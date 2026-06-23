import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/components/orb/vybia_orb.dart';
import 'package:vybia_v2/core/theme/app_colors.dart';

/// S17C — the near-edge proximity model: a release COMMITS only when the orb is
/// close enough to the screen edge; the live reach is proximity to that edge
/// (off at centre, intensifying on approach), not distance from the origin.
void main() {
  group('edgeProximityReach (pure)', () {
    const bounds = Size(400, 800); // shortestSide 400 → zone = 168px (0.42)

    test('is 0 at the centre (outside the near-edge band)', () {
      expect(
        edgeProximityReach(bounds, OrbDirection.left, const Offset(200, 400)),
        0,
      );
      expect(
        edgeProximityReach(bounds, OrbDirection.down, const Offset(200, 400)),
        0,
      );
    });

    test('is 1 right at the aimed edge', () {
      expect(
        edgeProximityReach(bounds, OrbDirection.left, const Offset(0, 400)),
        1.0,
      );
      expect(
        edgeProximityReach(bounds, OrbDirection.right, const Offset(400, 400)),
        1.0,
      );
    });

    test('ramps up monotonically as the orb nears the edge', () {
      final far = edgeProximityReach(
          bounds, OrbDirection.left, const Offset(150, 400));
      final near =
          edgeProximityReach(bounds, OrbDirection.left, const Offset(40, 400));
      expect(near, greaterThan(far));
      expect(far, greaterThanOrEqualTo(0));
    });

    test('returns 0 for an unlaid-out (zero) scene', () {
      expect(
        edgeProximityReach(Size.zero, OrbDirection.up, const Offset(0, 0)),
        0,
      );
    });
  });

  Widget host({
    required ValueChanged<OrbDirection> onDirection,
    ValueChanged<OrbAim>? onAim,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: VybiaOrb(
            onDirection: onDirection,
            onAim: onAim,
            // Suppress throws + hold-to-home so these are pure drag-release tests.
            throwVelocity: 100000,
            holdStill: const Duration(seconds: 30),
            child: const SizedBox.expand(),
          ),
        ),
      );

  // Default test surface is 800×600 ⇒ shortestSide 600 ⇒ zone 252px, so a
  // left-edge commit needs the orb within ~126px of the left edge.

  testWidgets('a drag that ENDS near the edge commits that direction',
      (tester) async {
    OrbDirection? dir;
    await tester.pumpWidget(host(onDirection: (d) => dir = d));

    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await g.moveBy(const Offset(-320, 0)); // → x=80, well inside the left band
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(dir, OrbDirection.left);
  });

  testWidgets('a deliberate drag that ENDS mid-scene does NOT commit (dissolves)',
      (tester) async {
    var commits = 0;
    await tester.pumpWidget(host(onDirection: (_) => commits++));

    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await g.moveBy(const Offset(-150, 0)); // big drag, but ends at x=250 (centre)
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(commits, 0,
        reason: 'far from the edge must not commit even on a long drag');
  });

  testWidgets('the live reach is ~0 at the centre and high near the edge',
      (tester) async {
    final reaches = <double>[];
    OrbDirection? lastDir;
    await tester.pumpWidget(host(
      onDirection: (_) {},
      onAim: (a) {
        reaches.add(a.reach);
        lastDir = a.direction;
      },
    ));

    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    // A small nudge left near centre: direction set, but reach still ~0.
    await g.moveBy(const Offset(-30, 0));
    await tester.pump();
    final midReach = reaches.last;

    // Carry it to near the left edge: reach climbs high.
    await g.moveBy(const Offset(-300, 0)); // → x=70
    await tester.pump();
    final nearReach = reaches.last;

    expect(lastDir, OrbDirection.left);
    expect(midReach, lessThan(0.2),
        reason: 'off / barely on near the centre');
    expect(nearReach, greaterThan(0.6),
        reason: 'intensifies as the orb approaches the edge');

    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
