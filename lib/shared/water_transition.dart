import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../components/bubble/calm_home_field.dart';
import '../core/theme/app_colors.dart';

/// S17A — the **signature Vybia water transition**, shared by BOTH the startup
/// SPLASH and the hold-to-home RETURN so the two moments read as one coherent
/// brand gesture.
///
/// A bubble of the calm sea-glass [CalmHomeField] (water / ice / glass) GROWS
/// from [center] and progressively SUBMERGES whatever is beneath it — as if the
/// scene is going underwater — until, at [progress] = 1, it fills the screen and
/// arrives on the calm home field. A soft, blurred wavefront ring rides the
/// growing boundary (the advancing "surface") with a faint chromatic rim, and a
/// gentle aqua veil deepens with progress so the dissolve feels like sinking
/// into water rather than a hard wipe.
///
/// It is a plain, stateless reveal driven entirely by [progress] — the caller
/// owns the timing (an [AnimationController] on the splash, the orb's
/// hold-to-home grow on a scene) — so the same widget can play forward on launch
/// and track a held gesture without any duplicated animation code.
///
/// Renders nothing at all while [progress] ≤ 0, so it costs ~nothing until the
/// transition actually begins.
class WaterReveal extends StatelessWidget {
  const WaterReveal({
    super.key,
    required this.progress,
    required this.center,
    this.seedRadius = 44,
    this.child,
  });

  /// 0 = nothing painted; 1 = the water bubble has grown to fully submerge the
  /// screen. The growth is eased internally so the wavefront accelerates calmly.
  final double progress;

  /// Where the water is born — the orb/bubble centre, so it grows from exactly
  /// where the gesture lives (the finger on a return, the splash orb on launch).
  final Offset center;

  /// The bubble's starting radius (≈ the orb body), so the water swells *out of*
  /// the orb rather than popping from a point.
  final double seedRadius;

  /// The water content revealed inside the growing disc. Defaults to the calm
  /// home field so "arriving" always looks like the same restful place.
  final Widget? child;

  /// The radius that just covers the whole rect from [center] (farthest corner).
  static double coverRadius(Size size, Offset center) {
    final dx = math.max(center.dx, size.width - center.dx);
    final dy = math.max(center.dy, size.height - center.dy);
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0).toDouble();
    if (p <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          final maxR = coverRadius(size, center);
          // Ease the swell so it surges calmly rather than linearly; overshoot
          // the cover radius a touch so the very corners are reached cleanly.
          final eased = Curves.easeInOutCubic.transform(p);
          final r = lerpDouble(seedRadius, maxR * 1.04, eased)!;
          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. The growing disc of calm water/ice/glass.
              ClipPath(
                clipper: _CircleReveal(center, r),
                child: child ?? const CalmHomeField(),
              ),
              // 2. An aqua submersion veil INSIDE the disc that deepens with
              //    progress — the "going underwater" tint. S21D: lifted
              //    0.10→0.16 so the submersion actually reads on the phone.
              ClipPath(
                clipper: _CircleReveal(center, r),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16 * eased),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              // 3. The advancing wavefront: a soft, blurred glowing ring on the
              //    water's surface with a faint chromatic rim. Fades out as the
              //    water fills the screen (nothing left to advance into).
              CustomPaint(
                size: Size.infinite,
                painter: _WavefrontPainter(
                  center: center,
                  radius: r,
                  fade: (1.0 - eased).clamp(0.0, 1.0).toDouble(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Paints the calm advancing surface of the rising water: a blurred pearl ring
/// at [radius] with a faint cyan/champagne chromatic split, so the wavefront
/// reads as a refractive water edge rather than a hard clip.
class _WavefrontPainter extends CustomPainter {
  _WavefrontPainter({
    required this.center,
    required this.radius,
    required this.fade,
  });

  final Offset center;
  final double radius;
  final double fade; // 1 near the start → 0 once submerged

  @override
  void paint(Canvas canvas, Size size) {
    if (fade <= 0.01 || radius <= 0) return;
    final a = fade;

    // S21D — the signature was barely visible: a single faint crest over a calm
    // field reads as nothing. Build a clear-but-calm rising surface:

    // A deep aqua band just inside the advancing surface — the water reads as
    // having DEPTH right behind the crest (the "going underwater" wall), without
    // flooding the whole disc.
    canvas.drawCircle(
      center,
      radius - 10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16)
        ..color = AppColors.primary.withValues(alpha: 0.30 * a),
    );

    // A small train of soft pearl ripple crests trailing the leading surface, so
    // the rise reads as WAVES — wide, blurred, low-contrast, fading inward
    // (calm, never aggressive).
    const crests = <(double, double, double)>[
      (0.0, 3.6, 0.62), // leading crest — brightest
      (-13.0, 2.6, 0.36),
      (-28.0, 1.9, 0.20),
    ];
    for (final (dr, w, op) in crests) {
      final rr = radius + dr;
      if (rr <= 0) continue;
      canvas.drawCircle(
        center,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
          ..color = AppColors.pearl.withValues(alpha: op * a),
      );
    }

    // Faint chromatic split on the leading crest — cyan just inside, champagne
    // just outside — for the refractive "underwater surface" sheen.
    canvas.drawCircle(
      center,
      radius - 4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = AppColors.accent.withValues(alpha: 0.42 * a),
    );
    canvas.drawCircle(
      center,
      radius + 5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..color = AppColors.champagne.withValues(alpha: 0.30 * a),
    );
  }

  @override
  bool shouldRepaint(covariant _WavefrontPainter old) =>
      old.center != center || old.radius != radius || old.fade != fade;
}

/// Clips a child to a growing circle centred at [center] — the rising water.
class _CircleReveal extends CustomClipper<Path> {
  const _CircleReveal(this.center, this.radius);

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(covariant _CircleReveal old) =>
      old.center != center || old.radius != radius;
}
