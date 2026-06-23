import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/components/orb/vybia_orb.dart';
import 'package:vybia_v2/core/theme/app_colors.dart';

/// S17C/S20A — the proximity reach drives the decisive VISUAL (off at centre,
/// intensifying on approach), but the COMMIT is decoupled from it (S20A): a
/// deliberate directional drag past the travel threshold registers reliably,
/// wherever the orb is released — it need not hug the edge.
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

  testWidgets('S20A: a normal directional release COMMITS even mid-scene '
      '(not hugging the edge)', (tester) async {
    OrbDirection? dir;
    await tester.pumpWidget(host(onDirection: (d) => dir = d));

    // A normal ~90px thumb swipe that releases well short of the edge (x=310,
    // centre band) must still register a choice — commit is travel-based now.
    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await g.moveBy(const Offset(-90, 0));
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(dir, OrbDirection.left,
        reason: 'a deliberate swipe registers wherever it is released');
  });

  testWidgets('S20B: after a commit the orb dissolves to nothing (never frozen)',
      (tester) async {
    OrbDirection? dir;
    final presence = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VybiaOrb(
            onDirection: (d) => dir = d,
            onPresence: presence.add,
            throwVelocity: 100000,
            holdStill: const Duration(seconds: 30),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await g.moveBy(const Offset(-120, 0));
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(dir, OrbDirection.left);
    expect(presence.last, lessThan(0.05),
        reason: 'the orb fully dissolves after a commit — never frozen on screen');
  });

  testWidgets('S20B: pointer-cancel resets cleanly (no commit, orb gone)',
      (tester) async {
    var commits = 0;
    final presence = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VybiaOrb(
            onDirection: (_) => commits++,
            onPresence: presence.add,
            holdStill: const Duration(seconds: 30),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await g.moveBy(const Offset(-60, 0));
    await tester.pump();
    await g.cancel(); // OS steals the pointer mid-gesture
    await tester.pump(const Duration(milliseconds: 200));

    expect(commits, 0);
    expect(presence.last, lessThan(0.05),
        reason: 'pointer-cancel must reset — no stuck orb');
  });

  testWidgets('a tiny sub-threshold nudge does NOT commit (still a tap)',
      (tester) async {
    var commits = 0;
    await tester.pumpWidget(host(onDirection: (_) => commits++));

    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await g.moveBy(const Offset(-20, 0)); // below the travel threshold
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(commits, 0);
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

  // ---- S17D: corner gradient (dominant wins) ----------------------------

  group('perpendicularEdge (pure)', () {
    test('a cardinal aim has no secondary edge', () {
      expect(perpendicularEdge(OrbDirection.left, const Offset(-120, 0)), null);
      expect(perpendicularEdge(OrbDirection.down, const Offset(2, 120)), null);
    });

    test('a diagonal aim names the perpendicular edge', () {
      // Dominant left, leaning up → secondary up.
      expect(
        perpendicularEdge(OrbDirection.left, const Offset(-120, -90)),
        OrbDirection.up,
      );
      // Dominant down, leaning right → secondary right.
      expect(
        perpendicularEdge(OrbDirection.down, const Offset(90, 120)),
        OrbDirection.right,
      );
    });
  });

  group('cornerBlend (pure)', () {
    test('is 0 when the secondary edge is not in reach (pure cardinal)', () {
      expect(cornerBlend(0.8, 0.0, 0.0), 0);
    });

    test('approaches an even blend at a perfect 45° corner', () {
      // Equal proximity to both edges + a perfect diagonal → ~0.5 (even).
      expect(cornerBlend(0.7, 0.7, 1.0), closeTo(0.5, 1e-9));
      // The closer edge dominates the mix.
      expect(cornerBlend(0.9, 0.3, 1.0), lessThan(0.5));
    });

    test('never exceeds 0.5 (the dominant edge always keeps the majority)', () {
      expect(cornerBlend(0.1, 0.9, 1.0), lessThanOrEqualTo(0.5));
    });

    test('S21C: a MODERATE diagonal near a corner now gives a CLEARLY visible '
        'blend (the old weighting left it nearly invisible)', () {
      // Both edges in reach, a moderate 0.4 diagonal-ness. Old weighting
      // (share·diagRatio) ⇒ 0.4·0.4 = 0.16 (barely there); the S21C floor curve
      // lifts it well past a perceptible threshold.
      final b = cornerBlend(0.6, 0.4, 0.4);
      expect(b, greaterThan(0.22),
          reason: 'the two-edge gradient must actually read on the phone');
      expect(b, lessThan(0.5));
    });
  });

  testWidgets('a diagonal drag into a corner commits the DOMINANT edge',
      (tester) async {
    OrbDirection? dir;
    await tester.pumpWidget(host(onDirection: (d) => dir = d));

    // From centre toward the top-left corner, with the horizontal pull dominant
    // (|dx| > |dy|). Ends at (60, 40): near the left edge, x dominates → LEFT.
    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await g.moveBy(const Offset(-340, -260));
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(dir, OrbDirection.left, reason: 'dominant axis wins the commit');
  });

  // ---- S21A: the DELIBERATE-commit rule ---------------------------------

  group('deliberateCommit (pure)', () {
    test('a clear horizontal swipe past the travel commits that direction', () {
      expect(
        deliberateCommit(const Offset(-120, 8), travel: 72),
        OrbDirection.left,
      );
      expect(
        deliberateCommit(const Offset(0, 130), travel: 72),
        OrbDirection.down,
      );
    });

    test('a small sub-travel nudge does NOT commit (it dissolves)', () {
      expect(deliberateCommit(const Offset(-30, 4), travel: 72), isNull);
    });

    test('an ambiguous ~45° drag does NOT commit, however far it travels', () {
      // |dx| ≈ |dy| → neither axis clearly dominates → no choice, no accident.
      expect(deliberateCommit(const Offset(-160, -150), travel: 72), isNull);
      expect(deliberateCommit(const Offset(140, 150), travel: 72), isNull);
    });

    test('a strong diagonal still commits its clearly dominant axis', () {
      // 340 vs 260 ⇒ horizontal beats vertical by ≥ kAxisDominance → LEFT.
      expect(
        deliberateCommit(const Offset(-340, -260), travel: 72),
        OrbDirection.left,
      );
    });
  });

  testWidgets('an ambiguous ~45° release does NOT commit a choice',
      (tester) async {
    var commits = 0;
    await tester.pumpWidget(host(onDirection: (_) => commits++));

    // A long but diagonal drift (|dx| ≈ |dy|): travels well past threshold yet
    // names no clear direction — the founder's "involuntary choice" must NOT
    // fire; the orb just dissolves.
    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await g.moveBy(const Offset(-150, -150));
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(commits, 0,
        reason: 'an ambiguous diagonal dissolves — only a clear swipe commits');
  });
}
