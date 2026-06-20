import '../../guest/model/dimension.dart';
import '../../guest/model/life_context.dart';
import '../model/activity.dart';

/// The life-context → feasibility table (S9D), as deterministic on-device rules.
///
/// Each active [LifeContext] drops the activities it makes infeasible. The table
/// (also reproduced in the sprint report):
///
///   avecEnfants      → no nightlife · nothing strictly late-evening
///   sansAlcool       → no nightlife (bars/clubs)
///   budgetSerre      → no splurges (budget tier 3)
///   mobiliteReduite  → no high-effort (active / energetic nature) · nothing far (>8km)
///   sansVoiture      → nothing across town (>6km)
///   avecAnimal       → no pet-unfriendly indoor venues (culture / nightlife)
///
/// The caller (the engine) already guards against starving the scene: if the
/// filter leaves too few options it falls back to the unfiltered pool, so a
/// pile-up of contexts never yields a blank screen.
class LifeContextRules {
  const LifeContextRules._();

  /// Distance (km) past which "no car" / "reduced mobility" drop a place.
  static const double _noCarKm = 6.0;
  static const double _reducedMobilityKm = 8.0;

  /// True if [a] is feasible under EVERY active context.
  static bool feasible(Set<LifeContext> active, Activity a, {double? distanceKm}) {
    for (final c in active) {
      if (!_ok(c, a, distanceKm)) return false;
    }
    return true;
  }

  static bool _ok(LifeContext c, Activity a, double? distanceKm) {
    switch (c) {
      case LifeContext.avecEnfants:
        if (a.category == ActivityCategory.nightlife) return false;
        if (a.tag(Dimension.timing) > 0.85) return false; // strictly late-night
        return true;
      case LifeContext.sansAlcool:
        return a.category != ActivityCategory.nightlife;
      case LifeContext.budgetSerre:
        return a.budget < 3; // no splurge
      case LifeContext.mobiliteReduite:
        if (a.category == ActivityCategory.active) return false;
        if (a.category == ActivityCategory.nature &&
            a.tag(Dimension.energy) > 0.6) {
          return false; // a real hike / climb
        }
        if (distanceKm != null && distanceKm > _reducedMobilityKm) return false;
        return true;
      case LifeContext.sansVoiture:
        if (distanceKm != null && distanceKm > _noCarKm) return false;
        return true;
      case LifeContext.avecAnimal:
        // Pet-unfriendly indoor venues only.
        if (!a.indoor) return true;
        return a.category != ActivityCategory.culture &&
            a.category != ActivityCategory.nightlife;
    }
  }
}
