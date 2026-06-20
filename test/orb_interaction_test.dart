import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/components/orb/vybia_orb.dart';
import 'package:vybia_v2/core/theme/app_colors.dart';
import 'package:vybia_v2/features/guest/widgets/scene_scaffold.dart';

/// S7 PART A — the founder's orb interaction model.
void main() {
  Widget orbHost({
    VoidCallback? onDoubleTap,
    VoidCallback? onHoldHome,
    ValueChanged<OrbDirection>? onDirection,
    bool enableHoldHome = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: VybiaOrb(
          onDirection: onDirection ?? (_) {},
          onDoubleTap: onDoubleTap,
          onHoldHome: onHoldHome,
          enableHoldHome: enableHoldHome,
          // Tiny thresholds keep the test fast and deterministic.
          holdStill: const Duration(milliseconds: 100),
          holdGrow: const Duration(milliseconds: 100),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  testWidgets('double-tap fires onDoubleTap (back), no direction committed',
      (tester) async {
    var taps = 0, dirs = 0;
    await tester.pumpWidget(orbHost(
      onDoubleTap: () => taps++,
      onDirection: (_) => dirs++,
    ));
    const c = Offset(200, 300);

    final g1 = await tester.startGesture(c);
    await g1.up();
    await tester.pump(const Duration(milliseconds: 40));
    final g2 = await tester.startGesture(c);
    await g2.up();
    await tester.pump(const Duration(milliseconds: 200));

    expect(taps, 1);
    expect(dirs, 0);
  });

  testWidgets('double-tap still reads as back when the two taps are slightly '
      'offset (within the forgiving slop)', (tester) async {
    var taps = 0, dirs = 0;
    await tester.pumpWidget(orbHost(
      onDoubleTap: () => taps++,
      onDirection: (_) => dirs++,
    ));

    final g1 = await tester.startGesture(const Offset(200, 300));
    await g1.up();
    await tester.pump(const Duration(milliseconds: 40));
    // Second tap lands ~30px away — natural finger imprecision, inside slop.
    final g2 = await tester.startGesture(const Offset(224, 318));
    await g2.up();
    await tester.pump(const Duration(milliseconds: 200));

    expect(taps, 1);
    expect(dirs, 0);
  });

  testWidgets('two taps far apart are NOT a double-tap (beyond slop)',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(orbHost(onDoubleTap: () => taps++));

    final g1 = await tester.startGesture(const Offset(120, 200));
    await g1.up();
    await tester.pump(const Duration(milliseconds: 40));
    final g2 = await tester.startGesture(const Offset(320, 600)); // far away
    await g2.up();
    await tester.pump(const Duration(milliseconds: 200));

    expect(taps, 0);
  });

  testWidgets('immobile hold ≥ threshold navigates home', (tester) async {
    var home = 0, dirs = 0;
    await tester.pumpWidget(orbHost(
      onHoldHome: () => home++,
      onDirection: (_) => dirs++,
    ));

    final g = await tester.startGesture(const Offset(200, 300));
    // Past holdStill → warning + grow begins.
    await tester.pump(const Duration(milliseconds: 140));
    // Past holdGrow → completes → navigate home.
    await tester.pump(const Duration(milliseconds: 140));

    expect(home, 1);
    expect(dirs, 0);
    await g.up(); // gesture already reset; release is a no-op
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('release before hold completes cancels — no nav, no edge',
      (tester) async {
    var home = 0, dirs = 0;
    await tester.pumpWidget(orbHost(
      onHoldHome: () => home++,
      onDirection: (_) => dirs++,
    ));

    final g = await tester.startGesture(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 120)); // warning started
    await g.up(); // released mid-warning, before grow completes
    await tester.pump(const Duration(milliseconds: 300));

    expect(home, 0);
    expect(dirs, 0);
  });

  testWidgets('moving to aim an edge cancels hold-to-home and commits the edge',
      (tester) async {
    var home = 0;
    OrbDirection? dir;
    await tester.pumpWidget(orbHost(
      onHoldHome: () => home++,
      onDirection: (d) => dir = d,
    ));

    final g = await tester.startGesture(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 40));
    await g.moveBy(const Offset(-120, 0)); // aim LEFT, well past threshold
    await tester.pump(const Duration(milliseconds: 200)); // would-be hold window
    await g.up();
    await tester.pump(const Duration(milliseconds: 200));

    expect(home, 0); // hold-to-home cancelled by movement
    expect(dir, OrbDirection.left); // the edge is committed normally
  });

  testWidgets('S9.0: orb position tracks the finger 1:1 — no easing/lerp '
      'on any move', (tester) async {
    // Capture the live position stream and prove it equals the *exact* pointer
    // position on every move (the orb is centred on the contact point, never a
    // smoothed/trailing point behind it).
    final reported = <Offset>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VybiaOrb(
            onDirection: (_) {},
            onPositionChanged: (p) {
              if (p != null) reported.add(p);
            },
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    const start = Offset(120, 200);
    final g = await tester.startGesture(start);
    await tester.pump();
    expect(reported.last, start, reason: 'born exactly at the contact point');

    // Walk an irregular path; after each move the reported point must be the
    // new pointer position itself (1:1), not an interpolation toward it.
    var p = start;
    for (final step in const [
      Offset(7, 0),
      Offset(13, -4),
      Offset(-5, 9),
      Offset(21, 3),
      Offset(-2, -11),
    ]) {
      await g.moveBy(step);
      await tester.pump();
      p = p + step;
      expect(reported.last, p,
          reason: 'orb sits ON the finger after move $step, not behind it');
    }

    await g.up();
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('SceneScaffold: edges hidden at rest, shown on contact',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SceneScaffold(
          image: 'assets/images/recos/cafe.jpg',
          headline: 'Café au Mile End',
          prompt: 'Une pause qui ralentit la journée',
          left: 'J’aime',
          right: 'Pas pour moi',
          up: 'Plus d’infos',
          down: 'Planifier',
          onDirection: _noop,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Rest: hero headline always visible; edge labels are NOT painted.
    expect(find.text('Café au Mile End'), findsOneWidget);
    expect(find.text('J’aime'), findsNothing);
    expect(find.text('Pas pour moi'), findsNothing);

    // On contact the edge labels fade in with the orb.
    final g = await tester.startGesture(const Offset(200, 400));
    await tester.pump(); // process pointer-down, start the birth ramp
    await tester.pump(const Duration(milliseconds: 160)); // ramp past birth
    expect(find.text('J’aime'), findsOneWidget);
    expect(find.text('Pas pour moi'), findsOneWidget);

    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('SceneScaffold bottom bubble: visible at rest, recedes on contact '
      '(S8.1D)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SceneScaffold(
          image: 'assets/images/places/cafe.jpg',
          headline: 'Café Olimpico',
          prompt: 'Une pause douce, un café soigné.',
          bottomBubble: true,
          infoLine: 'à 1,4 km · Café',
          tags: ['posé', 'calme'],
          left: 'J’aime',
          right: 'Pas pour moi',
          onDirection: _noop,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Rest: the bottom bubble shows the title, info line and the hint; the edge
    // labels are NOT painted yet.
    expect(find.text('Café Olimpico'), findsOneWidget);
    expect(find.text('à 1,4 km · Café'), findsOneWidget);
    expect(find.text('touche et décide'), findsOneWidget);
    expect(find.text('J’aime'), findsNothing);

    // On contact the bubble recedes (opacity → 0 ⇒ removed) and the edges fade
    // in with the orb.
    final g = await tester.startGesture(const Offset(200, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.text('J’aime'), findsOneWidget);
    expect(find.text('à 1,4 km · Café'), findsNothing);
    expect(find.text('touche et décide'), findsNothing);

    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
  });
}

void _noop(OrbDirection _) {}
