import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Four centered edge labels (left/right/up/down) tinted with their edge color.
/// Labels sit centered on each screen edge — never in the corners — and are
/// pinned with explicit insets so they can never overflow the viewport.
class EdgeLabels extends StatelessWidget {
  const EdgeLabels({
    super.key,
    required this.left,
    required this.right,
    required this.up,
    required this.down,
  });

  final String left;
  final String right;
  final String up;
  final String down;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: AppSpacing.md,
              top: 0,
              bottom: 0,
              child: Center(child: _Chip(label: left, color: AppColors.edgeLeft)),
            ),
            Positioned(
              right: AppSpacing.md,
              top: 0,
              bottom: 0,
              child:
                  Center(child: _Chip(label: right, color: AppColors.edgeRight)),
            ),
            Positioned(
              top: AppSpacing.xl,
              left: 0,
              right: 0,
              child: Center(child: _Chip(label: up, color: AppColors.edgeUp)),
            ),
            Positioned(
              bottom: AppSpacing.xl,
              left: 0,
              right: 0,
              child:
                  Center(child: _Chip(label: down, color: AppColors.edgeDown)),
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
