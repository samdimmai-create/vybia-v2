import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart' show OrbDirection;
import '../data/assets.dart';
import '../model/dimension.dart';
import '../state/guest_controller.dart';
import '../widgets/scene_scaffold.dart';

/// Guest entry — no account. "Comment veux-tu te sentir ?" is the first (mood)
/// capture: the four orb directions are four moods, each seeding the engine
/// with correlated priors before the adaptive questions begin.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final guest = GuestScope.of(context);

    void choose(OrbDirection d) {
      // mood value 0..1 (calm → energetic) plus correlated nudges.
      switch (d) {
        case OrbDirection.left: // posé
          guest.setMood(0.15, nudges: {
            Dimension.energy: 0.2,
            Dimension.vibe: 0.2,
            Dimension.social: 0.3,
          });
        case OrbDirection.up: // curieux
          guest.setMood(0.5, nudges: {
            Dimension.novelty: 0.8,
            Dimension.energy: 0.55,
          });
        case OrbDirection.right: // sociable
          guest.setMood(0.7, nudges: {
            Dimension.social: 0.85,
            Dimension.vibe: 0.7,
          });
        case OrbDirection.down: // plein d’énergie
          guest.setMood(0.95, nudges: {
            Dimension.energy: 0.9,
            Dimension.vibe: 0.8,
          });
      }
      // S9B: mood handed off to the adaptive engine LOOP (question batches ↔
      // reco rounds, alternating until Planifier), not the old linear discover.
      Navigator.of(context).pushReplacementNamed(AppRouter.engine);
    }

    return SceneScaffold(
      image: Img.calm,
      headline: 'Comment veux-tu te sentir ?',
      prompt: 'Sans compte, sans détour. Choisis avec l’orbe.',
      bottomBubble: true,
      onDirection: choose,
      left: 'Posé',
      up: 'Curieux',
      right: 'Sociable',
      down: 'Plein d’énergie',
      // Hold-to-home returns to the calm Accueil hub (S8).
    );
  }
}
