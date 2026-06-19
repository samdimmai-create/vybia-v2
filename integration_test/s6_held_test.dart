import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:vybia_v2/app.dart';
import 'package:vybia_v2/core/persistence/app_store.dart';
import 'package:vybia_v2/core/router/app_router.dart';
import 'package:vybia_v2/components/orb/vybia_orb.dart';

/// S6 PART A — prove the SIGNATURE effect live on the iOS simulator.
///
/// Runs the app on the booted sim (`flutter test integration_test/... -d <sim>`),
/// drives a HELD orb gesture at the Flutter framework level (TestGesture — never
/// OS cursor injection), and keeps it held at a decisive edge for several real
/// seconds. While held, the orb's refraction lens deforms the image AND the
/// decisive-edge colour filters it — the native shader rendering on a real
/// device frame. An external watcher (scripts/s6_capture.sh) captures each held
/// frame with `xcrun simctl io booted screenshot` when it sees the marker line
/// `VYBIA_SHOT <name>` this test prints.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  NavigatorState nav() => VybiaApp.navigatorKey.currentState!;

  // Real-wall-clock settle (the orb drift never stops → pumpAndSettle would spin).
  Future<void> settle(WidgetTester t, [int ms = 1200]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await t.pump(const Duration(milliseconds: 80));
    }
  }

  Offset orbCenter(WidgetTester t) => t.getCenter(find.byType(VybiaOrb).last);

  // Hold the orb toward [toward], print the capture marker, keep it held for
  // ~5s of real time (so the watcher can snap the live frame), then return to
  // centre and release WITHOUT committing (release below threshold).
  Future<void> holdCapture(
      WidgetTester t, Offset toward, String name) async {
    final c = orbCenter(t);
    final g = await t.startGesture(c);
    await t.pump(const Duration(milliseconds: 60));
    await g.moveTo(c + toward);
    await settle(t, 600); // let the lens + edge colour fully establish first
    // ignore: avoid_print
    debugPrint('VYBIA_SHOT $name');
    await settle(t, 6000); // hold the live refracted/edge-coloured frame
    await g.moveTo(c); // back to centre → reach 0 → cannot commit
    await t.pump(const Duration(milliseconds: 80));
    await g.up();
    await settle(t, 400);
  }

  testWidgets('held-orb refraction + decisive edge — reco/mood/profil', (t) async {
    await t.pumpWidget(VybiaApp(store: await AppStore.open()));
    await settle(t, 2200); // let splash auto-advance to Welcome

    const reach = 130.0; // well past the 72px threshold → strong lens + colour

    // 1) Reco scene — universal bubble on an activity image, all four edges.
    nav().pushNamed(AppRouter.reco);
    await settle(t, 3500); // first scene: let the activity image fully load
    await holdCapture(t, const Offset(-reach, 0), 's6_01_reco_joy');    // left
    await holdCapture(t, const Offset(reach, 0), 's6_02_reco_reject');  // right
    await holdCapture(t, const Offset(0, reach), 's6_03_reco_go');      // down
    await holdCapture(t, const Offset(0, -reach), 's6_04_reco_curious');// up

    // 2) Mood / emotions situational image (Welcome).
    nav().pushNamed(AppRouter.welcome);
    await settle(t, 2000);
    await holdCapture(t, const Offset(0, reach), 's6_05_mood_bubble');

    // 3) Profil situational image.
    nav().pushNamed(AppRouter.profil);
    await settle(t, 2000);
    await holdCapture(t, const Offset(-reach, 0), 's6_06_profil_bubble');

    // ignore: avoid_print
    debugPrint('VYBIA_SHOTS_DONE');
    await settle(t, 600);
  });
}
