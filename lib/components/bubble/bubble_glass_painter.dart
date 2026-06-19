import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Paints the universal Vybia "liquid-glass bubble" overlay that sits on top of
/// any image. It does NOT draw the image — the parent clips the image to the
/// bubble shape and this painter lays the glass on top:
///
///   * a curvature vignette so the surface reads as a domed lens,
///   * a large soft specular highlight (the glass shine) near the top-left,
///   * a faint secondary crescent bottom-right,
///   * one or two refraction arcs following the curvature,
///   * a sea-glass rim light.
///
/// The same painter serves emotions (circle) and recos (rounded card) — that is
/// the "universal" part: one glass treatment for every image in the app.
class BubbleGlassPainter extends CustomPainter {
  BubbleGlassPainter({
    required this.isCircle,
    required this.radius,
    required this.tint,
    this.shine = 1.0,
    this.highlighted = false,
  });

  /// Circle (emotions) vs rounded card (recos).
  final bool isCircle;

  /// Corner radius for the card shape (ignored when [isCircle]).
  final double radius;

  /// Brand tint blended into the glass (sea-glass family).
  final Color tint;

  /// 0..1 — overall strength of the glass shine, lets a card animate/recede.
  final double shine;

  /// Selection state — brightens the rim with the tint.
  final bool highlighted;

  Path _shapePath(Size size) {
    if (isCircle) {
      return Path()
        ..addOval(Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: size.shortestSide / 2,
        ));
    }
    return Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(radius),
      ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shapePath(size);
    canvas.save();
    canvas.clipPath(path);

    final rect = Offset.zero & size;
    final s = shine.clamp(0.0, 1.0);

    // ---- Sea-glass tint wash --------------------------------------------
    // Keeps every image inside the brand family instead of reading as a raw
    // photo. Stronger at the bottom where captions live.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tint.withValues(alpha: 0.10 * s),
            tint.withValues(alpha: 0.04 * s),
            AppColors.bg.withValues(alpha: 0.55),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rect),
    );

    // ---- Curvature vignette ---------------------------------------------
    // Darkens the rim so the surface domes toward the viewer like a lens.
    final c = rect.center;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.15, -0.2),
          radius: 0.95,
          colors: [
            Colors.transparent,
            Colors.transparent,
            AppColors.bg.withValues(alpha: 0.28),
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(rect),
    );

    // ---- Primary specular highlight (the glass shine) -------------------
    final shineCenter = Offset(rect.width * 0.30, rect.height * 0.22);
    final shineR = size.shortestSide * (isCircle ? 0.62 : 0.85);
    canvas.drawCircle(
      shineCenter,
      shineR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.pearl.withValues(alpha: 0.42 * s),
            AppColors.pearl.withValues(alpha: 0.10 * s),
            AppColors.pearl.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: shineCenter, radius: shineR)),
    );

    // ---- Secondary crescent (bottom-right bounce light) -----------------
    final crescentCenter = Offset(rect.width * 0.82, rect.height * 0.86);
    final crescentR = size.shortestSide * 0.5;
    canvas.drawCircle(
      crescentCenter,
      crescentR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.18 * s),
            AppColors.accent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: crescentCenter, radius: crescentR)),
    );

    // ---- Refraction arcs -------------------------------------------------
    // Two thin bright arcs hugging the top edge — the signature "bubble" cue.
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0
      ..color = AppColors.pearl.withValues(alpha: 0.40 * s);
    if (isCircle) {
      final rr = size.shortestSide / 2;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: rr * 0.82),
        math.pi * 1.08,
        math.pi * 0.42,
        false,
        arcPaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: rr * 0.64),
        math.pi * 1.18,
        math.pi * 0.22,
        false,
        arcPaint..color = AppColors.pearl.withValues(alpha: 0.22 * s),
      );
    } else {
      final arcRect = Rect.fromLTWH(
        rect.width * 0.10,
        rect.height * 0.05,
        rect.width * 0.8,
        rect.height * 0.5,
      );
      canvas.drawArc(arcRect, math.pi * 1.05, math.pi * 0.5, false, arcPaint);
    }

    // ---- Rim light -------------------------------------------------------
    final rimColor = highlighted
        ? tint.withValues(alpha: 0.85)
        : AppColors.pearl.withValues(alpha: 0.32);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? 2.6 : 1.6
        ..color = rimColor,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BubbleGlassPainter old) =>
      old.isCircle != isCircle ||
      old.radius != radius ||
      old.tint != tint ||
      old.shine != shine ||
      old.highlighted != highlighted;
}
