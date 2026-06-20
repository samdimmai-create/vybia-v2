import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vybia_v2/components/orb/orb_throw.dart';
import 'package:vybia_v2/components/orb/vybia_orb.dart';
import 'package:vybia_v2/core/theme/app_colors.dart';

/// Step a fresh simulation to completion and return it (so callers can read the
/// final result + committed direction).
ThrowResult _run(ThrowSimulation sim) {
  var r = ThrowResult.flying;
  for (var i = 0; i < 1200 && r == ThrowResult.flying; i++) {
    r = sim.step(1 / 60);
  }
  return r;
}

void main() {
  const bounds = Size(400, 800);
  const centre = Offset(200, 400);

  test('a strong throw reaches the edge and commits its direction', () {
    final sim = ThrowSimulation(
      bounds: bounds,
      position: centre,
      velocity: const Offset(2600, 0), // hard flick to the right
    );
    final r = _run(sim);
    expect(r, ThrowResult.commit);
    expect(sim.committedDirection, OrbDirection.right);
  });

  test('throw direction is honoured — an upward flick commits up', () {
    final sim = ThrowSimulation(
      bounds: bounds,
      position: centre,
      velocity: const Offset(0, -2600),
    );
    final r = _run(sim);
    expect(r, ThrowResult.commit);
    expect(sim.committedDirection, OrbDirection.up);
  });

  test('a weak throw runs out of momentum and dissolves — no commit', () {
    final sim = ThrowSimulation(
      bounds: bounds,
      position: centre,
      velocity: const Offset(240, 0), // gentle nudge, dies mid-scene
    );
    final r = _run(sim);
    expect(r, ThrowResult.dissolve);
    expect(sim.committedDirection, isNull);
  });

  test('reach grows toward 1 as the orb nears its heading edge', () {
    final sim = ThrowSimulation(
      bounds: bounds,
      position: centre,
      velocity: const Offset(2600, 0),
    );
    final reaches = <double>[];
    var r = ThrowResult.flying;
    for (var i = 0; i < 1200 && r == ThrowResult.flying; i++) {
      r = sim.step(1 / 60);
      reaches.add(sim.reach);
    }
    expect(sim.headingEdge, OrbDirection.right);
    // The last sampled reach (just before commit) is well past the mid-point.
    expect(reaches.last, greaterThan(0.6));
  });

  // S9.1C — the WIDGET behaviour: a thrown orb that runs out of momentum before
  // reaching an edge must DISSOLVE (presence → 0) without committing a direction
  // (and without teleporting back to the release point).
  testWidgets('a throw that stops mid-scene dissolves — presence → 0, no commit',
      (tester) async {
    var commits = 0;
    final presence = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VybiaOrb(
            onDirection: (_) => commits++,
            onPresence: presence.add,
            // A gentle flick counts as a throw, and the low release speed dies
            // out near the centre rather than reaching any edge.
            throwVelocity: 80,
            holdStill: const Duration(seconds: 10), // keep hold-to-home away
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    // Short, slow flick near centre: sub-threshold distance (no direct commit),
    // a small release velocity (a throw that won't reach an edge).
    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 60));
    await g.moveBy(const Offset(12, 0));
    await tester.pump(const Duration(milliseconds: 60));
    await g.moveBy(const Offset(12, 0));
    await tester.pump(const Duration(milliseconds: 60));
    await g.up();

    // Let the flight run out of momentum and the settle-dissolve finish.
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(commits, 0,
        reason: 'a throw that never reaches an edge must not commit a direction');
    expect(presence, isNotEmpty);
    expect(presence.last, lessThan(0.05),
        reason: 'the orb fades out (dissolves) after coming to rest');
  });
}
