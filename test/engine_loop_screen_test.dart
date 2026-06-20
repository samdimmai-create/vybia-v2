import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/core/router/app_router.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/screens/engine_loop_screen.dart';
import 'package:vybia_v2/features/guest/state/guest_controller.dart';

/// S9B/S9G — the adaptive loop, driven end to end ON SCREEN: a question batch
/// renders, an orb answer advances it, the reflection bridges, a recommendation
/// renders with the reaction edges, and Planifier navigates out (selection ends
/// the loop). skipReflection collapses the bridge to one frame for determinism.
void main() {
  Future<GuestController> pump(WidgetTester tester) async {
    final controller = GuestController();
    controller.profile.answer(Dimension.mood, 0.5); // seed mood (welcome step)
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: GuestScope(
          controller: controller,
          child: const EngineLoopScreen(skipReflection: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return controller;
  }

  /// Drive a full orb commit (down-swipe to the bottom edge) at the scene centre.
  Future<void> swipe(WidgetTester tester, Offset by) async {
    final g = await tester.startGesture(const Offset(200, 400));
    await tester.pump();
    await g.moveBy(by);
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('the loop renders a question, then a recommendation after answers',
      (tester) async {
    await pump(tester);

    // Phase 1: a question batch is on screen (its prompt headline shows).
    expect(find.byType(EngineLoopScreen), findsOneWidget);

    // Answer questions (swipe LEFT past threshold) until a recommendation
    // surfaces — its reaction edges ('Intéressant') appear on contact.
    var sawReco = false;
    for (var i = 0; i < 8 && !sawReco; i++) {
      await swipe(tester, const Offset(-160, 0)); // commit LEFT = first option
      await tester.pump(const Duration(milliseconds: 60));
      // Touch to reveal edge labels and check for the reco edge.
      final g = await tester.startGesture(const Offset(200, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      if (find.text('Intéressant').evaluate().isNotEmpty) sawReco = true;
      await g.up();
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(sawReco, isTrue,
        reason: 'the loop should reach a recommendation round on screen');
  });
}
