import 'dart:async';

import 'package:flutter/material.dart';

import '../../../components/bubble/refraction_bubble.dart';
import '../../../components/orb/vybia_orb.dart';
import '../../../core/media/image_ref.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/edge_action.dart';
import '../../../shared/edge_decisive.dart';
import '../../../shared/edge_labels.dart';
import '../../../shared/edge_palette.dart';
import '../../../shared/glass.dart';
import '../../../shared/water_transition.dart';

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
    // S8.1A: the bubble lens is now clearly SMALLER than V1 (whose ring was
    // ~ø80). At rest-on-contact the painter draws r ≈ lensRadius, so 44 ⇒ a
    // ~ø88 jewel — a smaller, crisper droplet than the old r=60 (~ø120).
    this.lensRadius = 44,
    this.onDoubleTap,
    this.onHoldHome,
    this.enableHoldHome = true,
    this.showPaletteSwitcher = false,
    this.journeyStep,
    this.journeyLabel,
    this.bottomBubble = false,
    this.infoLine,
    this.tags = const [],
    this.debugHoldProof = false,
    this.debugThrowProof = false,
    this.debugAimProof,
    this.debugContactProof = false,
    this.debugWarnProof = false,
    this.debugProofFull = false,
  });

  /// Debug/proof-only (S9.1): pin the orb at centre with the edge labels AND the
  /// bottom description bubble BOTH at full opacity (the normal UX fades one out
  /// as the other comes in). Lets a single Chrome screenshot show the
  /// options / reaction edges together with the place + "pourquoi". No edge aim.
  final bool debugProofFull;

  /// Debug-only: pin the clean on-contact state (orb born at centre, edges
  /// visible, bubble receded) with no edge aim, for the card-contact proof.
  final bool debugContactProof;

  /// Debug-only: pin the early hold-to-home WARNING (small portal, warning hint
  /// prominent) — distinct from [debugHoldProof]'s half-open portal.
  final bool debugWarnProof;

  /// S8.1D: present the description as a rounded-rect glass BUBBLE pinned near
  /// the BOTTOM (V1 style) instead of the top scrim. Used by the image/activity
  /// scenes (reco + the mood/preference scenes); the structural flows (plan,
  /// profil, mes plans) keep the plain top scrim. At rest the bubble is visible;
  /// on contact it fades out as the edge indicators + orb fade in, and it fades
  /// back on release/cancel.
  final bool bottomBubble;

  /// Optional one-line context for the bottom bubble, e.g. "à 1,4 km · Café ·
  /// posé". Shown under the title; ignored unless [bottomBubble] is true.
  final String? infoLine;

  /// Optional short tag chips for the bottom bubble (e.g. ["cosy"]).
  final List<String> tags;

  /// Debug-only: pin the scene in the on-contact state aimed at this edge (orb
  /// + edges visible, bubble hidden, decisive wave radiating) for a
  /// deterministic screenshot. Used by the S8.1 proof tour.
  final OrbDirection? debugAimProof;

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

  /// S14B: show the discreet palette-switcher chip (bottom-left) on this scene,
  /// so the founder can flip the edge-colour palette A/B/C live on his phone.
  /// Enabled on the decisive (reco / question) scenes where edge colours matter.
  final bool showPaletteSwitcher;

  /// S14C wayfinding: which journey step this scene belongs to (0-based into
  /// [JourneyStep.values]), drawing a calm progress indicator at the top. Null
  /// hides the indicator (e.g. structural sub-scenes).
  final int? journeyStep;

  /// S14C wayfinding: a short "where am I" label shown with the step dots, e.g.
  /// "Tes goûts" / "Pour toi" / "On planifie". Defaults to the step's own label.
  final String? journeyLabel;

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

class _SceneScaffoldState extends State<SceneScaffold> {
  // S21A (LATENCY FIX): the live orb/aim/presence/hold state flows through
  // ValueNotifiers, NOT setState. A pointer-move updates only these; the heavy
  // refraction lens and the decisive-edge overlay are each wrapped in a
  // RepaintBoundary and rebuild in ISOLATION off the minimal notifier they
  // depend on. So a move no longer rebuilds the whole scene tree (labels,
  // bubble, journey, palette) — which, together with the per-move setState in
  // VybiaOrb, was exactly what made the orb feel heavy and trail the finger on
  // Flutter web. The labels/bubble/journey rebuild only when [_presence] ticks
  // (birth/dissolve), never on a plain move. See [build].
  final ValueNotifier<Offset?> _orb = ValueNotifier<Offset?>(null);
  final ValueNotifier<double> _presence = ValueNotifier<double>(0);
  final ValueNotifier<OrbAim> _aim = ValueNotifier<OrbAim>(OrbAim.rest);
  final ValueNotifier<double> _hold = ValueNotifier<double>(0);

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
  static const List<
    (double, double, OrbDirection?, double, double, String, double)
  >
  _driveScript = [
    (0.0, 0.0, null, 0.0, 0.0, 'rest', 0.0), // image + description only
    (0.0, 0.0, null, 0.0, 1.0, 'centre', 0.0), // on-contact: orb + edges appear
    (-0.20, 0.0, OrbDirection.left, 1.0, 1.0, 'left', 0.0),
    (0.20, 0.0, OrbDirection.right, 1.0, 1.0, 'right', 0.0),
    (0.0, 0.18, OrbDirection.down, 1.0, 1.0, 'down', 0.0),
    (0.0, -0.18, OrbDirection.up, 1.0, 1.0, 'up', 0.0),
    (0.0, 0.0, null, 0.0, 1.0, 'hold', 0.55), // ≥3s immobile: warning + grow
    (
      0.0,
      0.0,
      null,
      0.0,
      0.35,
      'shrink',
      0.0,
    ), // release before complete: cancel
  ];
  Timer? _driveTimer;
  int _driveStep = 0;
  Size _lastSize = Size.zero;
  double? _forceActive; // autodrive only: pin the lens strength (0 = lens off)

  void _autoTick() {
    if (!mounted || _lastSize == Size.zero) return;
    final s = _driveScript[_driveStep % _driveScript.length];
    // Same framing for every state: the lens sits at the scripted point. The
    // 'rest' frame forces the lens OFF so the compare is identical-framing,
    // lens-off vs lens-on (proves geometry, not a brightness change).
    _orb.value = Offset(
      _lastSize.width / 2 + s.$1 * _lastSize.width,
      _lastSize.height / 2 + s.$2 * _lastSize.height,
    );
    if (s.$6 == 'rest') {
      _forceActive = 0.0;
      _aim.value = OrbAim.rest;
      _hold.value = 0;
      _presence.value = 0;
    } else {
      _forceActive = null;
      _aim.value = OrbAim(s.$3, s.$4);
      _hold.value = s.$7;
      _presence.value = s.$5;
    }
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
    if (_kAutoDrive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoTick();
        _driveTimer = Timer.periodic(
          const Duration(milliseconds: 5000),
          (_) => _autoTick(),
        );
      });
    }
    final holdProof = _kHoldProof || widget.debugHoldProof;
    final throwProof = _kThrowProof || widget.debugThrowProof;
    final aimProof = widget.debugAimProof;
    final contactProof = widget.debugContactProof || widget.debugProofFull;
    final warnProof = widget.debugWarnProof;
    if (holdProof ||
        throwProof ||
        aimProof != null ||
        contactProof ||
        warnProof) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _lastSize == Size.zero) return;
        _forceActive = null;
        _orb.value = Offset(_lastSize.width / 2, _lastSize.height / 2);
        if (warnProof) {
          _hold.value = 0.18; // early warning: portal still tiny, hint prominent
        } else if (holdProof) {
          _hold.value = 0.62; // portal half-open, filled with calm
        } else if (contactProof) {
          // Clean contact: orb + edges visible, bubble receded, no aim wave.
        } else if (aimProof != null) {
          // On-contact aim toward [aimProof]: orb sits ~70% toward that edge with
          // a high reach so the decisive radial wave is in full bloom.
          _orb.value = _aimPoint(_lastSize, aimProof);
          _aim.value = OrbAim(aimProof, 0.85);
        } else {
          // Thrown orb in flight, nearing the right edge and committing.
          _orb.value = Offset(_lastSize.width * 0.9, _lastSize.height / 2);
          _aim.value = const OrbAim(OrbDirection.right, 0.92);
        }
        _presence.value = 1.0;
      });
    }
  }

  /// A point ~70% of the way from centre toward [dir]'s edge — where the orb
  /// sits for the on-contact aim proof.
  static Offset _aimPoint(Size s, OrbDirection dir) {
    final cx = s.width / 2, cy = s.height / 2;
    switch (dir) {
      case OrbDirection.left:
        return Offset(s.width * 0.18, cy);
      case OrbDirection.right:
        return Offset(s.width * 0.82, cy);
      case OrbDirection.up:
        return Offset(cx, s.height * 0.24);
      case OrbDirection.down:
        return Offset(cx, s.height * 0.76);
    }
  }

  @override
  void dispose() {
    _driveTimer?.cancel();
    _orb.dispose();
    _presence.dispose();
    _aim.dispose();
    _hold.dispose();
    super.dispose();
  }

  /// The action mapped to [dir] — but only when that edge is an actual choice
  /// (has a label), so the orb/wave never filters toward a dead edge. Used for
  /// both the aimed edge and the perpendicular corner edge (S17D), so the
  /// gradient never leans toward an unlabelled secondary either.
  EdgeAction? _actionFor(OrbDirection? dir) {
    switch (dir) {
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

  /// The resting lens centre when no finger is down. S21A: a static point (the
  /// old gently-drifting Lissajous needed an 8s repeating ticker that rebuilt the
  /// whole scene at 60fps even at rest — wasted work, since the ambient lens
  /// strength is 0 and so nothing was ever visible there anyway).
  static Offset _restCenter(Size size) =>
      Offset(size.width / 2, size.height * 0.46);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _lastSize = size;
          final radius = widget.lensRadius;

          // S21A — the scene is composed of REPAINT-ISOLATED layers, each driven
          // by the minimal ValueNotifier(s) it needs. A pointer-move ticks only
          // [_orb]/[_aim], so only the lens + decisive overlay repaint; the
          // labels/bubble/journey (which depend on [_presence]) stay put. This is
          // what kills the per-move full-tree rebuild that made the orb lag.

          // Layer 1: the heavy refraction lens — the orb's body on these scenes.
          final hero = RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_orb, _presence, _hold, _aim]),
              builder: (context, _) {
                final orbPos = _orb.value;
                final pressing = orbPos != null;
                final center = orbPos ?? _restCenter(size);
                // Continuous floor (every image stays a bubble) lifted to full
                // strength on contact — no flicker on release.
                final active = _forceActive ??
                    (pressing
                        ? (_ambient + (1 - _ambient) * _presence.value)
                            .clamp(0.0, 1.0)
                            .toDouble()
                        : _ambient);
                // Web-safe reject drain: aiming at "Pas intéressant" desaturates
                // + darkens the hero proportionally to the reach (the radial
                // slate wave on top adds the from-edge feel). ColorFiltered
                // renders identically on Flutter web (unlike BackdropFilter).
                final aim = _aim.value;
                final rejectAmount =
                    _actionFor(aim.direction) == EdgeAction.reject
                        ? aim.reach
                        : 0.0;
                Widget bubble = RefractionBubble(
                  image: imageProviderFor(widget.image),
                  orbCenter: center,
                  radius: radius,
                  magnification: 0.8,
                  // As the hold-to-home portal opens, let the refraction recede.
                  active: active * (1 - 0.7 * _hold.value),
                );
                if (rejectAmount > 0.001) {
                  bubble = ColorFiltered(
                    colorFilter:
                        ColorFilter.matrix(rejectColorMatrix(rejectAmount)),
                    child: bubble,
                  );
                }
                return bubble;
              },
            ),
          );

          // Layer 2: decisive-edge colour feedback (filters the image toward the
          // aimed edge's colour + recolours the orb). Also watches the palette so
          // a live A/B flip recolours a held wave.
          final decisive = RepaintBoundary(
            child: AnimatedBuilder(
              animation:
                  Listenable.merge([_aim, _orb, activeEdgePaletteIndex]),
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
                  lensRadius: widget.lensRadius,
                );
              },
            ),
          );

          // Layer 3: the signature water transition — the calm home field rises
          // out of the orb and submerges the scene as the hold completes (the
          // EXACT same [WaterReveal] the splash plays).
          final water = AnimatedBuilder(
            animation: Listenable.merge([_hold, _orb]),
            builder: (context, _) {
              final hold = _hold.value;
              if (hold <= 0.001) return const SizedBox.shrink();
              return WaterReveal(
                progress: hold,
                center: _orb.value ?? _restCenter(size),
                seedRadius: widget.lensRadius,
              );
            },
          );

          // Layer 4: description — bottom glass bubble (recedes on contact) or
          // the always-on top scrim for structural scenes. Presence-driven only.
          final Widget description = widget.bottomBubble
              ? ValueListenableBuilder<double>(
                  valueListenable: _presence,
                  builder: (context, presence, _) {
                    final ui = presence.clamp(0.0, 1.0).toDouble();
                    final bubbleOpacity = widget.debugProofFull
                        ? 1.0
                        : (1 - ui).clamp(0.0, 1.0).toDouble();
                    return _BottomBubble(
                      opacity: bubbleOpacity,
                      badge: widget.badge,
                      title: widget.headline,
                      subtitle: widget.prompt,
                      infoLine: widget.infoLine,
                      tags: widget.tags,
                    );
                  },
                )
              : _TopScrim(
                  headline: widget.headline,
                  prompt: widget.prompt,
                  badge: widget.badge,
                );

          // Layer 5: edge labels + guidance chip — born/gone with the orb
          // (presence-driven), recoloured live by the palette.
          final labels = AnimatedBuilder(
            animation: Listenable.merge([_presence, activeEdgePaletteIndex]),
            builder: (context, _) {
              final ui = _presence.value.clamp(0.0, 1.0).toDouble();
              final edgesUi = widget.debugProofFull ? 1.0 : ui;
              if (edgesUi <= 0.001) return const SizedBox.shrink();
              return Opacity(
                opacity: edgesUi,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EdgeLabels(
                      left: widget.left,
                      right: widget.right,
                      up: widget.up,
                      down: widget.down,
                      leftColor: activeEdgePalette.colorFor(widget.leftAction),
                      rightColor:
                          activeEdgePalette.colorFor(widget.rightAction),
                      upColor: activeEdgePalette.colorFor(widget.upAction),
                      downColor: activeEdgePalette.colorFor(widget.downAction),
                    ),
                    // The bottom bubble carries its own "touche et décide" hint,
                    // so the redundant guidance chip is only on plain scenes.
                    if (!widget.bottomBubble && widget.prompt != null)
                      _hintChip(t, 'Touche, glisse, et choisis ta direction'),
                  ],
                ),
              );
            },
          );

          // Layer 6: calm "where am I" wayfinder — rides the rest state so it
          // cross-fades OUT on contact (presence-driven).
          final Widget journey = widget.journeyStep == null
              ? const SizedBox.shrink()
              : ValueListenableBuilder<double>(
                  valueListenable: _presence,
                  builder: (context, presence, _) {
                    final ui = presence.clamp(0.0, 1.0).toDouble();
                    final bubbleOpacity =
                        widget.debugProofFull ? 1.0 : (1 - ui);
                    if (bubbleOpacity <= 0.001) return const SizedBox.shrink();
                    return _JourneyIndicator(
                      step: widget.journeyStep!,
                      label: widget.journeyLabel,
                      opacity: bubbleOpacity,
                    );
                  },
                );

          // Layer 7: first-run coach mark + hold-to-home warning hint.
          final coachAndWarning = AnimatedBuilder(
            animation: Listenable.merge([_presence, _hold]),
            builder: (context, _) {
              final ui = _presence.value.clamp(0.0, 1.0).toDouble();
              final hold = _hold.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (!_Coach.shown && ui <= 0.001 && hold <= 0.001)
                    _firstRunCoach(t),
                  if (hold > 0.001) _holdWarning(t),
                ],
              );
            },
          );

          final orb = VybiaOrb(
            showOrb: false, // the refraction bubble IS the orb here
            enableHoldHome: widget.enableHoldHome,
            // S21A: callbacks push to ValueNotifiers — NO setState, so a move
            // never rebuilds the scene tree (only the isolated layers repaint).
            onPositionChanged: (p) => _orb.value = p,
            onPresence: (v) {
              _presence.value = v;
              if (v > 0.01) _Coach.shown = true; // guest has touched once
            },
            onAim: (aim) => _aim.value = aim,
            onHoldProgress: (v) => _hold.value = v,
            onDirection: widget.onDirection,
            onDoubleTap:
                widget.onDoubleTap ?? () => Navigator.of(context).maybePop(),
            onHoldHome: widget.onHoldHome ??
                () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRouter.accueil, (_) => false),
            child: Stack(
              fit: StackFit.expand,
              children: [
                hero,
                decisive,
                water,
                description,
                labels,
                journey,
                coachAndWarning,
              ],
            ),
          );
          // The palette switcher (S14B) sits ABOVE the orb's pointer Listener so
          // a tap on it flips the palette instead of starting an orb gesture.
          if (!widget.showPaletteSwitcher) return orb;
          return Stack(
            fit: StackFit.expand,
            children: [
              orb,
              Positioned(
                left: AppSpacing.md,
                bottom: AppSpacing.md,
                child: SafeArea(child: const _PaletteSwitcher()),
              ),
            ],
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
                  color: AppColors.pearl.withValues(alpha: 0.25),
                ),
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

  /// S14C: the once-per-launch coach mark. Beyond "touch to explore", it now
  /// names the two escape gestures up front — double-tap to go back, hold to
  /// return home — so a first-time guest always knows the way forward AND back.
  Widget _firstRunCoach(TextTheme t) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.huge),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.pearl.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Touche l’image, glisse vers un choix',
                    textAlign: TextAlign.center,
                    style: t.labelMedium?.copyWith(
                      color: AppColors.pearl,
                      fontWeight: FontWeight.w700,
                      shadows: kGlassTextShadow,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Double-tap : revenir · maintiens : accueil',
                    textAlign: TextAlign.center,
                    style: t.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
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
          opacity: (0.4 + 0.6 * _hold.value).clamp(0.0, 1.0).toDouble(),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.bg.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.pearl.withValues(alpha: 0.3)),
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

/// S9.2 + S9.3: the V1-style description — badge, title, the "pourquoi" line, an
/// info line and tag chips, with a small "touche et décide" hint below it —
/// pinned near the BOTTOM and floating DIRECTLY over the hero image. There is NO
/// opaque card and NO full backdrop blur: the illustrative image shows through
/// fully, like the V1 "Columbus Café & Co" card. The title / pourquoi / info /
/// hint stay FLOATING TEXT with [kGlassTextShadow] so reading is instant; the
/// badge + tag chips wear the liquid-glass [GlassCapsule] (S9.3) so the chrome
/// reads as one sea-glass family with the orb — dew beads on the photo, not a
/// UI card. Its [opacity] is driven by the scene: full at rest, fading to 0 as
/// the orb is born on contact (and back on release).
class _BottomBubble extends StatelessWidget {
  const _BottomBubble({
    required this.opacity,
    required this.title,
    this.badge,
    this.subtitle,
    this.infoLine,
    this.tags = const [],
  });

  final double opacity;
  final String title;
  final String? badge;
  final String? subtitle;
  final String? infoLine;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.001) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    // S9.2: NO opaque card, NO backdrop blur — the hero image
                    // shows through FULLY. The only background aid is a very
                    // faint bottom-anchored gradient veil (transparent at the
                    // top of the text → barely tinted at the very bottom) so a
                    // bright photo never washes the smallest text out.
                    // Legibility otherwise rides entirely on the text's own
                    // shadow/glow + weight (kGlassTextShadow), V1-card style.
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.bg.withValues(alpha: 0.0),
                          AppColors.bg.withValues(alpha: 0.30),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (badge != null) ...[
                          GlassCapsule(
                            tint: AppColors.champagne,
                            strong: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            child: Text(
                              badge!,
                              style: t.labelMedium?.copyWith(
                                color: AppColors.pearl,
                                fontWeight: FontWeight.w700,
                                shadows: kGlassTextShadow,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleLarge?.copyWith(
                            color: AppColors.pearl,
                            fontWeight: FontWeight.w700,
                            shadows: kGlassTextShadow,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium?.copyWith(
                              color: AppColors.pearl.withValues(alpha: 0.92),
                              shadows: kGlassTextShadow,
                            ),
                          ),
                        ],
                        if (infoLine != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            infoLine!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.labelMedium?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              shadows: kGlassTextShadow,
                            ),
                          ),
                        ],
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              for (final tag in tags)
                                GlassCapsule(
                                  tint: AppColors.accent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '• $tag',
                                    style: t.labelSmall?.copyWith(
                                      color: AppColors.pearl,
                                      shadows: kGlassTextShadow,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'touche et décide',
                    style: t.labelSmall?.copyWith(
                      color: AppColors.pearl.withValues(alpha: 0.85),
                      letterSpacing: 0.4,
                      shadows: kGlassTextShadow,
                    ),
                  ),
                ],
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
            AppSpacing.lg,
            AppSpacing.huge,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
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
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
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
                      Shadow(color: Colors.black54, blurRadius: 14),
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
                        Shadow(color: Colors.black45, blurRadius: 8),
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

/// S14C: the four legible phases of the guest journey, used by the
/// [_JourneyIndicator] so every scene tells the guest where they are.
enum JourneyStep {
  welcome('Bienvenue'),
  taste('Tes goûts'),
  forYou('Pour toi'),
  plan('On planifie');

  const JourneyStep(this.label);
  final String label;
}

/// A calm top-of-scene wayfinder: a short phase label over a row of step dots
/// (the current one lit). Low-clutter and on-brand (sea-glass), it rides the
/// scene's rest opacity so it fades out the moment the orb is born — leaving the
/// image clean while you act — and fades back on release.
class _JourneyIndicator extends StatelessWidget {
  const _JourneyIndicator({
    required this.step,
    required this.opacity,
    this.label,
  });

  final int step;
  final double opacity;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final steps = JourneyStep.values;
    final i = step.clamp(0, steps.length - 1);
    final text = label ?? steps[i].label;
    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: t.labelMedium?.copyWith(
                      color: AppColors.pearl,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      shadows: kGlassTextShadow,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var s = 0; s < steps.length; s++)
                        Container(
                          width: s == i ? 16 : 6,
                          height: 6,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: s == i
                                ? AppColors.accent
                                : AppColors.pearl.withValues(alpha: 0.30),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// S14B: a discreet, always-tappable chip that cycles the edge-colour palette
/// A → B → C live, so the founder can compare them on his phone. Deliberately
/// small and low-contrast so it never competes with the scene; it sits above
/// the orb's pointer Listener so a tap flips the palette (it does NOT start an
/// orb gesture). Rebuilds itself on each flip via [activeEdgePaletteIndex].
class _PaletteSwitcher extends StatelessWidget {
  const _PaletteSwitcher();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder<int>(
      valueListenable: activeEdgePaletteIndex,
      builder: (context, _, _) {
        final p = activeEdgePalette;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: cycleEdgePalette,
            child: Opacity(
              opacity: 0.85,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.pearl.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Four dots previewing this palette's action colours.
                    for (final c in [p.joy, p.curious, p.go, p.reject])
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.pearl.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    const SizedBox(width: 2),
                    Text(
                      'Palette ${p.id}',
                      style: t.labelSmall?.copyWith(
                        color: AppColors.pearl,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
