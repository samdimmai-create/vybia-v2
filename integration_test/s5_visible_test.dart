import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:vybia_v2/app.dart';
import 'package:vybia_v2/core/persistence/app_store.dart';
import 'package:vybia_v2/core/router/app_router.dart';
import 'package:vybia_v2/components/orb/vybia_orb.dart';

/// S5 visible walk #1 (runs ON the iOS simulator):
///   PART 0 — re-prove the S4B decisive-edge colour filter live on a reco scene
///            by HOLDING the orb toward each edge (commit fires only on release,
///            so a hold shows the filter without navigating).
///   PART 1 — drive Mon Profil: capture the learned-profile aperçu, then adjust a
///            dimension via the orb, AND create a plan — both writing through to
///            local storage so the relaunch test can prove persistence.
/// All gestures are Flutter-framework synthetic pointers (no OS injection).
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester t, [int ms = 700]) async {
    await t.pump();
    await t.pump(Duration(milliseconds: ms));
  }

  Future<void> shot(WidgetTester t, String name) async {
    await settle(t);
    await binding.takeScreenshot(name);
  }

  NavigatorState nav() => VybiaApp.navigatorKey.currentState!;
  Offset orbCenter(WidgetTester t) => t.getCenter(find.byType(VybiaOrb).last);

  // Commit a direction (release past threshold).
  Future<void> swipe(WidgetTester t, Offset delta) async {
    await t.fling(find.byType(VybiaOrb).last, delta, 900, warnIfMissed: false);
    await settle(t);
  }

  // Hold the orb toward an edge (no release → no commit), screenshot the live
  // decisive-colour filter, then return to centre and release cleanly.
  Future<void> holdShot(WidgetTester t, Offset toward, String name) async {
    final c = orbCenter(t);
    final g = await t.startGesture(c);
    await t.pump();
    await g.moveTo(c + toward);
    await t.pump(const Duration(milliseconds: 350));
    await shot(t, name);
    await g.moveTo(c); // back to centre → reach 0 → cannot commit
    await t.pump();
    await g.up();
    await settle(t);
  }

  Future<void> bootToWelcome(WidgetTester t, AppStore store) async {
    await t.pumpWidget(VybiaApp(store: store));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1800)); // let splash auto-advance
  }

  testWidgets('PART 0 — S4B decisive-edge filter re-proof (held orb)',
      (t) async {
    try {
      await binding.convertFlutterSurfaceToImage();
    } catch (_) {}

    final store = await AppStore.open();
    await bootToWelcome(t, store);
    nav().pushNamed(AppRouter.reco); // immersive reco scene (neutral profile ok)
    await settle(t);

    const reach = 110.0; // past the 72px threshold → strong filter
    // Reco edge meanings: left=J'aime(joy) right=Pas pour moi(reject)
    //                     up=Plus d'infos(curious) down=Planifier(go).
    await holdShot(t, const Offset(-reach, 0), 's5_01_edge_joy');
    await holdShot(t, const Offset(reach, 0), 's5_02_edge_reject');
    await holdShot(t, const Offset(0, reach), 's5_03_edge_go');
    await holdShot(t, const Offset(0, -reach), 's5_04_edge_curious');
  });

  testWidgets('PART 1 — profil aperçu + orb adjust + create plan (persists)',
      (t) async {
    try {
      await binding.convertFlutterSurfaceToImage();
    } catch (_) {}

    final store = await AppStore.open();
    await bootToWelcome(t, store);

    // Mon Profil — aperçu of what Vybia learned.
    nav().pushNamed(AppRouter.profil);
    await shot(t, 's5_05_profil');

    // Enter "Ajuster" (left) then push Énergie up twice (right) — each nudge
    // writes through to storage.
    await swipe(t, const Offset(-220, 0)); // left → Ajuster mes goûts
    await swipe(t, const Offset(240, 0)); // right → plus tonique
    await swipe(t, const Offset(240, 0)); // right → plus tonique
    await shot(t, 's5_06_adjust');

    // Create a plan so a real future plan persists too: reco → Planifier flow.
    nav().pushNamed(AppRouter.reco);
    await settle(t);
    await swipe(t, const Offset(0, 220)); // down → Planifier
    await swipe(t, const Offset(240, 0)); // right → Ce soir
    await swipe(t, const Offset(240, 0)); // right → En couple
    await swipe(t, const Offset(0, 220)); // down → Confirmer → Mes Plans
    await shot(t, 's5_06b_plan_created');

    // Give async shared_preferences writes time to flush to NSUserDefaults
    // before the process exits (so the relaunch test reads them).
    await t.pump(const Duration(seconds: 1));
  });
}
