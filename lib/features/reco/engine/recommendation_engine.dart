import '../../../core/geo/geo.dart';
import '../../guest/model/activity_axes.dart';
import '../../guest/model/dimension.dart';
import '../../guest/model/guest_profile.dart';
import '../content/content_provider.dart';
import '../model/activity.dart';
import '../model/lms_motive.dart';
import '../model/recommendation.dart';
import '../model/wellbeing.dart';
import 'leisure_motivation.dart';
import 'life_context_rules.dart';
import 'reco_context.dart';
import 'score_breakdown.dart';
import 'wellbeing_tagger.dart';

/// Deterministic, explainable recommendation engine — no LLM, on-device, free.
///
/// For a [GuestProfile] it: filters out infeasible activities, scores the rest
/// from a transparent weighted blend, ranks them, flags a single best pick, and
/// generates a one-line French "pourquoi ça te va" from the axes that matched
/// most. Same inputs → same outputs (pure), which is what makes the revealed-
/// preference learning and the unit tests well-behaved.
///
/// S11B — RESEARCH-GROUNDED score blend. Every term is tied to a documented
/// principle and every weight is a named constant with a one-line rationale +
/// source (see `reports/s11_research_grounded_scoring.md`):
///
///   score = w_pref·prefMatch(confidence-weighted, revealed-corrected)
///         + w_motive·lmsMotiveMatch                 (Beard & Ragheb LMS)
///         + w_affect·hedonicEudaimonicMoodFit        (Ryan&Deci / Huta&Ryan)
///         + w_context·contextFit(timeOfDay, season)  (context-aware rec)
///         + w_social·socialFit
///         + w_novelty·(noveltyPref·activityNovelty)  (novelty → hedonic boost)
///         + w_happiness·happinessTraitFit            (Lyubomirsky)
///         + w_proximity·(1−farness)                  (reachability as soft fit)
///         − w_repeat·repetitionPenalty               (revealed-pref anti-repeat)
///
/// Low-confidence taste dimensions contribute less (we lean on what we actually
/// know). Then: context + life-context feasibility hard-filter → diversity-aware
/// ranking (category spread + near-duplicate-venue guard) → DOSED serendipity
/// (one guaranteed discovery unless novelty-averse) → best pick first, then 4–6
/// alternatives one at a time, each with its real distance, a tailored
/// "pourquoi" AND its honest top-factor breakdown ([Recommendation.breakdown]).
class RecommendationEngine {
  const RecommendationEngine({
    this.catalog,
    this.content = const TemplatedContentProvider(),
  });

  /// Defaults to the seeded Montréal catalog; injectable for tests.
  final List<Activity>? catalog;

  /// S9F: the content surface (tailored "pourquoi" + smart image pick). Swap for
  /// an LLM-backed provider later without touching the engine.
  final ContentProvider content;

  // ---- Blend weights (sum ≈ 1; the penalty subtracts on top). --------------
  // Each weight names the principle it encodes; rationale in the S11 report.

  /// Taste match is the backbone — but it is REVEALED-corrected (the profile is
  /// continuously nudged by Intéressant/Pas-intéressant reactions) and
  /// confidence-weighted, because people mispredict what they'll enjoy
  /// (affective forecasting). So it leads without dominating the wellbeing terms.
  static const double _wPref = 0.30;

  /// Beard & Ragheb Leisure Motivation Scale — match the activity to WHY the
  /// guest reaches for leisure (intellectual/social/competence/escape).
  static const double _wMotive = 0.16;

  /// S11: hedonic↔eudaimonic mood fit. Leisure delivers pleasure/detachment AND
  /// meaning/growth; match the activity's axis to the guest's CURRENT motive
  /// (tired/escape → hedonic; curious/growth → eudaimonic). Ryan & Deci; Huta &
  /// Ryan.
  static const double _wAffect = 0.14;

  /// Context-aware recommendation: time-of-day + season as soft fit.
  static const double _wContext = 0.10;

  /// Plain social-axis fit (solo ↔ group), kept small since the happiness term
  /// already rewards self-congruent social support.
  static const double _wSocial = 0.06;

  /// Novelty → hedonic boost, scaled to the guest's OWN novelty preference, so
  /// it lifts discovery for the curious without unsettling the novelty-averse.
  static const double _wNovelty = 0.08;

  /// S11: happiness-raising activity traits (self-congruent, intrinsically
  /// appealing, flexible) lift wellbeing — reward fit on them. Lyubomirsky.
  static const double _wHappiness = 0.10;

  /// Reachability as soft fit: nearer real places rank up (S7C), so changing
  /// location visibly reranks.
  static const double _wProximity = 0.10;

  /// Anti-repetition: gently down-weight a category the guest just engaged, so a
  /// batch stays varied (revealed-preference / don't re-surface the decided).
  static const double _wRepeat = 0.06;

  // S9E diversity / serendipity tuning.
  /// Two same-category venues closer than this read as duplicates → keep one.
  static const double _nearDuplicateKm = 0.4;
  /// Novelty tag at/above which an activity counts as a genuine "discovery".
  static const double _discoveryNovelty = 0.7;
  /// Below this novelty preference the guest is treated as novelty-averse and no
  /// serendipity is forced.
  static const double _serendipityFloor = 0.3;

  /// Distance (km) at which a place reads as fully "far" (farness → 1). About
  /// across-town in Montréal. Used to normalise the real haversine distance.
  static const double _farKm = 8.0;

  /// The eight taste axes scored against an activity — see [kActivityAxes]
  /// (mood is folded into the motive weights, not matched directly).
  static const List<Dimension> _prefDims = kActivityAxes;

  List<Activity> get _activities => catalog ?? const [];

  /// Ranked recommendations, best first. Returns up to [max] (default 6),
  /// excluding [excludedIds]. [likedCategories] are gently down-weighted so the
  /// batch stays varied. Context defaults to the real clock.
  List<Recommendation> recommend(
    GuestProfile profile, {
    RecoContext? context,
    Set<String> excludedIds = const {},
    Set<ActivityCategory> likedCategories = const {},
    int max = 6,
  }) {
    final ctx = context ?? RecoContext.now();
    final pool =
        _activities.where((a) => !excludedIds.contains(a.id)).toList();
    if (pool.isEmpty) return const [];

    // Hard feasibility filter, with a guard so we never starve the scene.
    final feasible = pool
        .where((a) => _isFeasible(profile, a, _distanceOf(ctx, a)))
        .toList();
    final ranked = feasible.length >= 4 ? feasible : pool;

    // S9C: leisure-motivation weights over the four Beard & Ragheb LMS
    // components, derived once from the latent profile + mood.
    final lms = LeisureMotivation.weightsFor(profile);
    // S11: the guest's CURRENT desired position on the hedonic↔eudaimonic axis,
    // read off the same LMS weights (escape → hedonic, curiosity → eudaimonic).
    final desiredEud = _desiredEudaimonia(lms);
    final guestSocial = profile.valueOf(Dimension.social);
    final guestNovelty = profile.valueOf(Dimension.novelty);

    final scored = ranked.map((a) {
      // S7C: real haversine distance → 0 (here) … 1 (across town). S10: null
      // for non-geo kinds (films/online), so they aren't distance-filtered nor
      // falsely rewarded as "right here".
      final distanceKm = _distanceOf(ctx, a);
      final farness =
          distanceKm == null ? null : (distanceKm / _farKm).clamp(0.0, 1.0).toDouble();

      final wb = WellbeingTagger.of(a);
      final match = _prefMatch(profile, a, farness);
      final motive = LeisureMotivation.match(lms, LeisureMotivation.affinityFor(a));
      final affect = 1 - (wb.hedoniaEudaimonia - desiredEud).abs();
      final context = _contextFit(ctx, a);
      final social = 1 - (guestSocial - a.tag(Dimension.social)).abs();
      final novelty = guestNovelty * a.tag(Dimension.novelty);
      final happiness = _happinessFit(wb, guestSocial);

      final breakdown = ScoreBreakdown(
        pref: _wPref * match.score,
        motive: _wMotive * motive,
        affect: _wAffect * affect,
        context: _wContext * context,
        social: _wSocial * social,
        novelty: _wNovelty * novelty,
        happiness: _wHappiness * happiness,
        // Proximity only applies to located activities; 0 otherwise so films/
        // online are neither rewarded nor punished on distance.
        proximity: farness == null ? 0.0 : _wProximity * (1 - farness),
        repeatPenalty: likedCategories.contains(a.category) ? _wRepeat : 0.0,
      );

      return Recommendation(
        activity: a,
        score: breakdown.total,
        isBestPick: false,
        why: content.why(a, profile,
            lms: lms, topDims: match.topDims, context: ctx),
        topDimensions: match.topDims,
        breakdown: breakdown,
        distanceKm: distanceKm,
        imageOverride: content.imageFor(a, profile),
      );
    }).toList();

    scored.sort((x, y) => y.score.compareTo(x.score));
    final out = _diversify(scored, max, profile.valueOf(Dimension.novelty));
    if (out.isEmpty) return out;
    // Re-stamp the leader as the best pick.
    final lead = out.first;
    out[0] = Recommendation(
      activity: lead.activity,
      score: lead.score,
      isBestPick: true,
      why: lead.why,
      topDimensions: lead.topDimensions,
      breakdown: lead.breakdown,
      factors: lead.factors,
      distanceKm: lead.distanceKm,
      imageOverride: lead.imageOverride,
    );
    return out;
  }

  /// Diversity-aware ranking + dosed serendipity (S9E).
  ///
  /// 1. Category spread: best of each category first, so the visible queue isn't
  ///    five near-identical venues in a row.
  /// 2. Near-duplicate guard: never place two venues of the SAME category within
  ///    [_nearDuplicateKm] of each other (with real OSM data that's two cafés on
  ///    the same block) — pick the better, skip the clone.
  /// 3. Backfill the rest by score, same guard.
  /// 4. Dosed serendipity: unless the guest is novelty-averse, guarantee at least
  ///    one NON-lead pick is a genuine discovery (high-novelty), so the batch
  ///    always carries a controlled surprise — never only the safe picks.
  ///
  /// The global best pick always leads (it's never swapped out).
  List<Recommendation> _diversify(
      List<Recommendation> scored, int max, double noveltyPref) {
    final out = <Recommendation>[];
    final usedCategories = <ActivityCategory>{};
    for (final r in scored) {
      if (out.length >= max) break;
      if (_isNearDuplicate(r, out)) continue;
      if (usedCategories.add(r.activity.category)) out.add(r);
    }
    if (out.length < max) {
      final taken = out.toSet();
      for (final r in scored) {
        if (out.length >= max) break;
        if (taken.contains(r)) continue;
        if (_isNearDuplicate(r, out)) continue;
        out.add(r);
      }
    }
    _doseSerendipity(out, scored, noveltyPref);
    return out;
  }

  /// True if [r] is the same category AND within [_nearDuplicateKm] of an
  /// already-chosen pick (a near-duplicate venue).
  bool _isNearDuplicate(Recommendation r, List<Recommendation> chosen) {
    for (final c in chosen) {
      if (c.activity.category != r.activity.category) continue;
      final km = haversineKm(
          c.activity.lat, c.activity.lng, r.activity.lat, r.activity.lng);
      if (km <= _nearDuplicateKm) return true;
    }
    return false;
  }

  /// Ensure one non-lead pick is a genuine discovery, swapping in the best-scoring
  /// high-novelty option for the weakest alternative when the batch is all "safe"
  /// — but only when the guest isn't novelty-averse, so it never overrides a
  /// confident preference for the familiar.
  void _doseSerendipity(
      List<Recommendation> out, List<Recommendation> scored, double noveltyPref) {
    if (noveltyPref < _serendipityFloor || out.length <= 1) return;
    final alts = out.skip(1);
    final hasDiscovery =
        alts.any((r) => r.activity.tag(Dimension.novelty) >= _discoveryNovelty);
    if (hasDiscovery) return;
    final chosen = out.toSet();
    for (final r in scored) {
      if (chosen.contains(r)) continue;
      if (r.activity.tag(Dimension.novelty) < _discoveryNovelty) continue;
      // Don't reintroduce a near-duplicate; swap for the weakest alternative.
      final without = out.sublist(0, out.length - 1);
      if (_isNearDuplicate(r, without)) continue;
      out[out.length - 1] = r;
      return;
    }
  }

  // ---- Feasibility ---------------------------------------------------------

  /// Real distance to [a], or null for activities with no geography (S10) so the
  /// distance filter + proximity reward simply don't apply to them.
  double? _distanceOf(RecoContext ctx, Activity a) =>
      a.hasLocation ? ctx.distanceKmTo(a.lat, a.lng) : null;

  bool _isFeasible(GuestProfile p, Activity a, double? distanceKm) {
    // S9D: durable life-contexts are hard feasibility filters (kids, sans
    // alcool, budget serré, mobilité réduite, sans voiture, animal).
    if (!LifeContextRules.feasible(p.contexts, a, distanceKm: distanceKm)) {
      return false;
    }
    // Tight budget rules out a splurge.
    if (p.isConfident(Dimension.budget) &&
        p.valueOf(Dimension.budget) < 0.3 &&
        a.budget >= 3) {
      return false;
    }
    // A confident indoor/outdoor preference rules out the strict opposite.
    if (p.isConfident(Dimension.indoor)) {
      final pi = p.valueOf(Dimension.indoor);
      if (pi > 0.8 && a.tag(Dimension.indoor) < 0.2) return false;
      if (pi < 0.2 && a.tag(Dimension.indoor) > 0.85) return false;
    }
    // S7C: drop too-far places. Anything well out of the region is never shown;
    // a guest who confidently prefers nearby also won't see far-flung options.
    if (distanceKm != null) {
      if (distanceKm > 25) return false;
      if (p.isConfident(Dimension.distance) &&
          p.valueOf(Dimension.distance) < 0.35 &&
          distanceKm > 6) {
        return false;
      }
    }
    return true;
  }

  // ---- Preference match ----------------------------------------------------

  /// Normalized 0..1 taste match plus the axes that contributed most.
  ///
  /// Each axis contributes `weight × similarity`, where `weight = 0.2 +
  /// confidence` (unknown axes barely count) and `similarity = 1 − |p − a|`.
  /// The score is the confidence-weighted average similarity.
  ({double score, List<Dimension> topDims}) _prefMatch(
      GuestProfile p, Activity a, double? farness) {
    var sumC = 0.0, sumW = 0.0;
    final sims = <Dimension, double>{};
    for (final d in _prefDims) {
      // S7C: for the distance axis prefer the REAL normalised distance when the
      // guest's location is known, instead of the activity's static tag.
      final aTag =
          (d == Dimension.distance && farness != null) ? farness : a.tag(d);
      final sim = 1 - (p.valueOf(d) - aTag).abs();
      final weight = 0.2 + p.confidenceOf(d);
      sims[d] = sim;
      sumC += weight * sim;
      sumW += weight;
    }
    final score = sumW == 0 ? 0.0 : (sumC / sumW).clamp(0.0, 1.0).toDouble();

    final top = _prefDims.toList()
      ..sort((x, y) => (sims[y]! * (0.2 + p.confidenceOf(y)))
          .compareTo(sims[x]! * (0.2 + p.confidenceOf(x))));
    final topDims =
        top.where((d) => sims[d]! > 0.6).take(3).toList(growable: false);
    return (score: score, topDims: topDims);
  }

  // S9C: motive matching now runs over the four Beard & Ragheb LMS components
  // (see [LeisureMotivation]). The activity's legacy (hedonic/relaxation/
  // eudaimonic) affinities are folded into that derivation, not matched directly.

  // ---- Affect (hedonic ↔ eudaimonic) ---------------------------------------

  /// The guest's CURRENT desired position on the hedonic↔eudaimonic axis
  /// (0 hedonic/escape … 1 eudaimonic/growth), read off their live LMS weights.
  ///
  /// Intellectual & competence motives pull toward eudaimonia (meaning, mastery,
  /// discovery); stimulus-avoidance & — more weakly — social pull toward hedonia
  /// (escape, pleasure, detachment). So a tired guest who wants to decompress is
  /// matched to hedonic, low-effort picks, and a curious guest to eudaimonic,
  /// novel, cultural ones — from the SAME catalog. Ryan & Deci; Huta & Ryan.
  double _desiredEudaimonia(LmsWeights w) {
    final eud = w.intellectual + 0.6 * w.competence;
    final hed = w.stimulusAvoidance + 0.4 * w.social;
    return (0.5 + 0.5 * (eud - hed)).clamp(0.0, 1.0).toDouble();
  }

  // ---- Happiness-raising traits (Lyubomirsky) ------------------------------

  /// How well an activity's happiness-raising traits serve THIS guest, 0..1:
  ///   * self-congruent social support — the activity's connectedness matches
  ///     what the guest wants (a group place for a social guest, a calm one for
  ///     a solo guest);
  ///   * intrinsic appeal — enjoyed for its own sake (always rewarded);
  ///   * flexibility — adaptable / low-commitment (always a mild plus).
  double _happinessFit(WellbeingTags wb, double guestSocial) {
    final socialCongruence = 1 - (wb.socialSupport - guestSocial).abs();
    return (0.4 * socialCongruence +
            0.35 * wb.intrinsicAppeal +
            0.25 * wb.flexibility)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  // ---- Context -------------------------------------------------------------

  double _contextFit(RecoContext ctx, Activity a) {
    final timeFit = 1 - (a.tag(Dimension.timing) - ctx.eveningness).abs();
    final seasonFit =
        (ctx.winter && !a.winterFriendly && !a.indoor) ? 0.25 : 1.0;
    return (0.6 * timeFit + 0.4 * seasonFit).clamp(0.0, 1.0);
  }

  // S9F: the "pourquoi" and the image pick now come from the [ContentProvider]
  // (see content/content_provider.dart) — rich, varied, LLM-swappable templates
  // keyed to the profile + motive + matched axes + active life-context.
}
