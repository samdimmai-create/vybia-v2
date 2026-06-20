import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/edge_action.dart';
import '../guest/data/assets.dart';
import '../guest/widgets/scene_scaffold.dart';

/// Debug-only VISIBLE-IN-CHROME proof tour for Sprint S9.3
/// (`--dart-define=VYBIA_PROOF93=true`).
///
/// Proves the liquid-glass language on the SMALL chrome elements — the info
/// bubble's badge + tag chips and the edge/choice labels — across the four
/// balance goals (light / distinct / on-theme / legible), on BOTH a bright and
/// a dark background.
///
/// Three deterministic stops, each pausing and printing `VYBIA_PROOF <name>` so
/// tool/cdp_capture.mjs grabs the frame via DevTools:
///   • s9_3_info_glass_bright — info bubble at rest over a BRIGHT photo.
///   • s9_3_info_glass_dark   — info bubble at rest over a DARK photo.
///   • s9_3_edges_glass       — a reco scene ON CONTACT showing the glass
///     edge/choice labels (Intéressant / Pas intéressant / Plus d'infos /
///     Planifier) with the orb up.
class S93ProofTour extends StatefulWidget {
  const S93ProofTour({super.key});

  @override
  State<S93ProofTour> createState() => _S93ProofTourState();
}

class _S93ProofTourState extends State<S93ProofTour> {
  // Hold each frame well past the capture client's settle window so the
  // screenshot lands on a stable, decoded frame.
  static const _hold = Duration(seconds: 7);
  int _i = 0;
  Timer? _timer;

  static SceneScaffold _reco({required String image, bool contact = false}) =>
      SceneScaffold(
        image: image,
        badge: '★ Meilleur choix pour toi',
        headline: 'Café Olimpico',
        prompt: 'Une pause douce, un café soigné, le temps qui ralentit.',
        bottomBubble: true,
        infoLine: 'à 1,4 km · Mile End · Café posé',
        tags: const ['posé', 'calme', 'cosy'],
        // Canonical reco reaction edges (S9A): consistent on every reco scene.
        left: 'Intéressant',
        right: 'Pas intéressant',
        up: 'Plus d’infos',
        down: 'Planifier',
        leftAction: EdgeAction.joy,
        rightAction: EdgeAction.reject,
        upAction: EdgeAction.curious,
        downAction: EdgeAction.go,
        onDirection: (_) {},
        debugContactProof: contact,
      );

  // Img.market = a bright daylit scene; Img.bar = a dark, moody one — the two
  // background extremes the glass must hold its balance on.
  late final List<(String, Widget)> _stops = [
    ('s9_3_info_glass_bright', _reco(image: Img.market)),
    ('s9_3_info_glass_dark', _reco(image: Img.bar)),
    ('s9_3_edges_glass', _reco(image: Img.bar, contact: true)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
    _timer = Timer.periodic(_hold, (_) {
      if (!mounted) return;
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
