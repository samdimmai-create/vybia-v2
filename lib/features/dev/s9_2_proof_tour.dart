import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/edge_action.dart';
import '../guest/data/assets.dart';
import '../guest/widgets/scene_scaffold.dart';

/// Debug-only VISIBLE-IN-CHROME proof tour for Sprint S9.2
/// (`--dart-define=VYBIA_PROOF92=true`).
///
/// Proves the S9.2 change: the bottom description is now TRANSPARENT — the hero
/// image shows through fully behind the floating text (no frosted/blurred card)
/// — and it still recedes on contact, leaving only the image + edges + orb.
///
/// Two deterministic stops, each pausing and printing `VYBIA_PROOF <name>` so
/// tool/cdp_capture.mjs grabs the frame via DevTools:
///   • s9_2_bubble_transparent — at rest: the transparent description floats
///     over a fully-visible photo.
///   • s9_2_bubble_contact     — on contact: the description is gone, the orb
///     + decisive edges are up.
class S92ProofTour extends StatefulWidget {
  const S92ProofTour({super.key});

  @override
  State<S92ProofTour> createState() => _S92ProofTourState();
}

class _S92ProofTourState extends State<S92ProofTour> {
  // Hold each frame well past the capture client's settle window so the
  // screenshot lands on a stable, decoded frame.
  static const _hold = Duration(seconds: 7);
  int _i = 0;
  Timer? _timer;

  static SceneScaffold _reco({bool contact = false}) => SceneScaffold(
    image: Img.cafe,
    badge: '★ Meilleur choix pour toi',
    headline: 'Café Olimpico',
    prompt: 'Une pause douce, un café soigné, le temps qui ralentit.',
    bottomBubble: true,
    infoLine: 'à 1,4 km · Mile End · Café posé',
    tags: const ['posé', 'calme', 'cosy'],
    left: 'J’aime',
    right: 'Pas pour moi',
    up: 'Plus d’infos',
    down: 'Planifier',
    leftAction: EdgeAction.joy,
    rightAction: EdgeAction.reject,
    upAction: EdgeAction.curious,
    downAction: EdgeAction.go,
    onDirection: (_) {},
    debugContactProof: contact,
  );

  late final List<(String, Widget)> _stops = [
    ('s9_2_bubble_transparent', _reco()),
    ('s9_2_bubble_contact', _reco(contact: true)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
    _timer = Timer.periodic(_hold, (_) {
      if (!mounted) return;
      // Stop after the last frame so it doesn't loop endlessly in the window.
      if (_i >= _stops.length - 1) {
        debugPrint('VYBIA_PROOF DONE');
        _timer?.cancel();
        return;
      }
      setState(() => _i += 1);
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
