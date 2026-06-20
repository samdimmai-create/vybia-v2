import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vybia_v2/components/orb/orb_throw.dart';
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
}
