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
}
