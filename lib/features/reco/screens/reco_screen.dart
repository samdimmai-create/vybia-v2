import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../guest/state/guest_controller.dart';
import '../../guest/widgets/scene_scaffold.dart';
import '../state/reco_controller.dart';
import 'reco_detail_overlay.dart';

/// The core: immersive, all-orb recommendation scenes with live revealed-
/// preference learning.
///
/// Each scene is a full-bleed activity image under the universal bubble with the
/// best pick first and its "pourquoi ça te va" line. Orb directions:
///   left  = J'aime        right = Pas pour moi
///   up    = Plus d'infos  down  = Planifier (S4 stub)
/// A like/dislike re-ranks immediately, so the very next scene reflects it.
class RecoScreen extends StatefulWidget {
  const RecoScreen({super.key});

  @override
  State<RecoScreen> createState() => _RecoScreenState();
}

class _RecoScreenState extends State<RecoScreen> {
  RecoController? _reco;
  bool _showDetail = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Build once, from the shared guest profile captured during discovery.
    _reco ??= RecoController(profile: GuestScope.of(context).profile);
  }

  @override
  void dispose() {
    _reco?.dispose();
    super.dispose();
  }

  void _onDirection(OrbDirection d) {
    final reco = _reco!;
    final rec = reco.current;
    if (rec == null) return;
    switch (d) {
      case OrbDirection.left:
        reco.like();
      case OrbDirection.right:
        reco.dislike();
      case OrbDirection.up:
        setState(() => _showDetail = true);
      case OrbDirection.down:
        Navigator.of(context)
            .pushNamed(AppRouter.plan, arguments: rec.activity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reco = _reco!;
    return AnimatedBuilder(
      animation: reco,
      builder: (context, _) {
        final rec = reco.current;
        if (rec == null) return _ExhaustedView(likedCount: reco.liked.length);

        return Stack(
          fit: StackFit.expand,
          children: [
            SceneScaffold(
              key: ValueKey(rec.activity.id),
              image: rec.activity.image,
              badge: rec.isBestPick ? '★ Meilleur choix pour toi' : null,
              headline: rec.activity.titleFr,
              prompt: rec.why,
              left: 'J’aime',
              right: 'Pas pour moi',
              up: 'Plus d’infos',
              down: 'Planifier',
              onDirection: _onDirection,
            ),
            if (_showDetail)
              Positioned.fill(
                child: RecoDetailOverlay(
                  recommendation: rec,
                  onDismiss: () => setState(() => _showDetail = false),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Shown once the guest has reacted to every recommendation in the session.
class _ExhaustedView extends StatelessWidget {
  const _ExhaustedView({required this.likedCount});

  final int likedCount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final guest = GuestScope.of(context);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.bgWash),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu as tout vu',
                    style: t.displaySmall?.copyWith(color: AppColors.pearl)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  likedCount > 0
                      ? 'Vybia a noté tes $likedCount coup${likedCount > 1 ? 's' : ''} de cœur. '
                          'À chaque choix, le profil s’est affiné.'
                      : 'Vybia a affiné ton profil au fil de tes choix.',
                  style: t.bodyLarge?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.bg,
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    onPressed: () {
                      guest.restart();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRouter.welcome, (_) => false);
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
