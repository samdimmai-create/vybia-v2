import '../../../core/geo/geo.dart';
import '../../guest/model/activity_axes.dart';
import '../../guest/model/dimension.dart';
import '../../guest/model/guest_profile.dart';
import '../content/content_provider.dart';
import '../model/activity.dart';
import '../model/recommendation.dart';
import 'leisure_motivation.dart';
import 'life_context_rules.dart';
import 'reco_context.dart';

/// Deterministic, explainable recommendation engine — no LLM, on-device, free.
///
/// For a [GuestProfile] it: filters out infeasible activities, scores the rest
/// from a transparent weighted blend, ranks them, flags a single best pick, and
/// generates a one-line French "pourquoi ça te va" from the axes that matched
/// most. Same inputs → same outputs (pure), which is what makes the revealed-
/// preference learning and the unit tests well-behaved.
///
/// S9E score blend (weights below):
///   score = wPref·prefMatch + wMotive·lmsMatch(LMS+mood) + wContext·contextFit
///         + wSocial·socialFit + wNovelty·(noveltyPref·novelty) + wProximity·(1−farness)
///         − categoryRepeatPenalty
/// then: life-context + feasibility filter → diversity-aware ranking (category
/// spread + near-duplicate-venue guard) → DOSED serendipity (one guaranteed
/// discovery unless novelty-averse) → best pick first, then 4–6 alternatives one
/// at a time at the orb, each with its real distance and a tailored "pourquoi".
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

  // ---- Blend weights (sum ≈ 1; penalties subtract on top). -----------------
  static const double _wPref = 0.42;
  static const double _wMotive = 0.20;
  static const double _wContext = 0.14;
  static const double _wSocial = 0.09;
  static const double _wNovelty = 0.10;
  static const double _wProximity = 0.12; // S7C: nearer real places rank up
  static const double _categoryRepeatPenalty = 0.06;

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

    final scored = ranked.map((a) {
      // S7C: real haversine distance → 0 (here) … 1 (across town). S10: null
      // for non-geo kinds (films/online), so they aren't distance-filtered nor
      // falsely rewarded as "right here".
      final distanceKm = _distanceOf(ctx, a);
      final farness =
          distanceKm == null ? null : (distanceKm / _farKm).clamp(0.0, 1.0).toDouble();

      final match = _prefMatch(profile, a, farness);
      final motive = LeisureMotivation.match(lms, LeisureMotivation.affinityFor(a));
      final context = _contextFit(ctx, a);
      final social =
          1 - (profile.valueOf(Dimension.social) - a.tag(Dimension.social)).abs();
      final novelty =
          profile.valueOf(Dimension.novelty) * a.tag(Dimension.novelty);

      var score = _wPref * match.score +
          _wMotive * motive +
          _wContext * context +
          _wSocial * social +
          _wNovelty * novelty;

      // Always reward proximity a little so changing location visibly reranks.
      if (farness != null) score += _wProximity * (1 - farness);

      if (likedCategories.contains(a.category)) {
        score -= _categoryRepeatPenalty;
      }

      return Recommendation(
        activity: a,
        score: score,
        isBestPick: false,
        why: content.why(a, profile,
            lms: lms, topDims: match.topDims, context: ctx),
        topDimensions: match.topDims,
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
