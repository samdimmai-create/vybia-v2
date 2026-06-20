import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'orb_painter.dart';

/// A live snapshot of where the orb is aiming: the edge it's leaning toward
/// ([direction], null in the deadzone) and how close it is to committing
/// ([reach], 0 at centre → 1 at the threshold).
class OrbAim {
  const OrbAim(this.direction, this.reach);

  final OrbDirection? direction;
  final double reach;

  /// Idle aim — no direction, no reach.
  static const OrbAim rest = OrbAim(null, 0);
}

/// The Vybia brand primitive.
///
/// Wraps [child] in a [Listener] (pointer events — never GestureDetector). An
/// orb is *born* at the touch point on pointer-down (a ~150ms fade + scale-in,
/// never an instant pop), *follows* the finger, and either:
///   * commits a direction (left/right/up/down) when dragged past [threshold],
///     firing [onDirection]; or
///   * progressively dissolves in ~150ms on release when below threshold.
///
/// S7 interaction model (founder spec):
///   * A quick DOUBLE-TAP (two still taps within [doubleTapWindow]) fires
///     [onDoubleTap] — used for "back / undo this scene". No edge is committed.
///   * A constant IMMOBILE hold (still for [holdStill], ~3s) starts a
///     hold-to-home warning: the orb GROWS over [holdGrow] while
///     [onHoldProgress] streams 0→1; if the user keeps holding to completion
///     [onHoldHome] fires (navigate to accueil). ANY movement past a small
///     jitter, or a release before completion, cancels it cleanly — no
///     navigation and no edge commit.
///
/// State is fully reset on BOTH pointer-up and pointer-cancel, and every timer
/// is cancelled before a commit — so the orb can never freeze on screen (this
/// was V1's number-one bug, designed out here).
class VybiaOrb extends StatefulWidget {
  const VybiaOrb({
    super.key,
    required this.child,
    required this.onDirection,
    this.onPositionChanged,
    this.onPresence,
    this.onAim,
    this.onDoubleTap,
    this.onHoldHome,
    this.onHoldProgress,
    this.enableHoldHome = true,
    this.showOrb = true,
    this.threshold = 72,
    this.orbSize = 88,
    this.holdStill = const Duration(seconds: 3),
    this.holdGrow = const Duration(milliseconds: 1000),
  });

  final Widget child;
  final ValueChanged<OrbDirection> onDirection;

  /// Fires the live pointer position while the orb is active (born → follows),
  /// and `null` once it resets. Lets an overlay — e.g. the refraction lens —
  /// track the orb without re-implementing the gesture state machine.
  final ValueChanged<Offset?>? onPositionChanged;

  /// Streams the orb's life force, 0..1: ramps up on birth (~150ms fade + scale
  /// in on pointer-down) and back down on the dissolve (~150ms on release /
  /// cancel). An overlay (the refraction bubble) multiplies its own strength by
  /// this so it is *born on touch and gone on release* in lockstep with the orb
  /// — quick but smooth, never an instant pop, never frozen.
  final ValueChanged<double>? onPresence;

  /// Streams the live *aim*: the edge the finger is currently leaning toward and
  /// how close it is to committing (`reach` 0..1). Lets a scene progressively
  /// filter the image toward that edge's colour and recolour the orb, then clear
  /// it on release. Fires `OrbAim.rest` (null direction, 0 reach) when idle.
  final ValueChanged<OrbAim>? onAim;

  /// Fires on a quick double-tap (two still taps inside the double-tap window).
  /// Wired to "return to the previous image/page" — no edge is committed.
  final VoidCallback? onDoubleTap;

  /// Fires when an immobile hold is held all the way to completion — navigate to
  /// the home / accueil. The caller is responsible for the actual navigation.
  final VoidCallback? onHoldHome;

  /// Streams the hold-to-home warning progress, 0 (idle) → 1 (about to navigate
  /// home). A scene can use this to grow its bubble and show the warning hint.
  final ValueChanged<double>? onHoldProgress;

  /// When false, the immobile hold-to-home gesture is disabled entirely (e.g.
  /// on the home/accueil scene itself, where "go home" is a no-op).
  final bool enableHoldHome;

  /// When false the orb's gesture/state machine still runs (and
  /// [onPositionChanged] / [onPresence] still fire) but the painted orb body is
  /// hidden, so a custom visual (the refraction bubble) can stand in for it.
  final bool showOrb;

  final double threshold;
  final double orbSize;

  /// How long the contact must stay essentially STILL before the hold-to-home
  /// warning begins.
  final Duration holdStill;

  /// How long the warning/grow runs before it navigates home if held.
  final Duration holdGrow;

  @override
  State<VybiaOrb> createState() => _VybiaOrbState();
}

class _VybiaOrbState extends State<VybiaOrb> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _appear; // 0→1 birth
  late final AnimationController _dissolve; // 1→0 death
  late final AnimationController _hold; // 0→1 hold-to-home grow

  bool _active = false;
  bool _warning = false; // hold-to-home warning/grow in progress
  Offset _origin = Offset.zero;
  Offset _current = Offset.zero;
  Timer? _dissolveTimer;
  Timer? _immobileTimer; // fires when contact has been still long enough

  // Double-tap tracking.
  DateTime? _lastTapUp;
  Offset _lastTapPos = Offset.zero;
  static const Duration _doubleTapWindow = Duration(milliseconds: 320);
  static const double _doubleTapSlop = 26;

  // Movement past this (px from origin) counts as "aiming", not "still": it
  // cancels the hold-to-home timer/warning and is the normal edge gesture.
  static const double _holdJitter = 16;

  // How big the orb grows at the peak of the hold-to-home warning.
  static const double _holdGrowFactor = 9;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _appear = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 0.0,
    )..addListener(_emitPresence);
    _dissolve = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 1.0,
    )..addListener(_emitPresence);
    _hold = AnimationController(
      vsync: this,
      duration: widget.holdGrow,
      value: 0.0,
    )
      ..addListener(_emitHold)
      ..addStatusListener(_onHoldStatus);
  }

  @override
  void dispose() {
    _dissolveTimer?.cancel();
    _immobileTimer?.cancel();
    _pulse.dispose();
    _appear.dispose();
    _dissolve.dispose();
    _hold.dispose();
    super.dispose();
  }

  // ---- Life force --------------------------------------------------------
  // Birth ramps [_appear] 0→1 while [_dissolve] holds at 1; death reverses
  // [_dissolve] 1→0 while [_appear] holds at 1. The product is a single smooth
  // 0→1→0 curve over the orb's whole life.
  double get _presence =>
      (_appear.value * _dissolve.value).clamp(0.0, 1.0).toDouble();

  void _emitPresence() => widget.onPresence?.call(_presence);

  void _emitHold() => widget.onHoldProgress?.call(_warning ? _hold.value : 0.0);

  void _emitAim() =>
      widget.onAim?.call(_active ? OrbAim(_direction, _reach) : OrbAim.rest);

  // ---- Geometry helpers -------------------------------------------------
  Offset get _delta => _current - _origin;

  OrbDirection? get _direction {
    final d = _delta;
    if (d.distance < 14) return null; // deadzone — no preview tint yet
    if (d.dx.abs() > d.dy.abs()) {
      return d.dx < 0 ? OrbDirection.left : OrbDirection.right;
    }
    return d.dy < 0 ? OrbDirection.up : OrbDirection.down;
  }

  double get _reach =>
      (_delta.distance / widget.threshold).clamp(0.0, 1.0).toDouble();

  // ---- Hold-to-home ------------------------------------------------------
  void _startImmobileTimer() {
    _immobileTimer?.cancel();
    if (!widget.enableHoldHome) return;
    _immobileTimer = Timer(widget.holdStill, _enterWarning);
  }

  void _enterWarning() {
    if (!mounted || !_active) return;
    setState(() => _warning = true);
    _hold.forward(from: 0.0); // orb grows progressively from here
  }

  /// Cancel a hold-to-home in progress WITHOUT navigating or committing an edge.
  /// The orb shrinks back; the caller decides whether to also dissolve.
  void _cancelWarning() {
    _immobileTimer?.cancel();
    if (!_warning) return;
    setState(() => _warning = false);
    _hold.reverse();
    widget.onHoldProgress?.call(0.0);
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _warning) {
      _completeHoldHome();
    }
  }

  void _completeHoldHome() {
    // Cancel EVERYTHING before navigating so nothing lingers / re-fires.
    _dissolveTimer?.cancel();
    _immobileTimer?.cancel();
    _warning = false;
    widget.onHoldHome?.call();
    _reset(); // clean state machine so the orb can never freeze on return
  }

  // ---- Pointer lifecycle ------------------------------------------------
  void _onDown(PointerDownEvent e) {
    _dissolveTimer?.cancel();
    _dissolve.value = 1.0;
    setState(() {
      _active = true;
      _warning = false;
      _origin = e.localPosition;
      _current = e.localPosition;
    });
    _hold.value = 0.0;
    _appear.forward(from: 0.0); // smooth birth, never an instant pop
    _startImmobileTimer();
    widget.onPositionChanged?.call(e.localPosition);
    _emitAim();
  }

  void _onMove(PointerMoveEvent e) {
    if (!_active) return;
    setState(() => _current = e.localPosition);
    // Real movement = aiming → cancel any hold-to-home and stop the still timer.
    if (_delta.distance > _holdJitter) {
      _immobileTimer?.cancel();
      if (_warning) _cancelWarning();
    }
    widget.onPositionChanged?.call(e.localPosition);
    _emitAim();
  }

  void _onRelease() {
    if (!_active) return;
    _immobileTimer?.cancel();

    // A release DURING the hold-to-home warning is a pure cancel: shrink &
    // dissolve, NO navigation, NO edge commit.
    if (_warning) {
      setState(() => _warning = false);
      widget.onHoldProgress?.call(0.0);
      _dissolve.reverse(from: 1.0);
      _dissolveTimer = Timer(const Duration(milliseconds: 160), _reset);
      return;
    }

    final dir = _delta.distance >= widget.threshold ? _direction : null;

    if (dir != null) {
      widget.onDirection(dir);
      _lastTapUp = null; // a committed edge is not half of a double-tap
    } else {
      // A still tap (no commit). Detect a quick double-tap.
      final now = DateTime.now();
      final last = _lastTapUp;
      if (last != null &&
          now.difference(last) <= _doubleTapWindow &&
          (_current - _lastTapPos).distance <= _doubleTapSlop) {
        _lastTapUp = null;
        widget.onDoubleTap?.call();
      } else {
        _lastTapUp = now;
        _lastTapPos = _current;
      }
    }

    // Progressive dissolve, then hard-reset all state so nothing can persist.
    _dissolve.reverse(from: 1.0);
    _dissolveTimer = Timer(const Duration(milliseconds: 160), _reset);
  }

  void _reset() {
    _dissolveTimer?.cancel();
    _immobileTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _active = false;
      _warning = false;
      _origin = Offset.zero;
      _current = Offset.zero;
    });
    _appear.value = 0.0;
    _dissolve.value = 1.0;
    _hold.value = 0.0;
    _emitPresence(); // presence == 0 now
    widget.onHoldProgress?.call(0.0);
    _emitAim(); // aim cleared
    widget.onPositionChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: (_) => _onRelease(),
      onPointerCancel: (_) => _reset(), // never freeze
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (_active && widget.showOrb)
            AnimatedBuilder(
              animation: Listenable.merge([_pulse, _appear, _dissolve, _hold]),
              builder: (context, _) {
                final presence = _presence;
                // Pop-in: scales from 0.62 → 1.0 with the birth curve, then
                // grows further while the hold-to-home warning is active.
                final scale =
                    (0.62 + 0.38 * presence) * (1 + _hold.value * _holdGrowFactor);
                return Positioned(
                  left: _current.dx - widget.orbSize / 2,
                  top: _current.dy - widget.orbSize / 2,
                  width: widget.orbSize,
                  height: widget.orbSize,
                  child: IgnorePointer(
                    child: Transform.scale(
                      scale: scale,
                      child: CustomPaint(
                        painter: OrbPainter(
                          pulse: _pulse.value,
                          opacity: presence,
                          reach: _reach,
                          direction: _direction,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
