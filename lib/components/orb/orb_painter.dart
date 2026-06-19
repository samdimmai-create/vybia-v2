import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Paints the living Vybia orb: a warm pearl core wrapped in layered teal/cyan
/// glow and orbiting rings. [pulse] (0..1) drives a soft breathing motion;
/// [reach] (0..1) is how far the finger has dragged toward [direction], used to
/// bias the glow toward the active edge. [opacity] fades the whole orb for the
/// dissolve.
class OrbPainter extends CustomPainter {
  OrbPainter({
    required this.pulse,
    required this.opacity,
    required this.reach,
    required this.direction,
  });

  final double pulse;
  final double opacity;
  final double reach;
  final OrbDirection? direction;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.001) return;
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.shortestSide / 2;
    final breathe = 1.0 + 0.045 * math.sin(pulse * 2 * math.pi);
    final r = baseR * breathe;

    final edgeColor =
        direction == null ? AppColors.accent : AppColors.edgeFor(direction!);

    // Bias offset: glow leans toward the active edge as reach grows.
    Offset bias = Offset.zero;
    if (direction != null) {
      final amt = baseR * 0.18 * reach;
      switch (direction!) {
        case OrbDirection.left:
          bias = Offset(-amt, 0);
          break;
        case OrbDirection.right:
          bias = Offset(amt, 0);
          break;
        case OrbDirection.up:
          bias = Offset(0, -amt);
          break;
        case OrbDirection.down:
          bias = Offset(0, amt);
          break;
      }
    }

    // ---- Outer atmospheric glow ----------------------------------------
    final glowCenter = center + bias;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          edgeColor.withValues(alpha: 0.42 * opacity),
          AppColors.primary.withValues(alpha: 0.22 * opacity),
          AppColors.primary.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: glowCenter, radius: r * 1.9));
    canvas.drawCircle(glowCenter, r * 1.9, glowPaint);

    // ---- Orbiting rings -------------------------------------------------
    for (var i = 0; i < 3; i++) {
      final t = (pulse + i / 3) % 1.0;
      final ringR = r * (1.05 + 0.32 * t);
      final ringOpacity = (1.0 - t) * 0.5 * opacity;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 + 1.2 * (1 - t)
        ..color = AppColors.accent.withValues(alpha: ringOpacity);
      canvas.drawCircle(center, ringR, ringPaint);
    }

    // ---- Glass body -----------------------------------------------------
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [
          AppColors.pearl.withValues(alpha: 0.95 * opacity),
          AppColors.accent.withValues(alpha: 0.78 * opacity),
          AppColors.primary.withValues(alpha: 0.55 * opacity),
          edgeColor.withValues(alpha: 0.45 * opacity),
        ],
        stops: const [0.0, 0.4, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bodyPaint);

    // ---- Inner pearl core (specular highlight) -------------------------
    final coreCenter = center + Offset(-r * 0.22, -r * 0.26);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.pearl.withValues(alpha: 0.98 * opacity),
          AppColors.pearl.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: coreCenter, radius: r * 0.5));
    canvas.drawCircle(coreCenter, r * 0.5, corePaint);

    // ---- Rim light ------------------------------------------------------
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.pearl.withValues(alpha: 0.30 * opacity);
    canvas.drawCircle(center, r * 0.98, rimPaint);
  }

  @override
  bool shouldRepaint(covariant OrbPainter old) =>
      old.pulse != pulse ||
      old.opacity != opacity ||
      old.reach != reach ||
      old.direction != direction;
}
