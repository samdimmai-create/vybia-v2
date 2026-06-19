import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../components/bubble/refraction_bubble.dart';
import '../../../components/orb/vybia_orb.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/edge_action.dart';
import '../../../shared/edge_decisive.dart';
import '../../../shared/edge_labels.dart';

/// The universal guest scene: a full-bleed situational [image] always wearing
/// the Vybia bubble treatment, driven entirely by the orb.
///
/// An ambient refraction lens gently drifts so every image is *visibly* a
/// liquid-glass bubble (the brand non-negotiable, and screenshot-able headless).
/// On contact the lens is born at the finger, follows it, and the orb's life
/// force [presence] intensifies the refraction; on release it dissolves back to
/// the ambient drift. Committing a direction past threshold fires [onDirection].
class SceneScaffold extends StatefulWidget {
  const SceneScaffold({
    super.key,
    required this.image,
    required this.headline,
    required this.onDirection,
    this.prompt,
    this.badge,
    this.left,
    this.right,
    this.up,
    this.down,
    this.leftAction = EdgeAction.neutral,
    this.rightAction = EdgeAction.neutral,
    this.upAction = EdgeAction.neutral,
    this.downAction = EdgeAction.neutral,
    this.lensRadius = 108,
  });

  final String image;
  final String headline;
  final String? prompt;

  /// Optional small pill shown above the headline (e.g. "★ Meilleur choix").
  final String? badge;
  final ValueChanged<OrbDirection> onDirection;
  final String? left;
  final String? right;
  final String? up;
  final String? down;

  /// The *meaning* of each edge, driving its decisive-colour filter (see
  /// [EdgeDecisiveOverlay]). Defaults to a neutral brand tint.
  final EdgeAction leftAction;
  final EdgeAction rightAction;
  final EdgeAction upAction;
  final EdgeAction downAction;
  final double lensRadius;

  @override
  State<SceneScaffold> createState() => _SceneScaffoldState();
}

class _SceneScaffoldState extends State<SceneScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;
  Offset? _orb; // live finger position; null when resting
  double _presence = 0; // orb life force 0..1
  OrbDirection? _aimDir; // edge the orb is leaning toward
  double _aimReach = 0; // 0 centre → 1 at commit threshold

  static const double _ambient = 0.5; // every image always shows the bubble

  // ---- Debug auto-drive --------------------------------------------------
  // When built with `--dart-define=VYBIA_AUTODRIVE=true`, the orb is driven
  // PROGRAMMATICALLY (no pointer) through a rest → centre → 4-edge cycle. This
  // lets the live bubble be screenshotted under a normal `flutter run` WITHOUT
  // the Flutter live-test pointer crosshair (which only exists under TestGesture
  // and was masking the real glass droplet in earlier proofs). Compiled out of
  // release builds (const false → tree-shaken).
  static const bool _kAutoDrive = bool.fromEnvironment('VYBIA_AUTODRIVE');

  // (dxFrac, dyFrac, dir, reach, presence, name). presence 0 ⇒ lens off (drift).
  static const List<(double, double, OrbDirection?, double, double, String)>
      _driveScript = [
    (0.0, 0.0, null, 0.0, 0.0, 'rest'), // no-orb half of the refraction compare
    (0.0, 0.0, null, 0.0, 1.0, 'centre'), // pure glass droplet, no edge colour
    (-0.20, 0.0, OrbDirection.left, 1.0, 1.0, 'left'),
    (0.20, 0.0, OrbDirection.right, 1.0, 1.0, 'right'),
    (0.0, 0.18, OrbDirection.down, 1.0, 1.0, 'down'),
    (0.0, -0.18, OrbDirection.up, 1.0, 1.0, 'up'),
  ];
  Timer? _driveTimer;
  int _driveStep = 0;
  Size _lastSize = Size.zero;
  double? _forceActive; // autodrive only: pin the lens strength (0 = lens off)

  void _autoTick() {
    if (!mounted || _lastSize == Size.zero) return;
    final s = _driveScript[_driveStep % _driveScript.length];
    setState(() {
      // Same framing for every state: the lens sits at the scripted point. The
      // 'rest' frame forces the lens OFF so the compare is identical-framing,
      // lens-off vs lens-on (proves geometry, not a brightness change).
      _orb = Offset(_lastSize.width / 2 + s.$1 * _lastSize.width,
          _lastSize.height / 2 + s.$2 * _lastSize.height);
      if (s.$6 == 'rest') {
        _forceActive = 0.0;
        _presence = 0;
        _aimDir = null;
        _aimReach = 0;
      } else {
        _forceActive = null;
        _presence = s.$5;
        _aimDir = s.$3;
        _aimReach = s.$4;
      }
    });
    debugPrint('VYBIA_DRIVE ${s.$6}');
    _driveStep++;
  }

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    if (_kAutoDrive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoTick();
        _driveTimer =
            Timer.periodic(const Duration(milliseconds: 5000), (_) => _autoTick());
      });
    }
  }

  @override
  void dispose() {
    _driveTimer?.cancel();
    _drift.dispose();
    super.dispose();
  }

  /// The action for the currently-aimed edge — but only when that edge is an
  /// actual choice (has a label), so the orb never filters toward a dead edge.
  EdgeAction? get _activeAction {
    switch (_aimDir) {
      case OrbDirection.left:
        return _has(widget.left) ? widget.leftAction : null;
      case OrbDirection.right:
        return _has(widget.right) ? widget.rightAction : null;
      case OrbDirection.up:
        return _has(widget.up) ? widget.upAction : null;
      case OrbDirection.down:
        return _has(widget.down) ? widget.downAction : null;
      case null:
        return null;
    }
  }

  bool _has(String? s) => s != null && s.isNotEmpty;

  /// Gentle Lissajous path used when no finger is down.
  Offset _idle(Size size) {
    final t = _drift.value * 2 * math.pi;
    final cx = size.width / 2 + math.cos(t) * size.width * 0.20;
    final cy = size.height * 0.46 + math.sin(t * 1.3) * size.height * 0.14;
    return Offset(cx, cy);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _lastSize = size;
          return VybiaOrb(
            showOrb: false, // the refraction bubble IS the orb here
            onPositionChanged: (p) => setState(() => _orb = p),
            onPresence: (v) => setState(() => _presence = v),
            onAim: (aim) => setState(() {
              _aimDir = aim.direction;
              _aimReach = aim.reach;
            }),
            onDirection: widget.onDirection,
            child: AnimatedBuilder(
              animation: _drift,
              builder: (context, _) {
                final pressing = _orb != null;
                final center = _orb ?? _idle(size);
                // Continuous floor (every image stays a bubble) lifted to full
                // strength on contact — no flicker on release.
                final active = _forceActive ??
                    (pressing
                        ? (_ambient + (1 - _ambient) * _presence)
                            .clamp(0.0, 1.0)
                            .toDouble()
                        : _ambient);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    RefractionBubble(
                      image: AssetImage(widget.image),
                      orbCenter: center,
                      radius: widget.lensRadius,
                      magnification: 0.8,
                      active: active,
                    ),
                    // Decisive-edge colour feedback: filters the image toward the
                    // aimed edge's action colour and recolours the orb.
                    EdgeDecisiveOverlay(
                      action: _activeAction,
                      direction: _aimDir,
                      reach: _aimReach,
                      orbCenter: _orb,
                      lensRadius: widget.lensRadius,
                    ),
                    _TopScrim(
                      headline: widget.headline,
                      prompt: widget.prompt,
                      badge: widget.badge,
                    ),
                    EdgeLabels(
                      left: widget.left,
                      right: widget.right,
                      up: widget.up,
                      down: widget.down,
                    ),
                    if (widget.prompt != null)
                      _hintChip(t, 'Touche, glisse, et choisis ta direction'),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _hintChip(TextTheme t, String label) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.huge),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: AppColors.pearl.withValues(alpha: 0.25)),
              ),
              child: Text(
                label,
                style: t.labelSmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Headline + optional prompt floated on a top legibility scrim.
class _TopScrim extends StatelessWidget {
  const _TopScrim({required this.headline, this.prompt, this.badge});

  final String headline;
  final String? prompt;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          // Top padding reserves a safe zone for the centred top edge-label
          // (pinned just under the status bar by EdgeLabels) so the badge and
          // headline always start clearly below it — never overlapping.
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.huge, AppSpacing.lg, AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.bg.withValues(alpha: 0.72),
                AppColors.bg.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      badge!,
                      style: t.labelMedium?.copyWith(
                        color: AppColors.bg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  headline,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.displayMedium?.copyWith(
                    color: AppColors.pearl,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 14)
                    ],
                  ),
                ),
                if (prompt != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    prompt!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      shadows: const [
                        Shadow(color: Colors.black45, blurRadius: 8)
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
