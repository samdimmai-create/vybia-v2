import 'package:flutter/material.dart';

import '../../../core/geo/geo.dart';
import '../../../core/geo/location_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/edge_action.dart';
import '../../guest/model/dimension.dart';
import '../../guest/state/guest_controller.dart';
import '../../guest/widgets/reflection_slides.dart';
import '../../guest/widgets/reflection_transition.dart';
import '../../guest/widgets/scene_scaffold.dart';
import '../../plans/screens/planifier_screen.dart';
import '../model/activity.dart';
import '../model/recommendation.dart';
import '../state/reco_controller.dart';
import 'reco_detail_overlay.dart';

/// The bottom-bubble info line: "à 1,4 km · Café" (distance folded in only when
/// the location is known). Kept to one tidy line of real context.
String _infoLine(Recommendation rec) {
  final parts = <String>[
    if (rec.distanceKm != null) formatDistance(rec.distanceKm!),
    rec.activity.category.labelFr,
  ];
  return parts.join(' · ');
}

/// Up to two short vibe tags derived from the activity's taste axes, so the
/// bubble reads like a curated proposal ("• posé", "• calme").
List<String> _vibeTags(Activity a) {
  final tags = <String>[];
  final vibe = a.tag(Dimension.vibe);
  if (vibe <= 0.4) {
    tags.add('intime');
  } else if (vibe >= 0.65) {
    tags.add('animé');
  } else {
    tags.add('posé');
  }
  final energy = a.tag(Dimension.energy);
  if (energy <= 0.35) {
    tags.add('calme');
  } else if (energy >= 0.7) {
    tags.add('énergique');
  }
  return tags;
}

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

  // S8.1E: a brief "Vybia réfléchit" reflection plays first (exploration entry),
  // replaying the just-captured preferences, then reveals the recommendations.
  // Skipped for the deterministic proof/autodrive captures.
  bool _reflecting = !(bool.fromEnvironment('VYBIA_AUTODRIVE') ||
      bool.fromEnvironment('VYBIA_DETAIL') ||
      bool.fromEnvironment('VYBIA_SKIP_REFLECTION'));
  List<ReflectionSlide> _reflectSlides = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Build once, from the shared guest profile captured during discovery.
    // Threads the same store so likes/dislikes persist across relaunches.
    final guest = GuestScope.of(context);
    if (_reco == null) {
      _reco = RecoController(profile: guest.profile, store: guest.store);
      _reflectSlides = exploreReflectionSlides(guest.profile);
      _resolveLocation(); // guest-friendly: requested now, never a hard gate
      // Debug-only: open Plus d'infos on load for the visible proof capture.
      if (const bool.fromEnvironment('VYBIA_DETAIL')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _showDetail = true);
        });
      }
    }
  }

  // Debug-only location injection for the visible reranking proof:
  // `--dart-define=VYBIA_GEO=45.55,-73.62`. Empty in real builds.
  static const String _kGeoOverride = String.fromEnvironment('VYBIA_GEO');

  /// Ask for the guest's location AFTER they've reached the recommendations
  /// (value first). Resolves to a real fix or the Montréal-centre fallback —
  /// either way the reco loop re-ranks so nearer places move up.
  Future<void> _resolveLocation() async {
    final override = _parseGeoOverride();
    if (override != null) {
      _reco?.setLocation(override);
      return;
    }
    final result = await const LocationService().locate();
    if (!mounted) return;
    _reco?.setLocation(result);
  }

  GeoResult? _parseGeoOverride() {
    if (_kGeoOverride.isEmpty) return null;
    final parts = _kGeoOverride.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return GeoResult(lat, lng, GeoStatus.granted);
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
        Navigator.of(context).pushNamed(
          AppRouter.plan,
          arguments: PlanifierArgs(activity: rec.activity),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reco = _reco!;
    if (_reflecting) {
      return ReflectionTransition(
        slides: _reflectSlides,
        onDone: () {
          if (mounted) setState(() => _reflecting = false);
        },
      );
    }
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
              // S8.1D: description lives in the V1-style bottom glass bubble;
              // the distance/category/vibe become its single info line + tags.
              bottomBubble: true,
              infoLine: _infoLine(rec),
              tags: _vibeTags(rec.activity),
              left: 'J’aime',
              right: 'Pas pour moi',
              up: 'Plus d’infos',
              down: 'Planifier',
              leftAction: EdgeAction.joy,
              rightAction: EdgeAction.reject,
              upAction: EdgeAction.curious,
              downAction: EdgeAction.go,
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
