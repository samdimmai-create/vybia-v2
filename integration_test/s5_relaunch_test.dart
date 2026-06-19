import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:vybia_v2/app.dart';
import 'package:vybia_v2/core/persistence/app_store.dart';
import 'package:vybia_v2/core/router/app_router.dart';

/// S5 visible walk #2 — the RELAUNCH proof. This is a *separate* `flutter drive`
/// invocation (a brand-new app process on the same simulator, reading the same
/// on-device shared_preferences the write walk left behind). No re-driving, no
/// re-answering: the app simply boots from storage. The screenshots must show
/// the adjusted preference and the created plan still present — not the cold
/// default — proving the full guest model persists across a true quit+relaunch.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester t, [int ms = 800]) async {
    await t.pump();
    await t.pump(Duration(milliseconds: ms));
  }

  Future<void> shot(WidgetTester t, String name) async {
    await settle(t);
    await binding.takeScreenshot(name);
  }

  NavigatorState nav() => VybiaApp.navigatorKey.currentState!;

  testWidgets('after relaunch: adjusted profile + plan persist', (t) async {
    try {
      await binding.convertFlutterSurfaceToImage();
    } catch (_) {}

    // Fresh process → fresh store → hydrates whatever the write walk persisted.
    final store = await AppStore.open();
    await t.pumpWidget(VybiaApp(store: store));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1800));

    // Mon Profil should show the adjusted Énergie (tonique), not the default.
    nav().pushNamed(AppRouter.profil);
    await shot(t, 's5_07_after_relaunch');

    // And the plan created before the relaunch should still be in Mes Plans.
    nav().pushNamed(AppRouter.mesPlans);
    await shot(t, 's5_08_plans_after_relaunch');
  });
}
