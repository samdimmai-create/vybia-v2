import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/edge_action.dart';
import '../../guest/data/assets.dart';
import '../../guest/model/dimension.dart';
import '../../guest/state/guest_controller.dart';
import '../../guest/widgets/scene_scaffold.dart';

/// Mon Profil (`/profil`, reached by swiping *up* on Accueil).
///
/// Two things on one immersive, all-orb surface:
///   • Aperçu — "ce que Vybia a appris": the learned profile + the eight declared
///     taste dimensions, each shown with the way it currently leans, over a
///     situational image wearing the universal bubble.
///   • Ajuster — nudge any dimension ENTIRELY via the orb (left/right move it,
///     up = dimension suivante, down = terminé). Every nudge writes through to
///     local storage immediately, so the change survives a relaunch and the
///     recommendation engine reads it next time.
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

enum _Mode { apercu, ajuster }

/// The eight declared taste axes the guest can adjust (mood is captured live on
/// Accueil, not tuned here).
const List<Dimension> _adjustable = [
  Dimension.energy,
  Dimension.social,
  Dimension.novelty,
  Dimension.distance,
  Dimension.indoor,
  Dimension.timing,
  Dimension.budget,
  Dimension.vibe,
];

/// Low ↔ high edge labels per dimension, matching each axis's polarity.
({String low, String high}) _poles(Dimension d) {
  switch (d) {
    case Dimension.energy:
      return (low: 'Plus doux', high: 'Plus tonique');
    case Dimension.social:
      return (low: 'En solo', high: 'Entouré');
    case Dimension.novelty:
      return (low: 'Valeurs sûres', high: 'Du neuf');
    case Dimension.distance:
      return (low: 'Tout près', high: 'Prêt à bouger');
    case Dimension.indoor:
      return (low: 'Au grand air', high: 'À l’intérieur');
    case Dimension.timing:
      return (low: 'En journée', high: 'Plutôt le soir');
    case Dimension.budget:
      return (low: 'Malin', high: 'Sans compter');
    case Dimension.vibe:
      return (low: 'Intime', high: 'Effervescent');
    case Dimension.mood:
      return (low: 'Calme', high: 'En élan');
  }
}

/// A situational backdrop per dimension so the adjust scenes feel grounded.
String _imageFor(int index) {
  const pool = [Img.calm, Img.curious, Img.social, Img.energetic];
  return pool[index % pool.length];
}

class _ProfilScreenState extends State<ProfilScreen> {
  _Mode _mode = _Mode.apercu;
  int _dimIndex = 0;

  static const double _step = 0.18;

  Dimension get _dim => _adjustable[_dimIndex];

  void _onApercu(OrbDirection d) {
    switch (d) {
      case OrbDirection.left:
        setState(() => _mode = _Mode.ajuster); // Ajuster mes goûts
      case OrbDirection.down:
        Navigator.of(context).maybePop(); // Retour à l'accueil
      case OrbDirection.up:
      case OrbDirection.right:
        break; // calm: no dead-edge action
    }
  }

  void _onAjuster(OrbDirection d) {
    final guest = GuestScope.of(context);
    switch (d) {
      case OrbDirection.left:
        guest.adjustDimension(_dim, -_step);
        setState(() {}); // reflect the new reading
      case OrbDirection.right:
        guest.adjustDimension(_dim, _step);
        setState(() {});
      case OrbDirection.up:
        setState(() => _dimIndex = (_dimIndex + 1) % _adjustable.length);
      case OrbDirection.down:
        setState(() => _mode = _Mode.apercu); // Terminé → back to aperçu
    }
  }

  @override
  Widget build(BuildContext context) {
    final guest = GuestScope.of(context);
    // Rebuild the recap whenever the profile changes (e.g. after an adjust).
    return AnimatedBuilder(
      animation: guest,
      builder: (context, _) =>
          _mode == _Mode.apercu ? _buildApercu(guest) : _buildAjuster(guest),
    );
  }

  // ---- Aperçu : ce que Vybia a appris --------------------------------------

  Widget _buildApercu(GuestController guest) {
    final likedCount = guest.store?.readLikedIds().length ?? 0;
    final prompt = likedCount > 0
        ? 'Vybia a retenu $likedCount coup${likedCount > 1 ? 's' : ''} de cœur '
            'et affiné ton profil. Glisse à gauche pour l’ajuster.'
        : 'Voici ce que Vybia a cerné de tes goûts. '
            'Glisse à gauche pour l’ajuster.';
    return Stack(
      fit: StackFit.expand,
      children: [
        SceneScaffold(
          key: const ValueKey('profil_apercu'),
          image: Img.curious,
          badge: 'Mon profil',
          headline: 'Ce que Vybia\na appris',
          prompt: prompt,
          left: 'Ajuster mes goûts',
          leftAction: EdgeAction.curious,
          down: 'Retour',
          downAction: EdgeAction.neutral,
          onDirection: _onApercu,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            child: _LearnedCard(guest: guest),
          ),
        ),
      ],
    );
  }

  // ---- Ajuster : nudge a dimension via the orb -----------------------------

  Widget _buildAjuster(GuestController guest) {
    final d = _dim;
    final poles = _poles(d);
    return SceneScaffold(
      key: ValueKey('profil_ajuster_${d.name}'),
      image: _imageFor(_dimIndex),
      badge: 'Ajuster · ${_dimIndex + 1}/${_adjustable.length}',
      headline: d.labelFr,
      prompt: 'Aujourd’hui : ${guest.profile.readingFor(d)}.\n'
          'Glisse pour ajuster, vers le haut pour la suivante.',
      left: poles.low,
      leftAction: EdgeAction.neutral,
      right: poles.high,
      rightAction: EdgeAction.neutral,
      up: 'Suivante',
      upAction: EdgeAction.curious,
      down: 'Terminé',
      downAction: EdgeAction.go,
      onDirection: _onAjuster,
    );
  }
}

/// A calm glass recap of the eight declared dimensions floated near the bottom
/// of the Aperçu scene (purely informative — the orb drives the surface).
class _LearnedCard extends StatelessWidget {
  const _LearnedCard({required this.guest});

  final GuestController guest;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final profile = guest.profile;
    return SafeArea(
      child: Padding(
        // S6.3: sit clear ABOVE the SceneScaffold's bottom "Touche, glisse…"
        // hint chip (which is itself pinned at bottom: huge) so the last recap
        // row (e.g. Ambiance / feutré) never overlaps the hint.
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.huge + AppSpacing.xxl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in _adjustable)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.labelFr,
                          style: t.labelLarge
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                      Text(
                        profile.readingFor(d),
                        style: t.titleSmall?.copyWith(color: AppColors.pearl),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
