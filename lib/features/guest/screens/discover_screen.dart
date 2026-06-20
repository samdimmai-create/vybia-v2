import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../state/guest_controller.dart';
import '../widgets/scene_scaffold.dart';

/// The adaptive preference + mood capture loop.
///
/// Renders whatever question the [AdaptiveEngine] currently deems most
/// informative; each orb commit answers it (and nudges correlated dimensions),
/// then the engine re-picks. Once the profile is confident enough the engine is
/// "done" and we move on to Intention — so the guest answers only as many
/// scenes as needed, never a fixed eight.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _navigated = false;

  @override
  Widget build(BuildContext context) {
    final guest = GuestScope.of(context);
    final q = guest.currentQuestion;

    if (q == null) {
      // Profile is confident — advance once, after this frame.
      if (!_navigated) {
        _navigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(AppRouter.intention);
          }
        });
      }
      return const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.bgWash),
      );
    }

    // Backdrop = the "expansive" (right) option so the scene feels aspirational.
    final backdrop = q.options.last.image;

    return SceneScaffold(
      image: backdrop,
      headline: q.prompt,
      prompt: 'On affine ton profil au fil de tes choix.',
      bottomBubble: true,
      left: q.optionFor(OrbDirection.left)?.label,
      right: q.optionFor(OrbDirection.right)?.label,
      up: q.optionFor(OrbDirection.up)?.label,
      down: q.optionFor(OrbDirection.down)?.label,
      onDirection: (d) {
        final option = q.optionFor(d);
        if (option == null) return; // direction not offered → ignore
        guest.answerCurrent(option); // notifies → rebuild picks next question
      },
    );
  }
}
