import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/activity_catalog.dart';
import '../model/activity.dart';

/// S4 placeholder. Reached by swiping *down* (Planifier) on a reco scene; it
/// confirms the chosen activity and parks the real planning flow for the next
/// sprint. Tapping anywhere returns to the recommendations.
class PlanStubScreen extends StatelessWidget {
  const PlanStubScreen({super.key, required this.activity});

  /// Pulls the [Activity] passed as the route argument, or falls back to the
  /// first catalog entry so a bare `/#/plan` deep link still renders.
  static PlanStubScreen fromRoute(RouteSettings settings) => PlanStubScreen(
        activity: settings.arguments is Activity
            ? settings.arguments as Activity
            : kActivityCatalog.first,
      );

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.bgWash),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('On planifie',
                      style: t.displaySmall?.copyWith(color: AppColors.pearl)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(activity.titleFr,
                      style: t.titleLarge?.copyWith(color: AppColors.accent)),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Vybia retient ce choix. Le vrai parcours de planification '
                    '— date, moment, qui t’accompagne — arrive bientôt.',
                    style: t.bodyLarge?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Icon(Icons.touch_app_outlined,
                          size: 18, color: AppColors.textMuted),
                      const SizedBox(width: AppSpacing.xs),
                      Text('Touche pour revenir aux idées',
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
}
