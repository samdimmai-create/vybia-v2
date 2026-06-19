import 'package:flutter/widgets.dart';

import '../../reco/data/activity_catalog.dart';
import '../../reco/model/activity.dart';
import '../model/plan.dart';

/// Session store for the guest's plans (Futurs + Passés).
///
/// Lives above the navigator via [PlanScope] so it survives route changes —
/// the same "simple provider" pattern as the guest session. In-memory only;
/// persistence across reloads is S5. Seeds a couple of past plans so the Passés
/// section reads as real on a fresh session (disable with `seed: false` in tests).
class PlanController extends ChangeNotifier {
  PlanController({bool seed = true}) {
    if (seed) _seedPast();
  }

  final List<Plan> _plans = [];
  int _seq = 0;

  /// Future plans, soonest first.
  List<Plan> get futurs {
    final now = DateTime.now();
    final list = _plans.where((p) => !p.isPast(now)).toList()
      ..sort((a, b) => a.when.compareTo(b.when));
    return List.unmodifiable(list);
  }

  /// Past plans, most recent first.
  List<Plan> get passes {
    final now = DateTime.now();
    final list = _plans.where((p) => p.isPast(now)).toList()
      ..sort((a, b) => b.when.compareTo(a.when));
    return List.unmodifiable(list);
  }

  int get count => _plans.length;

  Plan? byId(String id) {
    for (final p in _plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Translate an orb-chosen [moment] into a representative future datetime so
  /// freshly created plans always land under Futurs. [pickedDate] is honoured
  /// for [PlanMoment.pickDate].
  static DateTime whenFor(PlanMoment moment, {DateTime? pickedDate, DateTime? from}) {
    final base = from ?? DateTime.now();
    switch (moment) {
      case PlanMoment.now:
        return base.add(const Duration(minutes: 30));
      case PlanMoment.tonight:
        final tonight = DateTime(base.year, base.month, base.day, 20);
        return tonight.isAfter(base)
            ? tonight
            : tonight.add(const Duration(days: 1));
      case PlanMoment.weekend:
        // Next Saturday at 14:00 (today if it's already the weekend ahead).
        var d = DateTime(base.year, base.month, base.day, 14);
        while (d.weekday != DateTime.saturday || !d.isAfter(base)) {
          d = d.add(const Duration(days: 1));
        }
        return d;
      case PlanMoment.pickDate:
        return pickedDate ?? base.add(const Duration(days: 7));
    }
  }

  /// Create and save a plan; returns the stored [Plan]. Lands at the front of
  /// Futurs by construction (its [when] is in the future).
  Plan create({
    required Activity activity,
    required PlanMoment moment,
    required PlanCompanions companions,
    DateTime? pickedDate,
  }) {
    final plan = Plan(
      id: 'plan_${_seq++}',
      activity: activity,
      moment: moment,
      companions: companions,
      when: whenFor(moment, pickedDate: pickedDate),
    );
    _plans.add(plan);
    notifyListeners();
    return plan;
  }

  /// Update an existing plan's moment / companions (Modifier). Recomputes [when]
  /// when the moment changes so it re-files into the right section.
  void update(
    String id, {
    PlanMoment? moment,
    PlanCompanions? companions,
    DateTime? pickedDate,
  }) {
    final plan = byId(id);
    if (plan == null) return;
    if (moment != null) {
      plan.moment = moment;
      plan.when = whenFor(moment, pickedDate: pickedDate);
    }
    if (companions != null) plan.companions = companions;
    notifyListeners();
  }

  /// Remove a plan from the session (Supprimer).
  void remove(String id) {
    _plans.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void _seedPast() {
    // Two believable past outings so Passés isn't empty on a fresh session.
    final now = DateTime.now();
    Activity at(int i) => kActivityCatalog[i % kActivityCatalog.length];
    _plans.addAll([
      Plan(
        id: 'plan_seed_0',
        activity: at(0),
        moment: PlanMoment.tonight,
        companions: PlanCompanions.couple,
        when: now.subtract(const Duration(days: 4, hours: 3)),
      ),
      Plan(
        id: 'plan_seed_1',
        activity: at(2),
        moment: PlanMoment.weekend,
        companions: PlanCompanions.friends,
        when: now.subtract(const Duration(days: 12, hours: 6)),
      ),
    ]);
    _seq = 0; // created plans get their own `plan_<n>` namespace
  }
}

/// Inherited access to the shared [PlanController].
class PlanScope extends InheritedNotifier<PlanController> {
  const PlanScope({
    super.key,
    required PlanController controller,
    required super.child,
  }) : super(notifier: controller);

  static PlanController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PlanScope>();
    assert(scope?.notifier != null, 'No PlanScope found in context');
    return scope!.notifier!;
  }
}
