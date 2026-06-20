import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/edge_action.dart';
import '../guest/data/assets.dart';
import '../guest/screens/accueil_screen.dart';
import '../guest/widgets/scene_scaffold.dart';

/// Debug-only visual-proof tour for Sprint S8 (`--dart-define=VYBIA_PROOF=true`).
///
/// It walks the five target states deterministically — pausing on each and
/// printing `VYBIA_PROOF <name>` so an `xcrun simctl io booted screenshot`
/// capture script can grab each frame crosshair-free:
///   1. accueil       — the calm hub at rest
///   2. reco_cafe     — a real Montréal café under its category-accurate image
///   3. reco_theatre  — a real Montréal theatre under its category-accurate image
///   4. hold          — the calm hold-to-home portal, half-open
///   5. throw         — a thrown orb nearing the right edge, committing
///
/// Compiled out of release builds (const false ⇒ tree-shaken).
class S8ProofTour extends StatefulWidget {
  const S8ProofTour({super.key});

  @override
  State<S8ProofTour> createState() => _S8ProofTourState();
}

class _S8ProofTourState extends State<S8ProofTour> {
  static const _hold = Duration(seconds: 7);
  int _i = 0;
  Timer? _timer;

  late final List<(String, Widget)> _stops = [
    ('accueil', const AccueilScreen()),
    (
      'reco_cafe',
      _reco(
        image: Img.cafe,
        title: 'Café Olimpico',
        prompt:
            'Café à découvrir — Mile End. Une pause douce, un café soigné, le temps qui ralentit.',
      ),
    ),
    (
      'reco_theatre',
      _reco(
        image: Img.theatre,
        title: 'Théâtre du Nouveau Monde',
        prompt:
            'Une scène vivante — Quartier des spectacles. Le genre de soirée qui sort de l’ordinaire.',
      ),
    ),
    (
      'hold',
      SceneScaffold(
        image: Img.viewpoint,
        headline: 'Belvédère Kondiaronk',
        prompt: 'Maintien… l’orbe s’ouvre sur l’accueil.',
        onDirection: (_) {},
        debugHoldProof: true,
      ),
    ),
    (
      'throw',
      SceneScaffold(
        image: Img.museum,
        headline: 'Musée des beaux-arts',
        prompt: 'Lancer de l’orbe — il file vers le bord et valide.',
        left: 'J’aime',
        right: 'Pas pour moi',
        up: 'Plus d’infos',
        down: 'Planifier',
        leftAction: EdgeAction.joy,
        rightAction: EdgeAction.reject,
        upAction: EdgeAction.curious,
        downAction: EdgeAction.go,
        onDirection: (_) {},
        debugThrowProof: true,
      ),
    ),
  ];

  static Widget _reco({
    required String image,
    required String title,
    required String prompt,
  }) =>
      SceneScaffold(
        image: image,
        badge: '★ Meilleur choix pour toi',
        headline: title,
        prompt: prompt,
        left: 'J’aime',
        right: 'Pas pour moi',
        up: 'Plus d’infos',
        down: 'Planifier',
        leftAction: EdgeAction.joy,
        rightAction: EdgeAction.reject,
        upAction: EdgeAction.curious,
        downAction: EdgeAction.go,
        onDirection: (_) {},
      );

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
