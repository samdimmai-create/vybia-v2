import 'package:flutter/material.dart';

import '../../../core/geo/geo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../model/recommendation.dart';

/// "Plus d'infos" overlay (orb disabled, tap anywhere to dismiss — the
/// info/detail contract). Shows the full activity description plus the
/// "Pourquoi pour toi" reading the engine generated.
class RecoDetailOverlay extends StatelessWidget {
  const RecoDetailOverlay({
    super.key,
    required this.recommendation,
    required this.onDismiss,
  });

  final Recommendation recommendation;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = recommendation.activity;
    final budgetLabel =
        ['Gratuit', 'Économique', 'Prix moyen', 'À s’offrir'][a.budget.clamp(0, 3)];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: Container(
        color: AppColors.bg.withValues(alpha: 0.82),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Text(a.category.labelFr.toUpperCase(),
                      style: t.labelMedium?.copyWith(
                          color: AppColors.accent, letterSpacing: 1.5)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(a.titleFr,
                      style: t.displaySmall?.copyWith(color: AppColors.pearl)),
                  const SizedBox(height: AppSpacing.md),
                  Text(a.descFr,
                      style: t.bodyLarge
                          ?.copyWith(color: AppColors.textSecondary, height: 1.4)),
                  const SizedBox(height: AppSpacing.lg),
                  _block(
                    t,
                    title: 'Pourquoi pour toi',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(recommendation.why,
                            style:
                                t.titleMedium?.copyWith(color: AppColors.pearl)),
                        // S11D: the honest top contributing factors behind this
                        // pick — the deterministic, specific "pourquoi".
                        if (recommendation.factors.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final f in recommendation.factors)
                                _factorChip(t, f),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (recommendation.distanceKm != null)
                        _chip(t, formatDistanceEta(recommendation.distanceKm!)),
                      // S12C: real enriched facts (Geoapify/Foursquare), shown
                      // only when present — additive, never blocks the card.
                      if (a.rating != null)
                        _chip(t, '★ ${a.rating!.toStringAsFixed(1)}'),
                      if (a.openingHours != null &&
                          a.openingHours!.trim().isNotEmpty)
                        _chip(t, a.openingHours!),
                      _chip(t, budgetLabel),
                      _chip(t, a.indoor ? 'Intérieur' : 'Plein air'),
                      for (final d in recommendation.topDimensions)
                        _chip(t, d.labelFr),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Icon(Icons.touch_app_outlined,
                          size: 18, color: AppColors.textMuted),
                      const SizedBox(width: AppSpacing.xs),
                      Text('Touche pour revenir',
                          style: t.labelLarge
                              ?.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _block(TextTheme t, {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: t.labelSmall
                  ?.copyWith(color: AppColors.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }

  /// A factor chip — the engine's real top scoring terms, accented to read as
  /// the "why" rather than the neutral fact chips below.
  Widget _factorChip(TextTheme t, String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Text(label,
          style: t.labelMedium?.copyWith(color: AppColors.pearl)),
    );
  }

  Widget _chip(TextTheme t, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: t.labelMedium?.copyWith(color: AppColors.textSecondary)),
    );
  }
}
