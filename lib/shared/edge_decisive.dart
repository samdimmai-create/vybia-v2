import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'edge_action.dart';

/// The reusable DECISIVE-EDGE feedback layer.
///
/// Drop this full-bleed above any orb-driven image (see `SceneScaffold`). As the
/// orb nears a decisive edge it:
///   1. progressively FILTERS the image toward that edge's action colour —
///      0 at centre, intense near the edge, scaling with `reach`;
///      `reject` instead drains colour to grayscale + darkens (a real
///      [BackdropFilter] desaturation, masked from the edge);
///   2. recolours the ORB's aura toward the same colour (a tinted glow at
///      [orbCenter], or a darkening for `reject`).
///
/// It paints nothing when idle, so it costs ~nothing until the user engages.
class EdgeDecisiveOverlay extends StatelessWidget {
  const EdgeDecisiveOverlay({
    super.key,
    required this.action,
    required this.direction,
    required this.reach,
    required this.orbCenter,
    this.lensRadius = 84,
  });

  /// The action mapped to the currently-aimed edge, or null when idle.
  final EdgeAction? action;

  /// The edge being aimed at, or null in the deadzone.
  final OrbDirection? direction;

  /// 0 at centre → 1 at the commit threshold.
  final double reach;

  /// Live orb position (for the aura), or null when resting.
  final Offset? orbCenter;
  final double lensRadius;

  @override
  Widget build(BuildContext context) {
    final a = action;
    if (a == null || direction == null || reach <= 0.001) {
      return const SizedBox.shrink();
    }

    final desat = a.desaturates
        ? Positioned.fill(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => _edgeGradient(
                direction!,
                [
                  Colors.white.withValues(alpha: (0.9 * reach).clamp(0, 1)),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ).createShader(rect),
              child: BackdropFilter(
                filter: ui.ColorFilter.matrix(_desaturateDarken),
                child: const SizedBox.expand(),
              ),
            ),
          )
        : null;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ?desat,
          CustomPaint(
            painter: _EdgeDecisivePainter(
              action: a,
              direction: direction!,
              reach: reach,
              orbCenter: orbCenter,
              lensRadius: lensRadius,
            ),
          ),
        ],
      ),
    );
  }
}

/// Linear gradient that starts at the aimed edge and fades toward the centre.
LinearGradient _edgeGradient(OrbDirection d, List<Color> colors) {
  late final Alignment begin;
  late final Alignment end;
  switch (d) {
    case OrbDirection.left:
      begin = Alignment.centerLeft;
      end = const Alignment(0.25, 0);
    case OrbDirection.right:
      begin = Alignment.centerRight;
      end = const Alignment(-0.25, 0);
    case OrbDirection.up:
      begin = Alignment.topCenter;
      end = const Alignment(0, 0.25);
    case OrbDirection.down:
      begin = Alignment.bottomCenter;
      end = const Alignment(0, -0.25);
  }
  return LinearGradient(begin: begin, end: end, colors: colors);
}

/// Grayscale (Rec. 709 luma) + darken to ~0.6 brightness — the reject filter.
const List<double> _desaturateDarken = <double>[
  0.2126 * 0.6, 0.7152 * 0.6, 0.0722 * 0.6, 0, 0, //
  0.2126 * 0.6, 0.7152 * 0.6, 0.0722 * 0.6, 0, 0, //
  0.2126 * 0.6, 0.7152 * 0.6, 0.0722 * 0.6, 0, 0, //
  0, 0, 0, 1, 0,
];

class _EdgeDecisivePainter extends CustomPainter {
  _EdgeDecisivePainter({
    required this.action,
    required this.direction,
    required this.reach,
    required this.orbCenter,
    required this.lensRadius,
  });

  final EdgeAction action;
  final OrbDirection direction;
  final double reach;
  final Offset? orbCenter;
  final double lensRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final color = action.color;

    // ---- 1. Edge colour filter (tints), or darken band (reject) ----------
    if (action.desaturates) {
      // The grayscale is applied by the BackdropFilter; add a darkening slate
      // band so the edge reads as "colour draining away".
      canvas.drawRect(
        rect,
        Paint()
          ..shader = _edgeGradient(direction, [
            color.withValues(alpha: (0.55 * reach).clamp(0, 1)),
            color.withValues(alpha: 0.0),
          ]).createShader(rect),
      );
    } else {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = _edgeGradient(direction, [
            color.withValues(alpha: (0.62 * reach).clamp(0, 1)),
            color.withValues(alpha: 0.0),
          ]).createShader(rect),
      );
    }

    // ---- 2. Orb aura recolour -------------------------------------------
    final c = orbCenter;
    if (c == null) return;
    final auraR = lensRadius * 2.0;
    if (action.desaturates) {
      // Darken the orb instead of tinting it (no colour to lean toward).
      canvas.drawCircle(
        c,
        auraR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF0E1417).withValues(alpha: 0.5 * reach),
              const Color(0xFF0E1417).withValues(alpha: 0.0),
            ],
            stops: const [0.0, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: auraR)),
      );
    } else {
      // Additive coloured glow — the orb leans into the action colour.
      canvas.drawCircle(
        c,
        auraR,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.55 * reach),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: auraR)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EdgeDecisivePainter old) =>
      old.action != action ||
      old.direction != direction ||
      old.reach != reach ||
      old.orbCenter != orbCenter ||
      old.lensRadius != lensRadius;
}
