import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../state/guest_controller.dart';

/// Closes the S2 loop: a calm recap of what the adaptive engine learned about
/// the guest (proof the questions actually shaped a profile) plus their chosen
/// intention. Recommendations themselves come in a later sprint.
class ProfileReadyScreen extends StatelessWidget {
  const ProfileReadyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final guest = GuestScope.of(context);
    final t = Theme.of(context).textTheme;
    final readout = guest.profile.readout();
    final intentionLabel = switch (guest.intention) {
      Intention.now => 'Pour maintenant',
      Intention.plan => 'À planifier',
      null => '—',
    };

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.bgWash),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Text('Ton profil est prêt',
                    style: t.displayMedium?.copyWith(color: AppColors.pearl)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'En quelques gestes, Vybia a cerné ton instant. '
                  '$intentionLabel.',
                  style: t.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final r in readout)
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.sm),
                              child: Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(
                                        right: AppSpacing.sm),
                                    decoration: const BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(children: [
                                        TextSpan(
                                          text: '${r.dim.labelFr} · ',
                                          style: t.labelLarge?.copyWith(
                                              color: AppColors.textMuted),
                                        ),
                                        TextSpan(
                                          text: r.reading,
                                          style: t.titleMedium?.copyWith(
                                              color: AppColors.pearl),
                                        ),
                                      ]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.bg,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    onPressed: () {
                      guest.restart();
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil(AppRouter.welcome, (_) => false);
                    },
                    child: const Text('Recommencer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
