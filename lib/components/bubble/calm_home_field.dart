import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The calm, neutral "home" atmosphere: a fluid sea-glass water / ice / glass
/// field with gentle drifting light. It is intentionally NOT tied to any
/// activity image — it is the orb's resting/neutral theme.
///
/// Reused in two places so "home" always looks the same:
///   * full-bleed behind the [AccueilScreen] (the calm hub), and
///   * clipped to a growing circle as the hold-to-home *portal*, so the orb
///     fills with this calm imagery instead of swirling the activity image
///     into a vortex (S8 — the "non-scary" hold-to-home fix).
///
/// Self-animating (owns its ticker) so it is a drop-in with no wiring.
class CalmHomeField extends StatefulWidget {
  const CalmHomeField({super.key, this.intensity = 1.0});

  /// 0..1 overall presence of the drifting light (the base gradient is always
  /// fully painted so the field is never a black void).
  final double intensity;

  @override
  State<CalmHomeField> createState() => _CalmHomeFieldState();
}

class _CalmHomeFieldState extends State<CalmHomeField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, _) => CustomPaint(
        painter: _CalmFieldPainter(
          t: _drift.value,
          intensity: widget.intensity.clamp(0.0, 1.0).toDouble(),
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Paints the calm sea-glass field: a soft vertical wash, three slowly drifting
/// pools of pearl / cyan / teal light, a faint icy caustic shimmer and a gentle
/// vignette. Restful, premium, low cognitive load — no purple, no black void.
class _CalmFieldPainter extends CustomPainter {
  _CalmFieldPainter({required this.t, required this.intensity});

  final double t; // 0..1 looping
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final tau = t * 2 * math.pi;

    // ---- 1. Base sea-glass wash (always painted — never a void) ----------
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF11272A), // lifted teal at the top
            Color(0xFF0E1C1F),
            Color(0xFF0C1618), // deep sea-glass at the foot
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(rect),
    );

    // ---- 2. Drifting pools of light (water caustics) ---------------------
    void pool(Offset c, double r, Color color, double a) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: a * intensity), color.withValues(alpha: 0.0)],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    final w = size.width, h = size.height;
    pool(
      Offset(w * (0.32 + 0.10 * math.cos(tau)), h * (0.34 + 0.05 * math.sin(tau * 1.1))),
      w * 0.55,
      AppColors.primary,
      0.16,
    );
    pool(
      Offset(w * (0.72 + 0.08 * math.cos(tau * 0.8 + 1.7)), h * (0.62 + 0.06 * math.sin(tau * 0.9))),
      w * 0.5,
      AppColors.accent,
      0.13,
    );
    pool(
      Offset(w * (0.5 + 0.12 * math.sin(tau * 0.7)), h * (0.5 + 0.10 * math.cos(tau * 1.3))),
      w * 0.42,
      AppColors.pearl,
      0.07,
    );

    // ---- 3. Icy caustic streaks (thin, blurred, drifting) ----------------
    final streak = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    for (var i = 0; i < 3; i++) {
      final phase = tau + i * 2.1;
      final y = h * (0.3 + 0.18 * i) + math.sin(phase) * h * 0.03;
      final path = Path()..moveTo(-20, y);
      for (var x = 0.0; x <= w + 20; x += w / 6) {
        path.lineTo(x, y + math.sin(phase + x / w * math.pi * 2) * 10);
      }
      streak
        ..strokeWidth = 1.6
        ..color = AppColors.pearl.withValues(alpha: 0.05 * intensity);
      canvas.drawPath(path, streak);
    }

    // ---- 4. Soft vignette to settle the edges ----------------------------
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.05,
          colors: [
            Colors.transparent,
            AppColors.bg.withValues(alpha: 0.42),
          ],
          stops: const [0.62, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _CalmFieldPainter old) =>
      old.t != t || old.intensity != intensity;
}
