import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../components/bubble/calm_home_field.dart';
import '../../../components/bubble/refraction_bubble.dart';
import '../../../components/orb/vybia_orb.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/edge_action.dart';
import '../../../shared/edge_decisive.dart';
import '../../../shared/edge_labels.dart';

/// One-time, app-launch-scoped coach mark guard: a brand-new guest sees a single
/// subtle "touche pour explorer" hint at rest on the first scene, then never
/// again this launch (the rest state is image + description only afterwards).
class _Coach {
  _Coach._();
  static bool shown = false;
}

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
    this.lensRadius = 60,
    this.onDoubleTap,
    this.onHoldHome,
    this.enableHoldHome = true,
    this.debugHoldProof = false,
    this.debugThrowProof = false,
  });

  /// Debug-only: pin this scene in the calm hold-to-home portal state (half-open
  /// at centre) for a deterministic screenshot. Used by the S8 proof tour.
  final bool debugHoldProof;

  /// Debug-only: pin this scene with a thrown orb nearing the RIGHT edge and
  /// committing, for a deterministic screenshot.
  final bool debugThrowProof;

  /// Quick double-tap → "return to the previous image/page". Defaults to
  /// `Navigator.maybePop` (back navigation) when not supplied.
  final VoidCallback? onDoubleTap;

  /// Immobile hold-to-home completion → navigate to accueil. Defaults to
  /// returning to the Welcome scene when not supplied.
  final VoidCallback? onHoldHome;

  /// Disables the hold-to-home gesture (e.g. on the accueil scene itself).
  final bool enableHoldHome;

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
  double _hold = 0; // hold-to-home warning progress 0..1

  // S6.3: the illustrative image is the hero. At rest there is NO lens — the
  // bubble is a small jewel that is born under the finger on contact and melts
  // away on release, so the only thing that ever touches the image is (a) the
  // local refraction wherever the orb is and (b) the growing decisive-edge
  // filter. An ambient always-on lens would veil the resting image, so it's 0.
  static const double _ambient = 0.0;

  // ---- Debug auto-drive --------------------------------------------------
  // When built with `--dart-define=VYBIA_AUTODRIVE=true`, the orb is driven
  // PROGRAMMATICALLY (no pointer) through a rest → centre → 4-edge cycle. This
  // lets the live bubble be screenshotted under a normal `flutter run` WITHOUT
  // the Flutter live-test pointer crosshair (which only exists under TestGesture
  // and was masking the real glass droplet in earlier proofs). Compiled out of
  // release builds (const false → tree-shaken).
  static const bool _kAutoDrive = bool.fromEnvironment('VYBIA_AUTODRIVE');

  // (dxFrac, dyFrac, dir, reach, presence, name, hold). presence 0 ⇒ lens off.
  // hold > 0 ⇒ hold-to-home warning (bubble grows, warning hint shows).
  static const List<(double, double, OrbDirection?, double, double, String, double)>
      _driveScript = [
    (0.0, 0.0, null, 0.0, 0.0, 'rest', 0.0), // image + description only
    (0.0, 0.0, null, 0.0, 1.0, 'centre', 0.0), // on-contact: orb + edges appear
    (-0.20, 0.0, OrbDirection.left, 1.0, 1.0, 'left', 0.0),
    (0.20, 0.0, OrbDirection.right, 1.0, 1.0, 'right', 0.0),
    (0.0, 0.18, OrbDirection.down, 1.0, 1.0, 'down', 0.0),
    (0.0, -0.18, OrbDirection.up, 1.0, 1.0, 'up', 0.0),
    (0.0, 0.0, null, 0.0, 1.0, 'hold', 0.55), // ≥3s immobile: warning + grow
    (0.0, 0.0, null, 0.0, 0.35, 'shrink', 0.0), // release before complete: cancel
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
        _hold = 0;
      } else {
        _forceActive = null;
        _presence = s.$5;
        _aimDir = s.$3;
        _aimReach = s.$4;
        _hold = s.$7;
      }
    });
    debugPrint('VYBIA_DRIVE ${s.$6}');
    _driveStep++;
  }

  // Debug-only single-frame proof pins (S8). Each lands the scene in one
  // deterministic state for a crosshair-free `xcrun simctl io screenshot`:
  //   VYBIA_HOLD=true  → the calm hold-to-home portal, half-open at centre.
  //   VYBIA_THROW=true → a thrown orb nearing the RIGHT edge, committing.
  static const bool _kHoldProof = bool.fromEnvironment('VYBIA_HOLD');
  static const bool _kThrowProof = bool.fromEnvironment('VYBIA_THROW');

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
    final holdProof = _kHoldProof || widget.debugHoldProof;
    final throwProof = _kThrowProof || widget.debugThrowProof;
    if (holdProof || throwProof) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _lastSize == Size.zero) return;
        setState(() {
          _forceActive = null;
          _presence = 1.0;
          if (holdProof) {
            _orb = Offset(_lastSize.width / 2, _lastSize.height / 2);
            _hold = 0.62; // portal half-open, filled with calm
          } else {
            // Thrown orb in flight, nearing the right edge and committing.
            _orb = Offset(_lastSize.width * 0.9, _lastSize.height / 2);
            _aimDir = OrbDirection.right;
            _aimReach = 0.92;
          }
        });
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
            enableHoldHome: widget.enableHoldHome,
            onPositionChanged: (p) => setState(() => _orb = p),
            onPresence: (v) => setState(() {
              _presence = v;
              if (v > 0.01) _Coach.shown = true; // guest has touched once
            }),
            onAim: (aim) => setState(() {
              _aimDir = aim.direction;
              _aimReach = aim.reach;
            }),
            onHoldProgress: (v) => setState(() => _hold = v),
            onDirection: widget.onDirection,
            onDoubleTap:
                widget.onDoubleTap ?? () => Navigator.of(context).maybePop(),
            onHoldHome: widget.onHoldHome ??
                () => Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRouter.accueil, (_) => false),
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
                // S7-A: the orb-driven UI (edge labels + guidance chip) is hidden
                // at rest and fades IN together with the orb on contact. Use the
                // presence (or the autodrive hold) as the single fade signal.
                final ui = _presence.clamp(0.0, 1.0).toDouble();
                // S8: the hold-to-home grow no longer swirls the ACTIVITY image
                // into a vortex. The refraction bubble keeps its calm contact
                // size; instead a CalmHomeField *portal* (the neutral home
                // water/ice/glass) expands from the orb and cross-fades in, so
                // the orb reads as a calm portal opening to the Accueil — never
                // a scary magnification of the activity photo.
                final radius = widget.lensRadius;
                final portalRadius = widget.lensRadius * (1 + _hold * 16);
                final portalFill = (_hold * 1.4).clamp(0.0, 1.0).toDouble();
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    RefractionBubble(
                      image: AssetImage(widget.image),
                      orbCenter: center,
                      radius: radius,
                      magnification: 0.8,
                      // As the portal opens, let the activity refraction recede.
                      active: active * (1 - 0.7 * _hold),
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
                    // The calm home portal: a growing circle of neutral
                    // water/ice/glass, centred on the orb, filling in as the
                    // hold completes. At _hold→1 it covers the screen → accueil.
                    if (_hold > 0.001)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: portalFill,
                            child: ClipPath(
                              clipper: _CircleReveal(center, portalRadius),
                              child: const CalmHomeField(),
                            ),
                          ),
                        ),
                      ),
                    // Rest state = hero image + description only. Always painted.
                    _TopScrim(
                      headline: widget.headline,
                      prompt: widget.prompt,
                      badge: widget.badge,
                    ),
                    // Edge labels + guidance chip: born/gone with the orb.
                    if (ui > 0.001)
                      Opacity(
                        opacity: ui,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            EdgeLabels(
                              left: widget.left,
                              right: widget.right,
                              up: widget.up,
                              down: widget.down,
                            ),
                            if (widget.prompt != null)
                              _hintChip(
                                  t, 'Touche, glisse, et choisis ta direction'),
                          ],
                        ),
                      ),
                    // First-run-only coach mark: at rest, tell a brand-new guest
                    // they can touch. Disappears for the rest of the launch.
                    if (!_Coach.shown && ui <= 0.001 && _hold <= 0.001)
                      _hintChip(t, 'Touche l’image pour explorer'),
                    // Hold-to-home warning hint.
                    if (_hold > 0.001) _holdWarning(t),
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

  /// Calm centred warning shown once the immobile hold-to-home threshold is
  /// reached: keep holding and you'll be taken back to the accueil. Its opacity
  /// tracks the grow progress so it feels like a deliberate, building gesture.
  Widget _holdWarning(TextTheme t) {
    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: (0.4 + 0.6 * _hold).clamp(0.0, 1.0).toDouble(),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.bg.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border:
                  Border.all(color: AppColors.pearl.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Continue de maintenir pour revenir à l’accueil',
              textAlign: TextAlign.center,
              style: t.titleMedium?.copyWith(color: AppColors.pearl),
            ),
          ),
        ),
      ),
    );
  }
}

/// Clips its child to a growing circle centred at [center] — the expanding
/// hold-to-home portal (S8).
class _CircleReveal extends CustomClipper<Path> {
  const _CircleReveal(this.center, this.radius);

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(covariant _CircleReveal old) =>
      old.center != center || old.radius != radius;
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
              // S6.3: a tight, soft legibility scrim local to the headline only
              // — just enough contrast for the title (which also carries its own
              // text shadow), so the rest of the hero image stays bright.
              colors: [
                AppColors.bg.withValues(alpha: 0.55),
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
                    maxLines: 4,
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
