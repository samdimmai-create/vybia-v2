import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/core/router/app_router.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/state/guest_controller.dart';
import 'package:vybia_v2/features/reco/screens/reco_screen.dart';

/// S9A — the recommendation scene presents the reaction model on its edges:
/// LEFT = Intéressant · RIGHT = Pas intéressant · UP = Plus d'infos ·
/// DOWN = Planifier. They are hidden at rest and fade in with the orb.
void main() {
  testWidgets('S9A: reco edges read Intéressant / Pas intéressant / Plus '
      'd’infos / Planifier on contact', (tester) async {
    final controller = GuestController();
    // A neutral mid profile so the engine always has a current pick to show.
    controller.profile.answer(Dimension.mood, 0.5);
    controller.profile.answer(Dimension.energy, 0.5);

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: GuestScope(
          controller: controller,
          child: const RecoScreen(skipIntro: true),
        ),
      ),
    );
    // Let didChangeDependencies build the controller + resolve the location.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Rest: the reaction labels are NOT painted (image + bubble only).
    expect(find.text('Intéressant'), findsNothing);
    expect(find.text('Pas intéressant'), findsNothing);

    // On contact the four edges fade in with the orb.
    final g = await tester.startGesture(const Offset(200, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    expect(find.text('Intéressant'), findsOneWidget);
    expect(find.text('Pas intéressant'), findsOneWidget);
    expect(find.text('Plus d’infos'), findsOneWidget);
    expect(find.text('Planifier'), findsOneWidget);

    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
