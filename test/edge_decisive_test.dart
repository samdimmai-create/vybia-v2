import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/core/theme/app_colors.dart' show OrbDirection;
import 'package:vybia_v2/shared/edge_action.dart';
import 'package:vybia_v2/shared/edge_decisive.dart';

/// The active overlay wraps its painters in an [IgnorePointer]; the idle path
/// returns a bare [SizedBox.shrink] (no IgnorePointer), so its presence is a
/// clean signal of "is the decisive-edge layer actually painting".
Future<void> _pump(
  WidgetTester t, {
  required EdgeAction? action,
  required OrbDirection? direction,
  required double reach,
  Offset? orbCenter,
}) =>
    t.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: EdgeDecisiveOverlay(
        action: action,
        direction: direction,
        reach: reach,
        orbCenter: orbCenter,
      ),
    ));

void main() {
  group('EdgeDecisiveOverlay', () {
    testWidgets('paints nothing when idle (no action / no aim)', (t) async {
      await _pump(t, action: null, direction: null, reach: 0);
      expect(find.byType(IgnorePointer), findsNothing);
    });

    testWidgets('paints nothing at rest even with a stored action (reach 0)',
        (t) async {
      await _pump(t,
          action: EdgeAction.go, direction: OrbDirection.down, reach: 0.0);
      expect(find.byType(IgnorePointer), findsNothing);
    });

    testWidgets('fires for a real aimed edge (joy, reach > 0)', (t) async {
      await _pump(t,
          action: EdgeAction.joy,
          direction: OrbDirection.left,
          reach: 0.6,
          orbCenter: const Offset(100, 100));
      expect(find.byType(IgnorePointer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('reject edge engages its desaturate filter', (t) async {
      await _pump(t,
          action: EdgeAction.reject,
          direction: OrbDirection.right,
          reach: 0.8,
          orbCenter: const Offset(200, 300));
      expect(find.byType(IgnorePointer), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });
  });

  group('edge-wave radial geometry (S8.1B)', () {
    const size = Size(400, 800);

    test('the wave originates on the aimed screen edge, anchored to the orb',
        () {
      const orb = Offset(120, 500);
      expect(edgeWaveOrigin(size, OrbDirection.right, orb),
          const Offset(400, 500)); // right edge, orb's y
      expect(edgeWaveOrigin(size, OrbDirection.left, orb),
          const Offset(0, 500));
      expect(edgeWaveOrigin(size, OrbDirection.up, orb),
          const Offset(120, 0));
      expect(edgeWaveOrigin(size, OrbDirection.down, orb),
          const Offset(120, 800));
    });

    test('at rest (no orb) the wave anchors to the edge mid-point', () {
      expect(edgeWaveOrigin(size, OrbDirection.right, null),
          const Offset(400, 400));
    });

    test('coverage grows monotonically with proximity (reach)', () {
      final near = edgeWaveRadius(size, 0.2);
      final far = edgeWaveRadius(size, 0.9);
      expect(far, greaterThan(near));
    });

    test('at full reach the wave passes the screen diagonal so even the far '
        'corner is touched', () {
      final diag = math.sqrt(size.width * size.width + size.height * size.height);
      expect(edgeWaveRadius(size, 1.0), greaterThan(diag));
    });
  });
}
