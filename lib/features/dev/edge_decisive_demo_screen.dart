import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/guest/data/assets.dart';
import '../../shared/edge_action.dart';
import '../../shared/edge_decisive.dart';

/// `/dev` visual proof for the decisive-edge colour system (Step B).
///
/// Gestures can't be injected on the iOS simulator and JS pointer injection
/// doesn't reach Flutter's gesture layer, so this screen renders the
/// [EdgeDecisiveOverlay] directly at fixed aims — a deterministic, screenshot-
/// able witness that each action colour filters the image from its edge and the
/// orb recolours, and that intensity scales with proximity (reach).
class EdgeDecisiveDemoScreen extends StatelessWidget {
  const EdgeDecisiveDemoScreen({super.key});

  static const _img = Img.walkNight;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.bgWash),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text('Couleurs décisives',
                  style: t.titleLarge?.copyWith(color: AppColors.pearl)),
              Text('Couleur par SENS de l’action (proximité forte).',
                  style: t.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                _cell('J’aime → joie', EdgeAction.joy, OrbDirection.left, 0.92),
                const SizedBox(width: AppSpacing.xs),
                _cell('Pas pour moi → rejet', EdgeAction.reject,
                    OrbDirection.right, 0.92),
              ]),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                _cell('Plus d’infos → curiosité', EdgeAction.curious,
                    OrbDirection.up, 0.92),
                const SizedBox(width: AppSpacing.xs),
                _cell('Planifier → go', EdgeAction.go, OrbDirection.down, 0.92),
              ]),
              const SizedBox(height: AppSpacing.lg),
              Text('Intensité selon la proximité',
                  style: t.titleLarge?.copyWith(color: AppColors.pearl)),
              Text('Même action (go), reach 0,2 → 0,6 → 0,95.',
                  style: t.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                _cell('faible', EdgeAction.go, OrbDirection.down, 0.2),
                const SizedBox(width: AppSpacing.xs),
                _cell('moyen', EdgeAction.go, OrbDirection.down, 0.6),
                const SizedBox(width: AppSpacing.xs),
                _cell('fort', EdgeAction.go, OrbDirection.down, 0.95),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(
      String label, EdgeAction action, OrbDirection dir, double reach) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 0.86,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth, h = c.maxHeight;
              final orb = switch (dir) {
                OrbDirection.left => Offset(w * 0.2, h * 0.5),
                OrbDirection.right => Offset(w * 0.8, h * 0.5),
                OrbDirection.up => Offset(w * 0.5, h * 0.2),
                OrbDirection.down => Offset(w * 0.5, h * 0.8),
              };
              return Stack(
                fit: StackFit.expand,
                children: [
                  const Image(image: AssetImage(_img), fit: BoxFit.cover),
                  EdgeDecisiveOverlay(
                    action: action,
                    direction: dir,
                    reach: reach,
                    orbCenter: orb,
                    lensRadius: w * 0.22,
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      color: AppColors.bg.withValues(alpha: 0.55),
                      child: Text(label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.pearl,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
