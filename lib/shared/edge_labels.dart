import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

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
  });

  /// Null (or empty) labels are simply not drawn — so a 2-choice scene shows
  /// only its left/right chips.
  final String? left;
  final String? right;
  final String? up;
  final String? down;

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
                    child: _Chip(label: left!, color: AppColors.edgeLeft)),
              ),
            if (_has(right))
              Positioned(
                right: AppSpacing.md,
                top: 0,
                bottom: 0,
                child: Center(
                    child: _Chip(label: right!, color: AppColors.edgeRight)),
              ),
            if (_has(up))
              Positioned(
                top: AppSpacing.xl,
                left: 0,
                right: 0,
                child:
                    Center(child: _Chip(label: up!, color: AppColors.edgeUp)),
              ),
            if (_has(down))
              Positioned(
                bottom: AppSpacing.xl,
                left: 0,
                right: 0,
                child: Center(
                    child: _Chip(label: down!, color: AppColors.edgeDown)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
