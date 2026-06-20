import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vybia_v2/core/persistence/app_store.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/guest/state/guest_controller.dart';
import 'package:vybia_v2/features/plans/model/plan.dart';
import 'package:vybia_v2/features/plans/state/plan_controller.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/state/reco_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppStore round-trips', () {
    test('profile values + confidence survive save → restore', () async {
      final store = await AppStore.open();
      final p = GuestProfile()
        ..answer(Dimension.energy, 0.82)
        ..answer(Dimension.social, 0.2);
      await store.saveProfile(p);

      final restored = GuestProfile()..restore(store.readProfileJson()!);
      expect(restored.valueOf(Dimension.energy), closeTo(0.82, 1e-9));
      expect(restored.valueOf(Dimension.social), closeTo(0.2, 1e-9));
      expect(restored.confidenceOf(Dimension.energy), greaterThan(0));
      // Untouched dimensions fall back to the neutral default.
      expect(restored.valueOf(Dimension.budget), 0.5);
    });

    test('intention round-trips and null clears it', () async {
      final store = await AppStore.open();
      await store.saveIntention(Intention.plan);
      expect(store.readIntention(), Intention.plan);
      await store.saveIntention(null);
      expect(store.readIntention(), isNull);
    });

    test('plans round-trip through JSON + catalog lookup', () async {
      final store = await AppStore.open();
      final plan = Plan(
        id: 'plan_7',
        activity: kActivityCatalog[3],
        moment: PlanMoment.weekend,
        companions: PlanCompanions.friends,
        when: DateTime(2026, 8, 1, 14),
      );
      await store.savePlans([plan]);

      final loaded = store.readPlans();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'plan_7');
      expect(loaded.single.activity.id, kActivityCatalog[3].id);
      expect(loaded.single.moment, PlanMoment.weekend);
      expect(loaded.single.companions, PlanCompanions.friends);
      expect(loaded.single.when, DateTime(2026, 8, 1, 14));
    });
  });

  group('persistence across relaunch', () {
    test('an adjusted preference rehydrates into a fresh GuestController',
        () async {
      final store = await AppStore.open();
      final guest = GuestController(store: store);
      guest.adjustDimension(Dimension.budget, 0.4); // 0.5 → 0.9

      // Simulate a relaunch: brand-new controller reading the same store.
      final reopened = await AppStore.open();
      final guest2 = GuestController(store: reopened);
      expect(guest2.profile.valueOf(Dimension.budget), closeTo(0.9, 1e-9));
      expect(guest2.profile.confidenceOf(Dimension.budget), greaterThan(0));
    });

    test('an Intéressant reaction persists the learned profile + liked history',
        () async {
      final store = await AppStore.open();
      final guest = GuestController(store: store)
        ..setMood(0.9, nudges: {Dimension.energy: 0.9});
      final reco = RecoController(profile: guest.profile, store: store);
      final likedTitle = reco.current!.activity.titleFr;
      reco.markInteresting();

      final reopened = await AppStore.open();
      expect(reopened.readLikedIds(), isNotEmpty);
      // The learned (nudged) profile was written through, not the cold default.
      final relaunched = GuestController(store: reopened);
      expect(relaunched.profile.confidenceOf(Dimension.energy), greaterThan(0));
      expect(likedTitle, isNotEmpty);
    });

    test('created plans rehydrate into a fresh PlanController', () async {
      final store = await AppStore.open();
      final plans = PlanController(store: store);
      final futursBefore = plans.futurs.length;
      plans.create(
        activity: kActivityCatalog.first,
        moment: PlanMoment.tonight,
        companions: PlanCompanions.solo,
      );

      final reopened = await AppStore.open();
      final plans2 = PlanController(store: reopened);
      expect(plans2.futurs.length, futursBefore + 1);
    });
  });

  group('first-run seed guard', () {
    test('seeds the two demo past plans exactly once', () async {
      final store = await AppStore.open();
      final first = PlanController(store: store);
      expect(first.passes.length, 2);
      expect(store.hasSeeded, isTrue);

      // Relaunch must NOT re-seed (would otherwise grow to 4).
      final reopened = await AppStore.open();
      final second = PlanController(store: reopened);
      expect(second.passes.length, 2);
    });

    test('a real plan added before relaunch is preserved, not re-seeded',
        () async {
      final store = await AppStore.open();
      final first = PlanController(store: store)
        ..create(
          activity: kActivityCatalog.first,
          moment: PlanMoment.weekend,
          companions: PlanCompanions.family,
        );
      final total = first.futurs.length + first.passes.length; // 2 seed + 1

      final reopened = await AppStore.open();
      final second = PlanController(store: reopened);
      expect(second.futurs.length + second.passes.length, total);
    });
  });
}
