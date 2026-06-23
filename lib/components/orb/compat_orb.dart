import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// S18D — the COMPATIBILITY orb: a small sea-glass droplet that is MORE or LESS
/// FILLED with water to show, at a glance, how well a recommendation fits the
/// guest. The fill level (and the % label) is the engine's match score, so a
/// strong pick reads as an almost-full orb and a weak one as a near-empty one.
///
/// Purely decorative (wrap in [IgnorePointer] upstream so it never steals an orb
/// gesture). On-brand: the fill is literally a little body of water inside the
/// glass bubble, matching the app's water/ice/transparent theme.
class CompatOrb extends StatelessWidget {
  const CompatOrb({super.key, required this.fill, this.size = 56});

  /// 0..1 — how full the orb is (the match score). Clamped on paint.
  final double fill;

  /// Diameter in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pct = (fill.clamp(0.0, 1.0) * 100).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _CompatOrbPainter(fill.clamp(0.0, 1.0).toDouble()),
          ),
          Text(
            '$pct%',
            style: t.labelMedium?.copyWith(
              color: AppColors.pearl,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.26,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatOrbPainter extends CustomPainter {
  _CompatOrbPainter(this.fill);

  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final circle = Rect.fromCircle(center: center, radius: r);

    // The empty glass bubble (faint dark base so the water reads on any photo).
    canvas.drawCircle(
      center,
      r,
      Paint()..color = AppColors.bg.withValues(alpha: 0.45),
    );

    // The water body, clipped to the bubble, rising to the fill level.
    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    final waterTop = center.dy + r - 2 * r * fill;
    canvas.drawRect(
      Rect.fromLTRB(center.dx - r, waterTop, center.dx + r, center.dy + r),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accent.withValues(alpha: 0.85),
            AppColors.primary.withValues(alpha: 0.9),
          ],
        ).createShader(circle),
    );
    // A bright surface line on the water for the liquid feel.
    if (fill > 0.02 && fill < 0.98) {
      canvas.drawLine(
        Offset(center.dx - r, waterTop),
        Offset(center.dx + r, waterTop),
        Paint()
          ..strokeWidth = 1.5
          ..color = AppColors.pearl.withValues(alpha: 0.6),
      );
    }
    canvas.restore();

    // Glass rim + a small specular kick (upper-left), matching the lens look.
    canvas.drawCircle(
      center,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.pearl.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      center + Offset(-r * 0.35, -r * 0.4),
      r * 0.1,
      Paint()
        ..color = AppColors.pearl.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CompatOrbPainter old) => old.fill != fill;
}
