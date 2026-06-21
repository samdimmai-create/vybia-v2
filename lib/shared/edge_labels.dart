import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import 'glass.dart';

/// Four centered edge labels (left/right/up/down) tinted with their edge color.
/// Labels sit centered on each screen edge — never in the corners — and are
/// pinned with explicit insets so they can never overflow the viewport.
class EdgeLabels extends StatelessWidget {
  const EdgeLabels({
    super.key,
    this.left,
    this.right,
    this.up,
    this.down,
    this.leftColor,
    this.rightColor,
    this.upColor,
    this.downColor,
  });

  /// Null (or empty) labels are simply not drawn — so a 2-choice scene shows
  /// only its left/right chips.
  final String? left;
  final String? right;
  final String? up;
  final String? down;

  /// Per-edge chip tints. When supplied (by [SceneScaffold], from the active
  /// palette's per-action colour) each label glows in the SAME colour as the
  /// wave it triggers — so the label reads as a preview of the decisive filter.
  /// Falls back to the fixed directional accent when null.
  final Color? leftColor;
  final Color? rightColor;
  final Color? upColor;
  final Color? downColor;

  bool _has(String? s) => s != null && s.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_has(left))
              Positioned(
                left: AppSpacing.md,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _Chip(
                    label: left!,
                    color: leftColor ?? AppColors.edgeLeft,
                  ),
                ),
              ),
            if (_has(right))
              Positioned(
                right: AppSpacing.md,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _Chip(
                    label: right!,
                    color: rightColor ?? AppColors.edgeRight,
                  ),
                ),
              ),
            if (_has(up))
              // Pinned just below the status bar (SafeArea), centred. The top
              // scrim reserves space below this band so it never overlaps the
              // badge or headline (see SceneScaffold._TopScrim).
              Positioned(
                top: AppSpacing.xs,
                left: 0,
                right: 0,
                child: Center(
                  child: _Chip(label: up!, color: upColor ?? AppColors.edgeUp),
                ),
              ),
            if (_has(down))
              Positioned(
                bottom: AppSpacing.xl,
                left: 0,
                right: 0,
                child: Center(
                  child: _Chip(
                    label: down!,
                    color: downColor ?? AppColors.edgeDown,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A liquid-glass choice label (S9.3): the same sea-glass capsule as the info
/// bubble's chips, glassily tinted with the edge's decisive-action [color]
/// (intéressant gold / pas-intéressant slate / plus-d'infos lavender / planifier
/// sea-glass green). Light over the photo, distinct via the rim + glow, and the
/// label stays instantly legible — a brightened tint glyph over the glass body,
/// carrying the [kGlassTextShadow] so it reads fast on bright OR dark images.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Lift the edge colour toward pearl so the glyph keeps strong contrast on
    // top of its own glassy tint, then let the shadow carry it over busy/bright
    // photos.
    final text = Color.alphaBlend(Colors.white.withValues(alpha: 0.30), color);
    return GlassCapsule(
      tint: color,
      strong: true,
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          shadows: kGlassTextShadow,
        ),
      ),
    );
  }
}
