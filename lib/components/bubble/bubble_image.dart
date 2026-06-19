import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'bubble_glass_painter.dart';

/// The two bubble silhouettes used across Vybia.
enum BubbleShape {
  /// Round bubble — used for emotions.
  circle,

  /// Rounded portrait card — used for recommendations.
  card,
}

/// The UNIVERSAL bubble-over-image effect.
///
/// Every image in Vybia (emotions AND recommendations) is rendered through this
/// one component, so the liquid-glass treatment is identical everywhere. It:
///   1. clips the image to a bubble shape (circle or rounded card),
///   2. lays the brand sea-glass glass overlay on top ([BubbleGlassPainter]),
///   3. floats an optional caption on a legibility scrim,
///   4. casts a soft outer glow so the bubble lifts off the field.
///
/// It owns no gesture logic — wrap it in [VybiaOrb] or a tap handler upstream.
class BubbleImage extends StatelessWidget {
  const BubbleImage({
    super.key,
    required this.image,
    this.shape = BubbleShape.card,
    this.label,
    this.subtitle,
    this.size,
    this.aspectRatio = 0.78,
    this.tint = AppColors.primary,
    this.highlighted = false,
    this.semanticLabel,
  });

  final ImageProvider image;
  final BubbleShape shape;
  final String? label;
  final String? subtitle;

  /// Circle: diameter. Card: width. Null → fills the parent's width.
  final double? size;

  /// Card height = width / aspectRatio (ignored for circle).
  final double aspectRatio;

  final Color tint;
  final bool highlighted;
  final String? semanticLabel;

  bool get _isCircle => shape == BubbleShape.circle;

  @override
  Widget build(BuildContext context) {
    final radius = _isCircle ? 0.0 : AppRadius.xl;
    final borderRadius =
        _isCircle ? null : BorderRadius.circular(radius);

    Widget bubble = LayoutBuilder(
      builder: (context, constraints) {
        final w = size ?? constraints.maxWidth;
        final h = _isCircle ? w : w / aspectRatio;
        return SizedBox(
          width: w,
          height: h,
          child: ClipPath(
            clipper: _BubbleClipper(isCircle: _isCircle, radius: radius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1 — the image.
                Image(
                  image: image,
                  fit: BoxFit.cover,
                  // Never gate visibility on a loadingBuilder (V1 web bug);
                  // degrade gracefully to the brand wash if an asset is missing.
                  errorBuilder: (_, _, _) => const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppColors.bgWash),
                  ),
                ),
                // 2 — the universal glass overlay.
                CustomPaint(
                  painter: BubbleGlassPainter(
                    isCircle: _isCircle,
                    radius: radius,
                    tint: tint,
                    highlighted: highlighted,
                  ),
                ),
                // 3 — caption.
                if (label != null) _caption(context),
              ],
            ),
          ),
        );
      },
    );

    // 4 — outer glow lifts the bubble off the sea-glass field.
    bubble = DecoratedBox(
      decoration: BoxDecoration(
        shape: _isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: (highlighted ? tint : AppColors.primary)
                .withValues(alpha: highlighted ? 0.40 : 0.22),
            blurRadius: highlighted ? 38 : 26,
            spreadRadius: highlighted ? 2 : 0,
          ),
        ],
      ),
      child: bubble,
    );

    return Semantics(
      label: semanticLabel ?? label,
      image: true,
      child: bubble,
    );
  }

  Widget _caption(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.all(
          _isCircle ? AppSpacing.sm : AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label!,
              textAlign: TextAlign.center,
              maxLines: _isCircle ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: (_isCircle ? t.titleMedium : t.titleLarge)?.copyWith(
                color: AppColors.pearl,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 8),
                ],
              ),
            ),
            if (subtitle != null && !_isCircle) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 6),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Clips content to the bubble silhouette so the glass and image share one edge.
class _BubbleClipper extends CustomClipper<Path> {
  _BubbleClipper({required this.isCircle, required this.radius});

  final bool isCircle;
  final double radius;

  @override
  Path getClip(Size size) {
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
  bool shouldReclip(covariant _BubbleClipper old) =>
      old.isCircle != isCircle || old.radius != radius;
}
