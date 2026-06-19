import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart' show OrbDirection;
import '../data/assets.dart';
import '../state/guest_controller.dart';
import '../widgets/scene_scaffold.dart';

/// "Maintenant ou planifier ?" — the guest chooses, via the orb, whether they
/// want something for right now or to plan ahead. Closes the S2 guest loop by
/// showing the captured profile recap.
class IntentionScreen extends StatelessWidget {
  const IntentionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final guest = GuestScope.of(context);

    void choose(OrbDirection d) {
      if (d == OrbDirection.left) {
        guest.setIntention(Intention.now);
      } else if (d == OrbDirection.right) {
        guest.setIntention(Intention.plan);
      } else {
        return; // only left/right are offered
      }
      Navigator.of(context).pushReplacementNamed(AppRouter.profileReady);
    }

    return SceneScaffold(
      image: Img.walkNight,
      headline: 'Maintenant ou\nplanifier ?',
      prompt: 'Glisse vers ce qui te ressemble, là tout de suite.',
      left: 'Maintenant',
      right: 'Planifier',
      onDirection: choose,
    );
  }
}
