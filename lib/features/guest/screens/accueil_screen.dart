import 'package:flutter/material.dart';

import '../../../components/bubble/calm_home_field.dart';
import '../../../components/orb/vybia_orb.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/edge_labels.dart';

/// The calm, neutral **Accueil** — the app's hub and the destination of the
/// hold-to-home gesture (S8).
///
/// Unlike every other scene it is NOT tied to an activity image: its background
/// is the procedural sea-glass [CalmHomeField] (water / ice / glass), so landing
/// here always feels like arriving somewhere restful rather than being dropped
/// back on a random photo. The four cahier directions are hosted on the orb:
///   gauche = Explorer · droite = Planifier · haut = Mon profil · bas = Mes plans.
///
/// Hold-to-home is disabled here (we're already home), so a still hold is a
/// no-op and can never loop back onto itself.
class AccueilScreen extends StatelessWidget {
  const AccueilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    void go(OrbDirection d) {
      switch (d) {
        case OrbDirection.left: // Explorer → start the mood → discover → reco flow
          Navigator.of(context).pushNamed(AppRouter.welcome);
        case OrbDirection.right: // Planifier
          Navigator.of(context).pushNamed(AppRouter.plan);
        case OrbDirection.up: // Mon profil
          Navigator.of(context).pushNamed(AppRouter.profil);
        case OrbDirection.down: // Mes plans
          Navigator.of(context).pushNamed(AppRouter.mesPlans);
      }
    }

    return Scaffold(
      body: VybiaOrb(
        // The orb is the primary chooser; it's visible against the calm field.
        showOrb: true,
        enableHoldHome: false, // already home — a still hold is a no-op
        onDirection: go,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CalmHomeField(),
            // The four directions are always visible here — a hub should make
            // its choices legible at a glance (low cognitive load).
            const IgnorePointer(
              child: EdgeLabels(
                left: 'Explorer',
                right: 'Planifier',
                up: 'Mon profil',
                down: 'Mes plans',
              ),
            ),
            // Calm welcome copy, floated top-centre over a soft scrim.
            IgnorePointer(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.huge, AppSpacing.lg, AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vybia',
                        style: t.displayMedium?.copyWith(
                          color: AppColors.pearl,
                          shadows: const [
                            Shadow(color: Colors.black45, blurRadius: 12)
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Ton instant, dans quelle direction ?',
                        style: t.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                          shadows: const [
                            Shadow(color: Colors.black38, blurRadius: 8)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Gentle invitation at the foot.
            IgnorePointer(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.huge),
                    child: Text(
                      'Touche, et choisis avec l’orbe',
                      style: t.labelMedium?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
