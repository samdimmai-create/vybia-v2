import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/bubble/refraction_bubble.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/edge_action.dart';
import '../guest/data/assets.dart';
import '../guest/screens/accueil_screen.dart';
import '../guest/widgets/reflection_transition.dart';
import '../guest/widgets/scene_scaffold.dart';

/// Debug-only visual-proof tour for Sprint S8.1
/// (`--dart-define=VYBIA_PROOF81=true`).
///
/// Walks every S8.1 target state deterministically, pausing on each and
/// printing `VYBIA_PROOF <name>` so the capture script can grab each frame
/// crosshair-free with `xcrun simctl io booted screenshot`.
class S81ProofTour extends StatefulWidget {
  const S81ProofTour({super.key});

  @override
  State<S81ProofTour> createState() => _S81ProofTourState();
}

class _S81ProofTourState extends State<S81ProofTour> {
  static const _hold = Duration(seconds: 7);
  int _i = 0;
  Timer? _timer;

  // A long per-slide so the reflection stops hold a stable frame for capture.
  static const _frozen = Duration(seconds: 60);

  static SceneScaffold _reco({
    required String headline,
    OrbDirection? aim,
    bool contact = false,
  }) =>
      SceneScaffold(
        image: Img.cafe,
        badge: '★ Meilleur choix pour toi',
        headline: headline,
        prompt: 'Une pause douce, un café soigné, le temps qui ralentit.',
        bottomBubble: true,
        infoLine: 'à 1,4 km · Café',
        tags: const ['posé', 'calme'],
        left: 'J’aime',
        right: 'Pas pour moi',
        up: 'Plus d’infos',
        down: 'Planifier',
        leftAction: EdgeAction.joy,
        rightAction: EdgeAction.reject,
        upAction: EdgeAction.curious,
        downAction: EdgeAction.go,
        onDirection: (_) {},
        debugAimProof: aim,
        debugContactProof: contact,
      );

  late final List<(String, Widget)> _stops = [
    ('orb_compare', const _OrbSizeCompare()),
    ('card_rest', _reco(headline: 'Café Olimpico')),
    ('card_contact', _reco(headline: 'Café Olimpico', contact: true)),
    ('edge_wave_joy',
        _reco(headline: 'Café Olimpico', aim: OrbDirection.left)),
    ('edge_wave_reject',
        _reco(headline: 'Café Olimpico', aim: OrbDirection.right)),
    ('edge_wave_curious',
        _reco(headline: 'Café Olimpico', aim: OrbDirection.up)),
    ('edge_wave_go',
        _reco(headline: 'Café Olimpico', aim: OrbDirection.down)),
    (
      'reflection_explore',
      ReflectionTransition(
        perSlide: _frozen,
        onDone: () {},
        slides: const [
          ReflectionSlide(image: Img.calm, label: 'Énergie · doux'),
          ReflectionSlide(image: Img.social, label: 'Social · entouré'),
          ReflectionSlide(image: Img.curious, label: 'Nouveauté · ouvert'),
        ],
      ),
    ),
    (
      'reflection_plan',
      ReflectionTransition(
        title: 'Vybia prépare ton plan',
        perSlide: _frozen,
        onDone: () {},
        slides: const [
          ReflectionSlide(image: Img.theatre, label: 'Pour « Théâtre du Nouveau Monde »'),
          ReflectionSlide(image: Img.theatre, label: 'Ce soir'),
          ReflectionSlide(image: Img.theatre, label: 'En couple'),
        ],
      ),
    ),
    (
      'hold_warning',
      SceneScaffold(
        image: Img.viewpoint,
        headline: 'Belvédère Kondiaronk',
        bottomBubble: true,
        infoLine: 'à 2,1 km · Belvédère',
        onDirection: (_) {},
        debugWarnProof: true,
      ),
    ),
    (
      'hold_portal',
      SceneScaffold(
        image: Img.viewpoint,
        headline: 'Belvédère Kondiaronk',
        bottomBubble: true,
        infoLine: 'à 2,1 km · Belvédère',
        onDirection: (_) {},
        debugHoldProof: true,
      ),
    ),
    ('home_landed', const AccueilScreen()),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
    _timer = Timer.periodic(_hold, (_) {
      if (!mounted) return;
      setState(() => _i = (_i + 1) % _stops.length);
      _announce();
    });
  }

  void _announce() => debugPrint('VYBIA_PROOF ${_stops[_i].$1}');

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(_i), child: _stops[_i].$2);
}

/// A side-by-side of the OLD S8 bubble lens (r = 60) and the NEW S8.1 one
/// (r = 44) over the same image, so the shrink is unmistakable.
class _OrbSizeCompare extends StatelessWidget {
  const _OrbSizeCompare();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget cell(String label, double radius) => Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              fit: StackFit.expand,
              children: [
                RefractionBubble(
                  image: const AssetImage(Img.cafe),
                  orbCenter: Offset(c.maxWidth / 2, c.maxHeight / 2),
                  radius: radius,
                  magnification: 0.8,
                  active: 1.0,
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.bg.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(label,
                          style: t.labelMedium
                              ?.copyWith(color: AppColors.pearl)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Row(
          children: [
            cell('S8  ·  ø~120 (r60)', 60),
            const SizedBox(width: 2),
            cell('S8.1  ·  ø~88 (r44)', 44),
          ],
        ),
      ),
    );
  }
}
