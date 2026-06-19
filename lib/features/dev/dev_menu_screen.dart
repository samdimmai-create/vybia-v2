import 'package:flutter/material.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../guest/state/guest_controller.dart';

/// Hidden developer route (`/dev`): jump straight to any screen so visual tests
/// are never blocked by flow order or guest redirects. Each jump first resets
/// the guest session so the target screen lands in a predictable state.
class DevMenuScreen extends StatelessWidget {
  const DevMenuScreen({super.key});

  static const _entries = <(String, String)>[
    ('Splash', AppRouter.splash),
    ('Welcome (humeur)', AppRouter.welcome),
    ('Découverte (questions adaptatives)', AppRouter.discover),
    ('Intention (maintenant / planifier)', AppRouter.intention),
    ('Reco (scènes immersives)', AppRouter.reco),
    ('Profil prêt (récap)', AppRouter.profileReady),
    ('— Bulle (gros plan réfraction)', AppRouter.bubble),
    ('— Orbe (aperçu)', AppRouter.orbPreview),
    ('— Démo orbe (champ)', AppRouter.orbDemo),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final guest = GuestScope.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.bgWash),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const SizedBox(height: AppSpacing.md),
              Text('Vybia · /dev',
                  style: t.displayMedium?.copyWith(color: AppColors.pearl)),
              const SizedBox(height: AppSpacing.xs),
              Text('Accès direct à chaque écran (tests visuels).',
                  style: t.bodyLarge),
              const SizedBox(height: AppSpacing.lg),
              for (final (label, route) in _entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _NavTile(
                    label: label,
                    onTap: () {
                      guest.restart();
                      Navigator.of(context).pushNamed(route);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: t.titleMedium?.copyWith(color: AppColors.pearl)),
              ),
              const Icon(Icons.chevron_right, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}
