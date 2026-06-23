import 'package:flutter/material.dart';

import '../../../components/bubble/calm_home_field.dart';
import '../../../components/orb/vybia_orb.dart';
import '../../../core/media/image_ref.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/edge_action.dart';
import '../../../shared/edge_decisive.dart';
import '../../../shared/edge_labels.dart';
import '../../../shared/edge_palette.dart';
import '../data/accueil_backdrop.dart';
import '../model/moment.dart';
import '../state/guest_controller.dart';

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
///
/// S22B — the DECISIVE EDGE EFFECT is restored here. Accueil drives the orb
/// directly (not via [SceneScaffold]), and the S21 refactor that moved the
/// decisive overlay into SceneScaffold left this hub without it — so the founder
/// saw the orb coloration + gradient filter vanish on the home screen. This now
/// wires the orb's live aim into an [EdgeDecisiveOverlay] exactly like every
/// other scene, with one decisive action per hub direction.
class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  // Live orb aim + position flow through ValueNotifiers (no setState per move),
  // so only the repaint-isolated decisive overlay rebuilds while the orb tracks
  // the finger — the same latency-safe pattern SceneScaffold uses (S21A).
  final ValueNotifier<Offset?> _orb = ValueNotifier<Offset?>(null);
  final ValueNotifier<OrbAim> _aim = ValueNotifier<OrbAim>(OrbAim.rest);

  // S19E: a real, time-/mood-fitting backdrop chosen once per visit. Computed in
  // [didChangeDependencies] (it reads the persisted history) so it's stable for
  // the rebuilds the orb notifiers drive, never re-rolled on a finger move.
  AccueilBackdrop? _backdrop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_backdrop != null) return;
    final moment = MomentContext.now();
    final memory = GuestScope.of(context).store?.readMemory();
    _backdrop = accueilBackdropFor(
      moment: moment,
      usualMood: memory?.usualMoodFor(moment.slot),
      winter: _isWinter(moment),
    );
  }

  static bool _isWinter(MomentContext m) {
    final month = DateTime.now().month;
    return month == 12 || month == 1 || month == 2;
  }

  /// One decisive action per hub direction, so each edge filters the calm field
  /// toward its own hue (and the orb leans into it). No `reject` on the hub —
  /// every direction here is a welcome destination.
  static EdgeAction _actionFor(OrbDirection? d) {
    switch (d) {
      case OrbDirection.left: // Explorer → curiosity (glacier blue)
        return EdgeAction.curious;
      case OrbDirection.right: // Planifier → go / commit (sea-glass green)
        return EdgeAction.go;
      case OrbDirection.up: // Mon profil → warm welcome (champagne)
        return EdgeAction.joy;
      case OrbDirection.down: // Mes plans → calm neutral (mist cyan)
        return EdgeAction.neutral;
      case null:
        return EdgeAction.neutral;
    }
  }

  @override
  void dispose() {
    _orb.dispose();
    _aim.dispose();
    super.dispose();
  }

  void _go(OrbDirection d) {
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: VybiaOrb(
        // The orb is the primary chooser; it's visible against the calm field.
        showOrb: true,
        enableHoldHome: false, // already home — a still hold is a no-op
        onDirection: _go,
        onPositionChanged: (p) => _orb.value = p,
        onAim: (a) => _aim.value = a,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // S19E: a REAL image that fits the hour / day / usual mood sits at
            // the base, with the validated sea-glass [CalmHomeField] veiled over
            // it (the orb feel + water theme are UNTOUCHED — the field is simply
            // semi-transparent now so a fitting photo gives Accueil time-of-day
            // depth and invites the guest to be guided to an activity).
            _AccueilBackground(image: _backdrop?.image),

            // S22B: the decisive edge filter — the calm field tints toward the
            // aimed direction's hue as the orb nears that edge, then clears on
            // release. Repaint-isolated + palette-aware (a live A/B flip
            // recolours a held wave).
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_aim, _orb, activeEdgePaletteIndex]),
                builder: (context, _) {
                  final aim = _aim.value;
                  return EdgeDecisiveOverlay(
                    action: _actionFor(aim.direction),
                    direction: aim.direction,
                    reach: aim.reach,
                    secondaryAction: _actionFor(aim.secondary),
                    secondaryDirection: aim.secondary,
                    blend: aim.blend,
                    orbCenter: _orb.value,
                  );
                },
              ),
            ),

            // The four directions are always visible here — a hub should make
            // its choices legible at a glance (low cognitive load). Each label
            // glows in the SAME colour as the wave it triggers (S22B), recoloured
            // live by the active palette.
            ValueListenableBuilder<int>(
              valueListenable: activeEdgePaletteIndex,
              builder: (context, _, _) {
                final p = activeEdgePalette;
                return IgnorePointer(
                  child: EdgeLabels(
                    left: 'Explorer',
                    right: 'Planifier',
                    up: 'Mon profil',
                    down: 'Mes plans',
                    leftColor: p.colorFor(_actionFor(OrbDirection.left)),
                    rightColor: p.colorFor(_actionFor(OrbDirection.right)),
                    upColor: p.colorFor(_actionFor(OrbDirection.up)),
                    downColor: p.colorFor(_actionFor(OrbDirection.down)),
                  ),
                );
              },
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
                        // S19E: a calm, time-aware invitation to be guided.
                        _backdrop?.invite ??
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

/// S19E — the Accueil base layer: a real, time-fitting photo (when one is known)
/// under the validated sea-glass [CalmHomeField], which is veiled semi-opaque so
/// the water/glass theme still dominates while the photo gives the hour its own
/// depth. With no image (e.g. very first launch before any history) it degrades
/// to exactly the old full-bleed calm field, so nothing regresses.
class _AccueilBackground extends StatelessWidget {
  const _AccueilBackground({this.image});

  final String? image;

  @override
  Widget build(BuildContext context) {
    final img = image;
    if (img == null) return const CalmHomeField();
    return Stack(
      fit: StackFit.expand,
      children: [
        // The fitting photo, gently darkened so the pearl welcome copy reads.
        Image(
          image: imageProviderFor(img),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        // The sea-glass field as a translucent veil — theme intact, photo reads
        // through ~a third. (Orb/edge effects layer above, untouched.)
        const Opacity(opacity: 0.66, child: CalmHomeField()),
      ],
    );
  }
}
