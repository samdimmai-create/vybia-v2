import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/components/orb/orb_throw.dart';
import 'package:vybia_v2/components/orb/vybia_orb.dart';
import 'package:vybia_v2/core/theme/app_colors.dart';

/// S17C — the proximity reach drives the decisive VISUAL (off at centre,
/// intensifying on approach).
///
/// S23 — the COMMIT is now POSITION-based: a release commits an edge only when
/// the drag names a clear cardinal direction AND the orb has reached that edge's
/// DECISION ZONE (the outer ~22% toward the edge). A release at the centre or
/// short of the zone never commits — the precise, controllable rule that replaces
/// the S18/S20A travel-from-origin commit (which fired from a short swipe
/// anywhere, even mid-scene).
void main() {
  group('edgeProximityReach (pure)', () {
    const bounds = Size(400, 800); // shortestSide 400 → zone = 72px (S22A: 0.18)

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

  // Default test surface is 800×600. S23 decision zone (frac 0.22): the LEFT zone
  // is x ≤ 176, RIGHT x ≥ 624, UP y ≤ 132, DOWN y ≥ 468. A release commits only
  // inside the named edge's zone; everything between is the controllable centre.

  testWidgets('a drag that REACHES the decision zone commits that direction',
      (tester) async {
    OrbDirection? dir;
    await tester.pumpWidget(host(onDirection: (d) => dir = d));

    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await g.moveBy(const Offset(-320, 0)); // → x=80, well inside the left zone
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(dir, OrbDirection.left);
  });

  testWidgets('S23: a normal mid-scene release does NOT commit (released short '
      'of the zone)', (tester) async {
    OrbDirection? dir;
    var commits = 0;
    await tester.pumpWidget(host(onDirection: (d) {
      dir = d;
      commits++;
    }));

    // A ~90px thumb swipe that releases well short of the zone (x=310, the
    // controllable centre) must NOT register a choice — commit is position-based.
    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await g.moveBy(const Offset(-90, 0)); // → x=310, outside the left zone (≤176)
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(commits, 0,
        reason: 'releasing before the decision zone glides back to rest, no '
            'commit — the founder can stop short safely');
    expect(dir, isNull);
  });

  testWidgets('S23: a release at the CENTRE never commits', (tester) async {
    var commits = 0;
    await tester.pumpWidget(host(onDirection: (_) => commits++));

    // Drag a little, then bring the orb back to the centre and release there.
    final g = await tester.startGesture(const Offset(400, 300));
    await tester.pump();
    await g.moveBy(const Offset(-60, 0));
    await tester.pump();
    await g.moveBy(const Offset(60, 0)); // back to the centre (400,300)
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(commits, 0, reason: 'the centre is never a decision zone');
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
    await g.moveBy(const Offset(-260, 0)); // → x=140, inside the left zone (≤176)
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

    // Carry it into the tight near-edge band (S22A): reach climbs high only when
    // the orb is genuinely close to the edge, not from mid-scene.
    await g.moveBy(const Offset(-340, 0)); // → x=30, well inside the 108px band
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

  group('cornerBlend (pure) — S22D reliable two-edge gradient', () {
    test('is 0 for a pure cardinal aim (no diagonal-ness)', () {
      expect(cornerBlend(0.8, 0.0), 0);
    });

    test('is 0 when the dominant edge is outside its near-edge band (reach 0)',
        () {
      // The decisive effect is off mid-scene, so there is no corner blend either.
      expect(cornerBlend(0.0, 1.0), 0);
    });

    test('approaches an even blend at a perfect 45° corner', () {
      // A perfect diagonal (diagRatio 1) inside the active band → the even 0.5.
      expect(cornerBlend(0.7, 1.0), closeTo(0.5, 1e-9));
    });

    test('never exceeds 0.5 (the dominant edge always keeps the majority)', () {
      expect(cornerBlend(0.9, 1.0), lessThanOrEqualTo(0.5));
      expect(cornerBlend(0.2, 1.0), lessThanOrEqualTo(0.5));
    });

    test('S22D: a MODERATE diagonal gives a CLEARLY visible blend regardless of '
        'how near the perpendicular edge is (the old proximity gate left it '
        'nearly always invisible with the tighter S22A zone)', () {
      // A moderate 0.4 diagonal-ness, dominant edge active. The √ floor curve
      // lifts it well past a perceptible threshold (0.5·√0.4 ≈ 0.316).
      final b = cornerBlend(0.6, 0.4);
      expect(b, greaterThan(0.22),
          reason: 'the two-edge gradient must actually read on the phone');
      expect(b, lessThan(0.5));
    });

    test('grows monotonically with the diagonal-ness of the aim', () {
      expect(cornerBlend(0.5, 0.6), greaterThan(cornerBlend(0.5, 0.2)));
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

  // ---- S23: direction + decision-zone commit ----------------------------

  group('dominantEdge (pure) — the clear cardinal DIRECTION', () {
    test('a clear horizontal swipe names that edge', () {
      expect(dominantEdge(const Offset(-120, 8)), OrbDirection.left);
      expect(dominantEdge(const Offset(0, 130)), OrbDirection.down);
    });

    test('a tiny jitter inside the deadzone names nothing', () {
      expect(dominantEdge(const Offset(-10, 4)), isNull);
    });

    test('an ambiguous ~45° drag names nothing (no dominant axis)', () {
      expect(dominantEdge(const Offset(-160, -150)), isNull);
      expect(dominantEdge(const Offset(140, 150)), isNull);
    });

    test('a strong diagonal still names its clearly dominant axis', () {
      // 340 vs 260 ⇒ horizontal beats vertical by ≥ kAxisDominance → LEFT.
      expect(dominantEdge(const Offset(-340, -260)), OrbDirection.left);
    });
  });

  group('inDecisionZone (pure) — the near-edge band', () {
    const bounds = Size(400, 800); // left zone x≤88, right x≥312, up y≤176, down y≥624

    test('the centre is outside every zone', () {
      const centre = Offset(200, 400);
      expect(inDecisionZone(bounds, OrbDirection.left, centre), isFalse);
      expect(inDecisionZone(bounds, OrbDirection.right, centre), isFalse);
      expect(inDecisionZone(bounds, OrbDirection.up, centre), isFalse);
      expect(inDecisionZone(bounds, OrbDirection.down, centre), isFalse);
    });

    test('a position near an edge is inside that edge\'s zone', () {
      expect(inDecisionZone(bounds, OrbDirection.left, const Offset(40, 400)),
          isTrue);
      expect(inDecisionZone(bounds, OrbDirection.right, const Offset(360, 400)),
          isTrue);
      expect(inDecisionZone(bounds, OrbDirection.down, const Offset(200, 700)),
          isTrue);
    });

    test('a position just SHORT of the band is NOT in the zone', () {
      // left zone boundary is x = 88; x = 120 is short of it.
      expect(inDecisionZone(bounds, OrbDirection.left, const Offset(120, 400)),
          isFalse);
    });

    test('an unlaid-out (zero) scene has no zone', () {
      expect(
          inDecisionZone(Size.zero, OrbDirection.left, Offset.zero), isFalse);
    });
  });

  group('zoneCommit (pure) — direction AND position together', () {
    const bounds = Size(400, 800); // left zone x≤88

    test('a leftward drag whose position reached the left zone commits left',
        () {
      expect(
        zoneCommit(bounds, const Offset(40, 400), const Offset(-200, 6)),
        OrbDirection.left,
      );
    });

    test('a leftward drag released SHORT of the zone does NOT commit', () {
      // Clear left direction, but x=150 is short of the 88px zone → no commit.
      expect(
        zoneCommit(bounds, const Offset(150, 400), const Offset(-200, 6)),
        isNull,
      );
    });

    test('a release at the CENTRE never commits, however clear the direction',
        () {
      expect(
        zoneCommit(bounds, const Offset(200, 400), const Offset(-200, 6)),
        isNull,
      );
    });

    test('in the zone but ambiguous ~45° → no commit', () {
      // Position is in the left zone, but the aim names no dominant edge.
      expect(
        zoneCommit(bounds, const Offset(40, 400), const Offset(-150, -150)),
        isNull,
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
