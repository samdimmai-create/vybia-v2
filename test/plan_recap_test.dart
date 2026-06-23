import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/core/router/app_router.dart';
import 'package:vybia_v2/features/guest/state/guest_controller.dart';
import 'package:vybia_v2/features/plans/model/plan.dart';
import 'package:vybia_v2/features/plans/screens/planifier_screen.dart';
import 'package:vybia_v2/features/plans/screens/recap_screen.dart';
import 'package:vybia_v2/features/plans/state/plan_controller.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';

Widget _host(Widget child, PlanController plans) => MaterialApp(
      onGenerateRoute: AppRouter.onGenerateRoute,
      // Scopes sit ABOVE the navigator (as in the real app's builder) so routes
      // pushed by the recap (e.g. Mes Plans) still find them.
      builder: (context, navChild) => GuestScope(
        controller: GuestController(),
        child: PlanScope(controller: plans, child: navChild ?? const SizedBox()),
      ),
      home: child,
    );

/// A full orb commit toward [by] from the scene centre.
Future<void> swipe(WidgetTester tester, Offset by) async {
  final g = await tester.startGesture(const Offset(200, 400));
  await tester.pump();
  await g.moveBy(by);
  await tester.pump();
  await g.up();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  testWidgets('S19D — recap screen confirm SAVES a plan and lands on Mes Plans',
      (tester) async {
    final plans = PlanController(seed: false);
    final activity = kActivityCatalog.first;
    await tester.pumpWidget(_host(
      RecapScreen(
        activity: activity,
        moment: PlanMoment.tonight,
        companions: PlanCompanions.couple,
      ),
      plans,
    ));
    await tester.pump(const Duration(milliseconds: 100));

    // The recap shows the activity title and the planning summary.
    expect(find.text(activity.titleFr), findsWidgets);
    expect(plans.count, 0);

    // BAS = confirmer → the plan is created.
    await swipe(tester, const Offset(0, 220));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(plans.count, 1);
    expect(plans.futurs.single.moment, PlanMoment.tonight);
    expect(plans.futurs.single.companions, PlanCompanions.couple);
  });

  testWidgets('S19D — HAUT reveals the planning details panel', (tester) async {
    final plans = PlanController(seed: false);
    await tester.pumpWidget(_host(
      RecapScreen(
        activity: kActivityCatalog.first,
        moment: PlanMoment.weekend,
        companions: PlanCompanions.friends,
      ),
      plans,
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Détails de la planification'), findsNothing);
    await swipe(tester, const Offset(0, -220)); // HAUT = détails
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Détails de la planification'), findsOneWidget);
    expect(find.text('À compléter bientôt'), findsOneWidget);
    // No plan was saved by opening details.
    expect(plans.count, 0);
  });

  testWidgets('S19D — plan-from-zero gathers Quand → Avec qui → mood',
      (tester) async {
    final plans = PlanController(seed: false);
    await tester.pumpWidget(_host(const PlanifierScreen(), plans));
    await tester.pump(const Duration(milliseconds: 100));

    // From-zero opens on "Quand ?" with no chosen activity.
    expect(find.text('Quand ?'), findsOneWidget);

    await swipe(tester, const Offset(160, 0)); // right = Ce soir
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Avec qui ?'), findsOneWidget);

    await swipe(tester, const Offset(160, 0)); // right = En couple
    await tester.pump(const Duration(milliseconds: 150));
    // Plan-from-zero then captures a mood before entering the loop.
    expect(find.text('Dans quel état d’esprit ?'), findsOneWidget);
  });
}
