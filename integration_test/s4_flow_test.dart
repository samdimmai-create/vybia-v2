import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:vybia_v2/app.dart';
import 'package:vybia_v2/components/bubble/bubble_image.dart';
import 'package:vybia_v2/components/orb/vybia_orb.dart';
import 'package:vybia_v2/core/router/app_router.dart';

/// Visible S4 walk on the iOS simulator: reco → Planifier (moment + companions
/// + confirm) → Mes Plans → selected-plan orb actions. Gestures are driven at
/// the Flutter framework level (no OS cursor), and real frames are captured to
/// ./screenshots/ at every milestone.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The orb's ambient drift + pulse never stop, so we step time with pump()
  // (pumpAndSettle would spin forever).
  Future<void> settle(WidgetTester t, [int ms = 800]) async {
    await t.pump();
    await t.pump(Duration(milliseconds: ms));
  }

  Future<void> shot(WidgetTester t, String name) async {
    await settle(t);
    await binding.takeScreenshot(name);
  }

  NavigatorState nav() => VybiaApp.navigatorKey.currentState!;

  // Drive the orb past its commit threshold in one direction.
  Future<void> swipe(WidgetTester t, Offset delta) async {
    await t.fling(find.byType(VybiaOrb).last, delta, 800,
        warnIfMissed: false);
    await settle(t);
  }

  testWidgets('S4 plan flow walk', (t) async {
    // Mobile needs the surface converted before screenshots; desktop/web don't
    // (and throw), so this is best-effort.
    try {
      await binding.convertFlutterSurfaceToImage();
    } catch (_) {}

    await t.pumpWidget(const VybiaApp());
    // Let the splash auto-advance to Welcome before we deep-link, so its
    // pushReplacement can't clobber our navigation.
    await t.pump();
    await t.pump(const Duration(milliseconds: 1800));
    await shot(t, '01_welcome');

    // Jump into the immersive recommendations (neutral profile is fine).
    nav().pushNamed(AppRouter.reco);
    await shot(t, '02_reco');

    // Down = Planifier → moment step.
    await swipe(t, const Offset(0, 200));
    await shot(t, '03_planifier_moment');

    // Right = Ce soir → companions step.
    await swipe(t, const Offset(240, 0));
    await shot(t, '04_planifier_companions');

    // Right = En couple → confirm step.
    await swipe(t, const Offset(240, 0));
    await shot(t, '05_planifier_confirm');

    // Down = Confirmer → Mes Plans, new plan heading Futurs.
    await swipe(t, const Offset(0, 200));
    await shot(t, '06_mes_plans');

    // Open the first plan's selected layer.
    final card = find.byType(BubbleImage).first;
    expect(card, findsOneWidget);
    await t.tap(card);
    await shot(t, '07_selected_plan');

    // Up = Détails.
    await swipe(t, const Offset(0, -200));
    await shot(t, '08_plan_details');
  });
}
