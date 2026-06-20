import '../../guest/model/activity_axes.dart';
import '../../guest/model/dimension.dart';
import '../../guest/model/guest_profile.dart';
import '../model/activity.dart';
import '../model/motive.dart';
import '../model/recommendation.dart';
import 'reco_context.dart';

/// Deterministic, explainable recommendation engine — no LLM, on-device, free.
///
/// For a [GuestProfile] it: filters out infeasible activities, scores the rest
/// from a transparent weighted blend, ranks them, flags a single best pick, and
/// generates a one-line French "pourquoi ça te va" from the axes that matched
/// most. Same inputs → same outputs (pure), which is what makes the revealed-
/// preference learning and the unit tests well-behaved.
class RecommendationEngine {
  const RecommendationEngine({this.catalog});

  /// Defaults to the seeded Montréal catalog; injectable for tests.
  final List<Activity>? catalog;

  // ---- Blend weights (sum ≈ 1; penalties subtract on top). -----------------
  static const double _wPref = 0.42;
  static const double _wMotive = 0.20;
  static const double _wContext = 0.14;
  static const double _wSocial = 0.09;
  static const double _wNovelty = 0.10;
  static const double _wProximity = 0.12; // S7C: nearer real places rank up
  static const double _categoryRepeatPenalty = 0.06;

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
        .where((a) => _isFeasible(profile, a, ctx.distanceKmTo(a.lat, a.lng)))
        .toList();
    final ranked = feasible.length >= 4 ? feasible : pool;

    final motives = _motiveWeights(profile);

    final scored = ranked.map((a) {
      // S7C: real haversine distance → 0 (here) … 1 (across town).
      final distanceKm = ctx.distanceKmTo(a.lat, a.lng);
      final farness =
          distanceKm == null ? null : (distanceKm / _farKm).clamp(0.0, 1.0).toDouble();

      final match = _prefMatch(profile, a, farness);
      final motive = _motiveMatch(motives, a.motives);
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
        why: _why(match.topDims, a),
        topDimensions: match.topDims,
        distanceKm: distanceKm,
      );
    }).toList();

    scored.sort((x, y) => y.score.compareTo(x.score));
    final out = _diversify(scored, max);
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
    );
    return out;
  }

  /// Greedy category spread: take the best of each category first (so the
  /// visible queue isn't five near-identical venues in a row), then backfill the
  /// remaining slots by score. The global best pick still leads. With real OSM
  /// data — hundreds of cafés/restaurants — this is what keeps the batch varied.
  List<Recommendation> _diversify(List<Recommendation> scored, int max) {
    final out = <Recommendation>[];
    final usedCategories = <ActivityCategory>{};
    for (final r in scored) {
      if (out.length >= max) break;
      if (usedCategories.add(r.activity.category)) out.add(r);
    }
    if (out.length < max) {
      final taken = out.toSet();
      for (final r in scored) {
        if (out.length >= max) break;
        if (taken.contains(r)) continue;
        out.add(r);
      }
    }
    return out;
  }

  // ---- Feasibility ---------------------------------------------------------

  bool _isFeasible(GuestProfile p, Activity a, double? distanceKm) {
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

  // ---- Motive match --------------------------------------------------------

  MotiveWeights _motiveWeights(GuestProfile p) {
    final mood = p.valueOf(Dimension.mood); // 0 calm → 1 energetic
    final energy = p.valueOf(Dimension.energy);
    final social = p.valueOf(Dimension.social);
    final vibe = p.valueOf(Dimension.vibe);
    final novelty = p.valueOf(Dimension.novelty);

    final hed = social * 0.4 + vibe * 0.3 + mood * 0.3;
    final rel = (1 - energy) * 0.5 + (1 - mood) * 0.5;
    // Eudaimonia peaks with novelty and a "curious" (mid) mood.
    final eud =
        novelty * 0.7 + 0.3 * (1 - (mood - 0.5).abs() * 2).clamp(0.0, 1.0);

    final sum = hed + rel + eud;
    if (sum == 0) return (hedonic: 1 / 3, relaxation: 1 / 3, eudaimonic: 1 / 3);
    return (hedonic: hed / sum, relaxation: rel / sum, eudaimonic: eud / sum);
  }

  double _motiveMatch(MotiveWeights w, MotiveAffinity a) => (w.hedonic *
              a.hedonic +
          w.relaxation * a.relaxation +
          w.eudaimonic * a.eudaimonic)
      .clamp(0.0, 1.0);

  // ---- Context -------------------------------------------------------------

  double _contextFit(RecoContext ctx, Activity a) {
    final timeFit = 1 - (a.tag(Dimension.timing) - ctx.eveningness).abs();
    final seasonFit =
        (ctx.winter && !a.winterFriendly && !a.indoor) ? 0.25 : 1.0;
    return (0.6 * timeFit + 0.4 * seasonFit).clamp(0.0, 1.0);
  }

  // ---- Explanation ---------------------------------------------------------

  String _why(List<Dimension> top, Activity a) {
    // Distance is shown explicitly on the card ("à X km"), so keep it out of the
    // prose to avoid a vague "à deux pas" contradicting a precise "à 4,4 km".
    final dims = top.where((d) => d != Dimension.distance).toList();
    if (dims.isEmpty) {
      return 'Un choix équilibré, dans l’esprit de ton moment.';
    }
    final frags = dims.take(2).map((d) => _fragment(d, a.tag(d))).toList();
    return '${_capitalize(frags.join(', '))}.';
  }

  String _fragment(Dimension d, double v) {
    switch (d) {
      case Dimension.energy:
        return v > 0.6 ? 'ça bouge, à ton rythme' : 'tout en douceur';
      case Dimension.social:
        return v > 0.6 ? 'avec du monde autour' : 'au calme, juste pour toi';
      case Dimension.novelty:
        return v > 0.6 ? 'une vraie découverte' : 'une valeur sûre';
      case Dimension.distance:
        return v > 0.6 ? 'ça vaut le petit trajet' : 'à deux pas';
      case Dimension.indoor:
        return v > 0.6 ? 'bien à l’abri' : 'au grand air';
      case Dimension.timing:
        return v > 0.6 ? 'taillé pour la soirée' : 'parfait en journée';
      case Dimension.budget:
        return v < 0.4 ? 'sans te ruiner' : 'tu te fais plaisir';
      case Dimension.vibe:
        return v > 0.6 ? 'une ambiance vivante' : 'une atmosphère intime';
      case Dimension.mood:
        return 'dans ton humeur du moment';
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
