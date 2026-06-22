import 'package:flutter/material.dart';

import '../../../core/geo/geo.dart';
import '../../../core/geo/location_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/edge_action.dart';
import '../../plans/screens/planifier_screen.dart';
import '../../reco/live/live_availability_service.dart';
import '../../reco/live/weather_service.dart';
import '../../reco/model/recommendation.dart';
import '../../reco/screens/reco_detail_overlay.dart';
import '../engine/loop_controller.dart';
import '../model/dimension.dart';
import '../state/guest_controller.dart';
import '../widgets/reflection_slides.dart';
import '../widgets/reflection_transition.dart';
import '../widgets/scene_scaffold.dart';

/// THE adaptive engine loop, on screen (S9B).
///
/// Drives a [LoopController] and renders whichever phase it's in: a question
/// batch, the reflection bridge, a round of recommendations, or the terminal
/// states. Question answers and reco reactions both flow back into the same
/// profile, so each round visibly sharpens the next — the loop only ends when
/// the guest hits Planifier (which selects an activity) or everything is spent.
class EngineLoopScreen extends StatefulWidget {
  const EngineLoopScreen({
    super.key,
    this.skipReflection = false,
    this.controller,
    this.proof = false,
    this.liveService,
    this.weatherService,
  });

  /// The LIVE availability layer (S10.1B), supplied by the router in the real
  /// app and left null in widget tests so they run fully offline.
  final LiveAvailabilityService? liveService;

  /// The keyless live weather source (S12B), supplied by the router; null in
  /// widget tests so they run with no weather signal.
  final WeatherService? weatherService;

  /// Test/proof seam: collapse the reflection bridge to a single frame so a
  /// widget test can step the loop deterministically.
  final bool skipReflection;

  /// Test/proof seam: drive an externally-owned [LoopController] instead of
  /// building one from the guest profile. When supplied the caller owns its
  /// lifecycle (the S9.1 proof tour steps it deterministically); the screen
  /// neither resolves geolocation nor disposes it.
  final LoopController? controller;

  /// Proof seam (S9.1): render question/reco scenes with the orb + edge labels
  /// AND the bottom bubble both visible, so a single Chrome screenshot shows the
  /// options / reaction edges together with the place + "pourquoi"; also holds
  /// the reflection bridge open for capture.
  final bool proof;

  @override
  State<EngineLoopScreen> createState() => _EngineLoopScreenState();
}

class _EngineLoopScreenState extends State<EngineLoopScreen> {
  LoopController? _loop;
  bool _ownsLoop = false;
  bool _showDetail = false;
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loop == null) {
      final injected = widget.controller;
      if (injected != null) {
        _loop = injected; // caller-owned (proof tour / tests)
        _ownsLoop = false;
      } else {
        final guest = GuestScope.of(context);
        _loop = LoopController(
          profile: guest.profile,
          store: guest.store,
          liveService: widget.liveService,
          weatherService: widget.weatherService,
        );
        _ownsLoop = true;
        _resolveLocation();
      }
    }
  }

  static const String _kGeoOverride = String.fromEnvironment('VYBIA_GEO');

  Future<void> _resolveLocation() async {
    final override = _parseGeoOverride();
    if (override != null) {
      _loop?.setLocation(override);
      return;
    }
    final result = await const LocationService().locate();
    if (!mounted) return;
    _loop?.setLocation(result);
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
    if (_ownsLoop) _loop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loop = _loop!;
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        switch (loop.phase) {
          case LoopPhase.questions:
            return _buildQuestion(loop);
          case LoopPhase.reflection:
            return _buildReflection(loop);
          case LoopPhase.recos:
            return _buildReco(loop);
          case LoopPhase.selected:
            _goToPlan(loop);
            return const _LoopBlank();
          case LoopPhase.exhausted:
            return _ExhaustedView(
              likedCount: loop.reco?.liked.length ?? 0,
            );
        }
      },
    );
  }

  // ---- Questions -----------------------------------------------------------

  Widget _buildQuestion(LoopController loop) {
    final q = loop.currentQuestion!;
    return SceneScaffold(
      key: ValueKey('q_${q.id}'),
      image: q.options.last.image,
      // S15C: fresh Claude wording once it arrives, else the deterministic prompt.
      headline: loop.currentQuestionPrompt ?? q.prompt,
      prompt: 'On affine ton profil au fil de tes choix.',
      bottomBubble: true,
      showPaletteSwitcher: true,
      journeyStep: JourneyStep.taste.index,
      debugProofFull: widget.proof,
      left: q.optionFor(OrbDirection.left)?.label,
      right: q.optionFor(OrbDirection.right)?.label,
      up: q.optionFor(OrbDirection.up)?.label,
      down: q.optionFor(OrbDirection.down)?.label,
      onDirection: (d) {
        final option = q.optionFor(d);
        if (option == null) return;
        loop.answer(option);
      },
    );
  }

  // ---- Reflection ----------------------------------------------------------

  Widget _buildReflection(LoopController loop) {
    if (widget.skipReflection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) loop.reflectionDone();
      });
      return const _LoopBlank();
    }
    return ReflectionTransition(
      key: ValueKey('reflect_${loop.round}'),
      slides: exploreReflectionSlides(loop.profile),
      onDone: loop.reflectionDone,
      // Proof: hold the bridge open so the capture lands a stable frame; the
      // tour advances it explicitly via reflectionDone().
      perSlide: widget.proof
          ? const Duration(seconds: 60)
          : const Duration(milliseconds: 850),
    );
  }

  // ---- Recommendations -----------------------------------------------------

  Widget _buildReco(LoopController loop) {
    final rec = loop.currentReco!;
    return Stack(
      fit: StackFit.expand,
      children: [
        SceneScaffold(
          key: ValueKey('reco_${rec.activity.id}'),
          image: rec.image, // S9F: engine's vibe-aware pick
          badge: rec.isBestPick ? '★ Meilleur choix pour toi' : null,
          headline: rec.activity.titleFr,
          // S15C: Claude-voiced "pourquoi" once it arrives, else deterministic.
          prompt: loop.currentRecoWhy ?? rec.why,
          bottomBubble: true,
          showPaletteSwitcher: true,
          journeyStep: JourneyStep.forYou.index,
          debugProofFull: widget.proof,
          infoLine: _infoLine(rec),
          tags: _vibeTags(rec),
          left: 'Intéressant',
          right: 'Pas intéressant',
          up: 'Plus d’infos',
          down: 'Planifier',
          leftAction: EdgeAction.joy,
          rightAction: EdgeAction.reject,
          upAction: EdgeAction.curious,
          downAction: EdgeAction.go,
          onDirection: (d) => _onRecoDirection(loop, d),
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
  }

  void _onRecoDirection(LoopController loop, OrbDirection d) {
    switch (d) {
      case OrbDirection.left:
        _reactWithLine(loop, liked: true);
      case OrbDirection.right:
        _reactWithLine(loop, liked: false);
      case OrbDirection.up:
        setState(() => _showDetail = true);
      case OrbDirection.down:
        loop.select(); // → LoopPhase.selected → _goToPlan
    }
  }

  /// React, then surface a short acknowledgement line (S15C). Capture the title
  /// BEFORE reacting (reacting advances to the next pick). The line is
  /// Claude-voiced when the proxy is configured, deterministic otherwise.
  void _reactWithLine(LoopController loop, {required bool liked}) {
    final title = loop.currentReco?.activity.titleFr ?? '';
    if (liked) {
      loop.reactInteresting();
    } else {
      loop.reactNotInteresting();
    }
    if (title.isEmpty) return;
    loop.reactionLine(liked: liked, activityTitle: title).then((line) {
      if (!mounted || line.isEmpty) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(line),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
        ));
    });
  }

  void _goToPlan(LoopController loop) {
    if (_navigated) return;
    final rec = loop.reco?.current;
    if (rec == null) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        AppRouter.plan,
        arguments: PlanifierArgs(activity: rec.activity),
      );
    });
  }

  String _infoLine(Recommendation rec) {
    final parts = <String>[
      if (rec.distanceKm != null) formatDistance(rec.distanceKm!),
      rec.activity.category.labelFr,
    ];
    return parts.join(' · ');
  }

  List<String> _vibeTags(Recommendation rec) {
    final a = rec.activity;
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
}

/// A calm sea-glass holding frame for the instant a phase hands off.
class _LoopBlank extends StatelessWidget {
  const _LoopBlank();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.bgWash),
        child: SizedBox.expand(),
      );
}

/// Shown when the loop has run out of questions AND recommendations without a
/// selection (a rare tail — most sessions end on Planifier).
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
                      ? 'Vybia a retenu les $likedCount activité${likedCount > 1 ? 's' : ''} qui t’ont intéressé${likedCount > 1 ? 'es' : 'e'}. '
                          'À chaque réaction, ton profil s’est affiné.'
                      : 'Vybia a affiné ton profil au fil de tes réactions.',
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
