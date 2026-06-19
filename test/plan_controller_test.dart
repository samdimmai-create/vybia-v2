import 'package:flutter_test/flutter_test.dart';
import 'package:vybia_v2/features/plans/model/plan.dart';
import 'package:vybia_v2/features/plans/state/plan_controller.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';

void main() {
  final activity = kActivityCatalog.first;

  group('PlanController', () {
    test('create → plan appears in Futurs', () {
      final c = PlanController(seed: false);
      expect(c.futurs, isEmpty);

      final plan = c.create(
        activity: activity,
        moment: PlanMoment.tonight,
        companions: PlanCompanions.couple,
      );

      expect(c.futurs, hasLength(1));
      expect(c.futurs.single.id, plan.id);
      expect(c.passes, isEmpty);
      expect(plan.isPast(), isFalse);
    });

    test('supprimer removes the plan', () {
      final c = PlanController(seed: false);
      final plan = c.create(
        activity: activity,
        moment: PlanMoment.now,
        companions: PlanCompanions.solo,
      );
      expect(c.futurs, hasLength(1));

      c.remove(plan.id);

      expect(c.futurs, isEmpty);
      expect(c.count, 0);
      expect(c.byId(plan.id), isNull);
    });

    test('modifier updates moment and companions in place', () {
      final c = PlanController(seed: false);
      final plan = c.create(
        activity: activity,
        moment: PlanMoment.tonight,
        companions: PlanCompanions.solo,
      );

      c.update(plan.id,
          moment: PlanMoment.weekend, companions: PlanCompanions.friends);

      final updated = c.byId(plan.id)!;
      expect(updated.moment, PlanMoment.weekend);
      expect(updated.companions, PlanCompanions.friends);
      expect(updated.isPast(), isFalse); // still a future plan
      expect(c.count, 1); // updated in place, not duplicated
    });

    test('a "Choisir une date" plan honours the picked date', () {
      final c = PlanController(seed: false);
      final date = DateTime.now().add(const Duration(days: 30));
      final plan = c.create(
        activity: activity,
        moment: PlanMoment.pickDate,
        companions: PlanCompanions.family,
        pickedDate: date,
      );
      expect(plan.when, date);
      expect(c.futurs.single.id, plan.id);
    });

    test('notifies listeners on create / update / remove', () {
      final c = PlanController(seed: false);
      var notifications = 0;
      c.addListener(() => notifications++);

      final plan = c.create(
        activity: activity,
        moment: PlanMoment.now,
        companions: PlanCompanions.solo,
      );
      c.update(plan.id, companions: PlanCompanions.couple);
      c.remove(plan.id);

      expect(notifications, 3);
    });

    test('seeded session exposes past plans under Passés', () {
      final c = PlanController(); // seeded
      expect(c.passes, isNotEmpty);
      expect(c.passes.every((p) => p.isPast()), isTrue);
    });
  });
}
