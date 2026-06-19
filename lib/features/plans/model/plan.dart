import '../../reco/model/activity.dart';

/// When the guest wants to live a plan. Maps 1:1 to the four orb directions on
/// the Planifier "Quand ?" scene, so picking a moment is a single swipe.
enum PlanMoment { now, tonight, weekend, pickDate }

/// Who the guest is bringing along. Maps 1:1 to the four orb directions on the
/// Planifier "Avec qui ?" scene.
enum PlanCompanions { solo, couple, friends, family }

extension PlanMomentLabel on PlanMoment {
  String get labelFr {
    switch (this) {
      case PlanMoment.now:
        return 'Maintenant';
      case PlanMoment.tonight:
        return 'Ce soir';
      case PlanMoment.weekend:
        return 'Ce week-end';
      case PlanMoment.pickDate:
        return 'Une date choisie';
    }
  }
}

extension PlanCompanionsLabel on PlanCompanions {
  String get labelFr {
    switch (this) {
      case PlanCompanions.solo:
        return 'Solo';
      case PlanCompanions.couple:
        return 'En couple';
      case PlanCompanions.friends:
        return 'Entre amis';
      case PlanCompanions.family:
        return 'En famille';
    }
  }
}

/// One saved plan: an [Activity] anchored to a [moment] and [companions].
///
/// [when] is the representative datetime used purely to sort and to split the
/// list into Futurs vs Passés. Persistence across reloads is S5 — for now a plan
/// lives only in the session's [PlanController].
class Plan {
  Plan({
    required this.id,
    required this.activity,
    required this.moment,
    required this.companions,
    required this.when,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final Activity activity;
  PlanMoment moment;
  PlanCompanions companions;

  /// Representative moment in time (sorting + past/future split).
  DateTime when;

  final DateTime createdAt;

  bool isPast([DateTime? now]) => when.isBefore(now ?? DateTime.now());

  /// "Ce soir · En couple" — the one-line plan summary used on cards.
  String get summaryFr => '${moment.labelFr} · ${companions.labelFr}';

  Plan copyWith({
    PlanMoment? moment,
    PlanCompanions? companions,
    DateTime? when,
  }) =>
      Plan(
        id: id,
        activity: activity,
        moment: moment ?? this.moment,
        companions: companions ?? this.companions,
        when: when ?? this.when,
        createdAt: createdAt,
      );
}
