import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../../core/theme/app_colors.dart';
import 'orb_painter.dart';
import 'orb_throw.dart';

/// A live snapshot of where the orb is aiming: the edge it's leaning toward
/// ([direction], null in the deadzone) and how close it is to committing
/// ([reach], 0 at centre → 1 at the threshold).
class OrbAim {
  const OrbAim(this.direction, this.reach, {this.secondary, this.blend = 0});

  final OrbDirection? direction;
  final double reach;

  /// S17D: when heading into a CORNER, the perpendicular edge the orb is also
  /// leaning toward — null on a cardinal aim. The committed choice is still the
  /// dominant [direction]; this only colours the effect (a two-edge gradient).
  final OrbDirection? secondary;

  /// How much the [secondary] edge's colour mixes into the dominant edge's:
  /// 0 = pure cardinal → 0.5 = a perfect 45° corner (an even blend).
  final double blend;

  /// Idle aim — no direction, no reach.
  static const OrbAim rest = OrbAim(null, 0);
}

// ---- Near-edge proximity model (VISUAL ONLY) ----------------------------
// S17C introduced proximity-to-the-edge as the decisive feel; S20A DECOUPLES it
// from whether a choice commits. This reach now drives ONLY the visual bloom
// (the filter/coloration are off around the centre and intensify as the orb
// approaches an edge); the COMMIT is travel-based (see `_commitDirection`), so a
// normal directional swipe registers reliably wherever the orb is released.

/// Depth of the near-edge zone, as a fraction of the scene's SHORTER side. The
/// decisive VISUAL is 0 beyond this depth from an edge (around the centre) and
/// ramps to 1 at the edge.
const double kEdgeZoneFrac = 0.42;

/// How close the orb is to the screen edge it is aiming at: 0 around the centre
/// (outside the near-edge band) → 1 right at the edge. The reach reported to the
/// scene, so the decisive filter is off mid-scene and blooms only on approach.
double edgeProximityReach(
  Size bounds,
  OrbDirection dir,
  Offset pos, {
  double zoneFrac = kEdgeZoneFrac,
}) {
  if (bounds.width <= 0 || bounds.height <= 0) return 0;
  final double dist;
  switch (dir) {
    case OrbDirection.left:
      dist = pos.dx;
    case OrbDirection.right:
      dist = bounds.width - pos.dx;
    case OrbDirection.up:
      dist = pos.dy;
    case OrbDirection.down:
      dist = bounds.height - pos.dy;
  }
  final zone = bounds.shortestSide * zoneFrac;
  if (zone <= 0) return 0;
  return (1 - dist / zone).clamp(0.0, 1.0).toDouble();
}

/// S17D: the perpendicular edge the orb is also leaning toward (for a corner
/// gradient), or null when the aim is essentially cardinal. [primary] is the
/// dominant-axis edge; [delta] is the drag vector. The minor axis must be at
/// least [minorFrac] of the major to count as "heading into a corner".
OrbDirection? perpendicularEdge(
  OrbDirection primary,
  Offset delta, {
  // S21C: lowered 0.18→0.12 so a moderate diagonal near a corner registers its
  // perpendicular edge earlier, letting the two-edge gradient actually show on
  // the phone (the commit still goes to the dominant axis — see deliberateCommit).
  double minorFrac = 0.12,
}) {
  final horiz =
      primary == OrbDirection.left || primary == OrbDirection.right;
  final major = horiz ? delta.dx.abs() : delta.dy.abs();
  final minor = horiz ? delta.dy.abs() : delta.dx.abs();
  if (major <= 0 || minor < major * minorFrac) return null;
  if (horiz) return delta.dy < 0 ? OrbDirection.up : OrbDirection.down;
  return delta.dx < 0 ? OrbDirection.left : OrbDirection.right;
}

/// S17D: how much the secondary edge's colour mixes into the dominant edge's:
/// 0 = pure cardinal → 0.5 = a perfect 45° corner. Weighted by both the
/// diagonal-ness of the aim ([diagRatio] = minor/major, 0..1) AND the orb's
/// proximity to each edge, so a blend only blooms when the orb is genuinely near
/// a corner, and the closer edge dominates the mix.
///
/// S21C: the founder reported the corner gradient "didn't work" on the phone —
/// the old `share * diagRatio` weighting made the blend nearly invisible for any
/// aim that wasn't a near-perfect 45°. The diagonal-ness now lifts the mix on a
/// floor curve (`0.45 + 0.55·diagRatio`) so even a moderate diagonal near a
/// corner shows a CLEARLY visible two-edge blend, while a pure cardinal aim still
/// produces no secondary edge at all (see [perpendicularEdge]) and so no blend.
/// A perfect 45° (diagRatio 1, equal reach) still lands on the even 0.5 cap.
double cornerBlend(
  double primaryReach,
  double secondaryReach,
  double diagRatio,
) {
  if (secondaryReach <= 0 || primaryReach <= 0) return 0;
  final share = secondaryReach / (primaryReach + secondaryReach); // 0..1
  final weight = 0.45 + 0.55 * diagRatio.clamp(0.0, 1.0);
  return (share * weight).clamp(0.0, 0.5).toDouble();
}

/// S21A — how decisively one axis must beat the other for a release to read as a
/// clear, deliberate cardinal choice (major ≥ this × minor ≈ within ~38° of the
/// axis). Below this the drag is an ambiguous diagonal and does NOT commit.
const double kAxisDominance = 1.25;

/// S21A — the DELIBERATE-commit rule. A release commits a direction only when the
/// drag is an unmistakable swipe: it travelled at least [travel] px from the
/// birth point AND one axis clearly dominates ([dominance]), so an ambiguous
/// ~45° drift or a small jitter never commits — it dissolves. The tuned middle
/// ground between S17's strict edge-gate (intentional swipes silently failed) and
/// S20's hair-trigger (casual drifts committed choices by accident).
OrbDirection? deliberateCommit(
  Offset delta, {
  required double travel,
  double dominance = kAxisDominance,
}) {
  if (delta.distance < travel) return null;
  final ax = delta.dx.abs();
  final ay = delta.dy.abs();
  if (ax >= ay) {
    if (ax < ay * dominance) return null; // too diagonal → ambiguous
    return delta.dx < 0 ? OrbDirection.left : OrbDirection.right;
  }
  if (ay < ax * dominance) return null; // too diagonal → ambiguous
  return delta.dy < 0 ? OrbDirection.up : OrbDirection.down;
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
/// S8 interaction model (V1 momentum parity):
///   * A quick FLICK — a release below the commit distance but above
///     [throwVelocity] — *throws* the orb. It keeps traveling on its own along
///     the release direction/force on a gently curved path (friction); if it
///     reaches a decisive edge it COMMITS that direction exactly like a held
///     commit (same decisive colour as it nears), and if it runs out of
///     momentum first it dissolves with NO commit. See [ThrowSimulation].
///
/// State is fully reset on BOTH pointer-up and pointer-cancel, and every timer
/// (and the flight ticker) is cancelled before a commit — so the orb can never
/// freeze on screen (this was V1's number-one bug, designed out here).
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
    // S8.1A: the painted orb (Accueil) is shrunk to match the smaller scene
    // bubble — a tighter ~ø72 body instead of the old ~ø88.
    this.orbSize = 72,
    this.holdStill = const Duration(milliseconds: 1800),
    this.holdGrow = const Duration(milliseconds: 1300),
    // S21A: a throw must be a deliberate FLICK, not a casual release — raised
    // 720→900 px/s so a relaxed lift no longer flings the orb into a commit.
    this.throwVelocity = 900,
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
  /// warning begins. S8.1C: shortened from a fully-silent 3s (which felt
  /// unresponsive — no feedback for 3 whole seconds) to 1.8s, so the building
  /// portal gives feedback sooner; a deliberate 1.3s grow still gates the
  /// actual navigation (≈3.1s total), so it can't fire by accident.
  final Duration holdStill;

  /// How long the warning/grow runs before it navigates home if held.
  final Duration holdGrow;

  /// Release speed (px/s) at or above which a sub-threshold release becomes a
  /// *throw* (ballistic momentum) instead of a still tap.
  final double throwVelocity;

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
  bool _settling = false; // S9.1C: a stopped throw is fading out in place
  Offset _origin = Offset.zero;
  Offset _current = Offset.zero;
  Timer? _dissolveTimer;
  Timer? _immobileTimer; // fires when contact has been still long enough

  // ---- Throw / momentum (S8) --------------------------------------------
  late final Ticker _flightTicker;
  ThrowSimulation? _sim; // active ballistic flight, or null
  bool _flying = false;
  Offset _flightPos = Offset.zero;
  double? _lastFlightSec;
  Size _bounds = Size.zero; // scene size, captured in build
  VelocityTracker? _tracker; // measures the release velocity of the gesture

  // Double-tap tracking.
  DateTime? _lastTapUp;
  Offset _lastTapPos = Offset.zero;
  // S8.1C: a slightly wider window + a much more forgiving travel slop so a
  // natural quick double-tap (two taps rarely land on the exact same pixel on a
  // 3× phone screen) reliably reads as "back" rather than two dead single taps.
  static const Duration _doubleTapWindow = Duration(milliseconds: 340);
  static const double _doubleTapSlop = 44;

  // Movement past this (px from origin) counts as "aiming", not "still": it
  // cancels the hold-to-home timer/warning and is the normal edge gesture.
  // S8.1C: 16→22 so a resting finger's micro-drift doesn't keep cancelling the
  // hold-to-home before it can begin.
  static const double _holdJitter = 22;

  // How big the orb grows at the peak of the hold-to-home warning.
  static const double _holdGrowFactor = 9;

  // Dissolve durations. A tap/commit dissolves quickly; a thrown orb that runs
  // out of momentum before reaching an edge SETTLES a touch more slowly (S9.1C)
  // — quick but graceful — and recedes deeper as it fades.
  static const Duration _quickDissolve = Duration(milliseconds: 150);
  static const Duration _settleDissolve = Duration(milliseconds: 260);

  // S9.1C proof: pin the orb mid-settle (a stopped throw fading + shrinking in
  // place) for a deterministic Chrome screenshot. `--dart-define=VYBIA_THROWFADE=true`.
  static const bool _kThrowFadeProof = bool.fromEnvironment('VYBIA_THROWFADE');

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
      duration: _quickDissolve,
      value: 1.0,
    )..addListener(_emitPresence);
    _hold = AnimationController(
      vsync: this,
      duration: widget.holdGrow,
      value: 0.0,
    )
      ..addListener(_emitHold)
      ..addStatusListener(_onHoldStatus);
    _flightTicker = createTicker(_onFlightTick);

    if (_kThrowFadeProof) {
      // Freeze the orb part-way through a throw-stop settle: present but fading
      // (presence ≈ 0.5) and shrunk, resting a bit off-centre where it ran out
      // of momentum (never at an edge).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _bounds == Size.zero) return;
        // An empty region (not over any label) so the fading orb reads clearly.
        final rest = Offset(_bounds.width * 0.30, _bounds.height * 0.66);
        setState(() {
          _active = true;
          _settling = true;
          _origin = rest; // delta 0 → no edge aim
          _current = rest;
        });
        _appear.value = 1.0;
        _dissolve.value = 0.55; // mid-fade (faded + scaled down, in place)
      });
    }
  }

  @override
  void dispose() {
    _dissolveTimer?.cancel();
    _immobileTimer?.cancel();
    _flightTicker.dispose();
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

  void _emitAim() => widget.onAim?.call(
        _active
            ? OrbAim(
                _direction,
                _reach,
                secondary: _secondary,
                blend: _cornerBlend,
              )
            : OrbAim.rest,
      );

  // ---- S17D: corner gradient --------------------------------------------
  OrbDirection? get _secondary {
    final d = _direction;
    if (d == null) return null;
    return perpendicularEdge(d, _delta);
  }

  double get _cornerBlend {
    final d = _direction;
    final s = _secondary;
    if (d == null || s == null) return 0;
    final horiz = d == OrbDirection.left || d == OrbDirection.right;
    final major = horiz ? _delta.dx.abs() : _delta.dy.abs();
    final minor = horiz ? _delta.dy.abs() : _delta.dx.abs();
    final diagRatio = major <= 0 ? 0.0 : minor / major;
    return cornerBlend(
      edgeProximityReach(_bounds, d, _current),
      edgeProximityReach(_bounds, s, _current),
      diagRatio,
    );
  }

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

  // S17C: the live reach is the orb's PROXIMITY to the aimed screen edge (0 at
  // centre → 1 at the edge), NOT the old distance-from-origin. So the decisive
  // filter + orb coloration are off mid-scene and intensify only on approach.
  double get _reach {
    final d = _direction;
    if (d == null) return 0;
    return edgeProximityReach(_bounds, d, _current);
  }

  /// The direction a release should COMMIT, or null (→ dissolve).
  ///
  /// S20A: commit is DECOUPLED from the proximity visual — a deliberate drag past
  /// the travel [threshold] commits wherever the orb is released, no edge-hug.
  /// S21A: it must ALSO be a clear cardinal swipe (one axis dominating, via
  /// [deliberateCommit]) so an ambiguous diagonal or a slow drift dissolves
  /// rather than committing a choice the founder never intended.
  OrbDirection? _commitDirection() =>
      deliberateCommit(_delta, travel: widget.threshold);

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
    _stopFlight(); // a fresh touch interrupts any in-flight throw cleanly
    _dissolve.duration = _quickDissolve; // a fresh gesture dissolves quickly
    _dissolve.value = 1.0;
    setState(() {
      _active = true;
      _warning = false;
      _settling = false;
      _origin = e.localPosition;
      _current = e.localPosition;
    });
    _hold.value = 0.0;
    _tracker = VelocityTracker.withKind(e.kind)
      ..addPosition(e.timeStamp, e.localPosition);
    _appear.forward(from: 0.0); // smooth birth, never an instant pop
    _startImmobileTimer();
    widget.onPositionChanged?.call(e.localPosition);
    _emitAim();
  }

  void _onMove(PointerMoveEvent e) {
    if (!_active) return;
    _tracker?.addPosition(e.timeStamp, e.localPosition);
    // S9.0: 1:1 INSTANT tracking — the orb is placed at the *exact* contact
    // point, never an eased/lerped point trailing behind it. Do NOT introduce
    // positional smoothing here.
    //
    // S21A (LATENCY FIX): the position is hard-assigned WITHOUT setState. The
    // painted orb body is repainted every frame by the always-running [_pulse]
    // ticker (its AnimatedBuilder re-reads `_current`), so a setState per
    // pointer-move only forced a redundant full widget rebuild — on Flutter web
    // that rebuild (plus the scene's own per-move rebuild via onPositionChanged)
    // is exactly what made the orb feel HEAVY and TRAIL behind the finger. The
    // raw pointer value now flows straight to the cheap repaint path + the
    // scene's ValueNotifiers, so the orb sits under the finger with no rebuild
    // churn between pointer and paint.
    _current = e.localPosition;
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

    final dir = _commitDirection();

    if (dir != null) {
      // S20B: cancel EVERYTHING before the commit fires, so nothing lingers,
      // re-fires, or animates after a navigation. The callback may navigate and
      // dispose this widget — guard before touching any controller (calling
      // .reverse() on a disposed controller would throw mid-pointer-handling and
      // could wedge the gesture, reading as a "frozen" orb).
      _immobileTimer?.cancel();
      _stopFlight();
      _warning = false;
      _lastTapUp = null; // a committed edge is not half of a double-tap
      widget.onDirection(dir);
      if (!mounted) return;
      _dissolve.reverse(from: 1.0);
      _dissolveTimer = Timer(const Duration(milliseconds: 160), _reset);
      return;
    }

    // Sub-threshold release: a quick FLICK becomes a throw (momentum). A
    // near-stationary release falls through to the tap / double-tap path.
    final vel = _tracker?.getVelocity().pixelsPerSecond ?? Offset.zero;
    if (vel.distance >= widget.throwVelocity && _bounds != Size.zero) {
      _startThrow(_current, vel);
      return;
    }

    {
      // A still tap (no commit). Detect a quick double-tap.
      final now = DateTime.now();
      final last = _lastTapUp;
      if (last != null &&
          now.difference(last) <= _doubleTapWindow &&
          (_current - _lastTapPos).distance <= _doubleTapSlop) {
        _lastTapUp = null;
        widget.onDoubleTap?.call();
        // The double-tap callback (e.g. back-nav / maybePop) may dispose this
        // widget — bail before touching any controller (S20B).
        if (!mounted) return;
      } else {
        _lastTapUp = now;
        _lastTapPos = _current;
      }
    }

    // Progressive dissolve, then hard-reset all state so nothing can persist.
    _dissolve.reverse(from: 1.0);
    _dissolveTimer = Timer(const Duration(milliseconds: 160), _reset);
  }

  // ---- Throw / momentum --------------------------------------------------
  /// Stop any in-flight throw immediately, without committing or dissolving
  /// (used when a fresh touch lands mid-flight).
  void _stopFlight() {
    if (_flightTicker.isActive) _flightTicker.stop();
    _flying = false;
    _sim = null;
    _lastFlightSec = null;
  }

  /// Seed and start a ballistic flight from [pos] with release velocity [vel].
  void _startThrow(Offset pos, Offset vel) {
    _sim = ThrowSimulation(bounds: _bounds, position: pos, velocity: vel);
    _flying = true;
    _flightPos = pos;
    _lastFlightSec = null;
    // Keep the orb fully present during flight (born, not dissolving).
    _appear.value = 1.0;
    _dissolve.value = 1.0;
    _flightTicker.start();
  }

  void _onFlightTick(Duration elapsed) {
    final sim = _sim;
    if (sim == null) return;
    final sec = elapsed.inMicroseconds / 1e6;
    final dt = _lastFlightSec == null
        ? 1 / 60
        : (sec - _lastFlightSec!).clamp(0.0, 0.05).toDouble();
    _lastFlightSec = sec;
    final result = sim.step(dt);
    setState(() => _flightPos = sim.position);
    widget.onPositionChanged?.call(sim.position);
    // Decisive colour as it nears the edge — exactly like a held aim.
    widget.onAim?.call(OrbAim(sim.headingEdge, sim.reach));
    if (result == ThrowResult.commit) {
      _endThrow(sim.committedDirection);
    } else if (result == ThrowResult.dissolve) {
      _endThrow(null);
    }
  }

  /// End a flight in COMMIT (an edge was reached) or DISSOLVE (ran out of
  /// momentum) — never a freeze.
  void _endThrow(OrbDirection? committed) {
    // Where the orb actually came to rest (before _stopFlight clears the sim).
    final restPos = _sim?.position ?? _flightPos;
    _stopFlight();
    if (committed != null) {
      widget.onDirection(committed);
      _reset();
      return;
    }
    // S9.1C: it decelerated below stopSpeed mid-scene. Come to rest GRACEFULLY:
    // fade + scale-down IN PLACE, right where it stopped — not an abrupt vanish,
    // and never teleported back to the release point (the build falls back to
    // [_current] once flying, so pin it to the rest position first).
    setState(() {
      _settling = true;
      _current = restPos;
    });
    _dissolve.duration = _settleDissolve;
    _dissolve.reverse(from: 1.0);
    _dissolveTimer =
        Timer(_settleDissolve + const Duration(milliseconds: 20), _reset);
  }

  void _reset() {
    _dissolveTimer?.cancel();
    _immobileTimer?.cancel();
    _stopFlight();
    if (!mounted) return;
    setState(() {
      _active = false;
      _warning = false;
      _settling = false;
      _origin = Offset.zero;
      _current = Offset.zero;
    });
    _appear.value = 0.0;
    _dissolve.duration = _quickDissolve; // restore the quick dissolve
    _dissolve.value = 1.0;
    _hold.value = 0.0;
    _emitPresence(); // presence == 0 now
    widget.onHoldProgress?.call(0.0);
    _emitAim(); // aim cleared
    widget.onPositionChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _bounds = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: (_) => _onRelease(),
          onPointerCancel: (_) => _reset(), // never freeze
          child: Stack(
            children: [
              Positioned.fill(child: widget.child),
              if ((_active || _flying) && widget.showOrb)
                AnimatedBuilder(
                  animation:
                      Listenable.merge([_pulse, _appear, _dissolve, _hold]),
                  builder: (context, _) {
                    final presence = _presence;
                    // During a throw the orb rides the flight position and is
                    // tinted by the edge it is heading toward; otherwise it sits
                    // at the finger and grows with the hold-to-home warning.
                    final pos = _flying ? _flightPos : _current;
                    final dir = _flying ? _sim?.headingEdge : _direction;
                    final reach = _flying ? (_sim?.reach ?? 0.0) : _reach;
                    // S17D: a held aim near a corner gradients toward the
                    // secondary edge; a thrown orb just commits its heading edge.
                    final secondary = _flying ? null : _secondary;
                    final blend = _flying ? 0.0 : _cornerBlend;
                    // S9.1C: while settling from a stopped throw, recede deeper
                    // (toward a small point) as it fades — a graceful exit.
                    final settle = _settling ? (0.30 + 0.70 * presence) : 1.0;
                    final scale = (0.62 + 0.38 * presence) *
                        (1 + _hold.value * _holdGrowFactor) *
                        settle;
                    return Positioned(
                      left: pos.dx - widget.orbSize / 2,
                      top: pos.dy - widget.orbSize / 2,
                      width: widget.orbSize,
                      height: widget.orbSize,
                      child: IgnorePointer(
                        child: Transform.scale(
                          scale: scale,
                          child: CustomPaint(
                            painter: OrbPainter(
                              pulse: _pulse.value,
                              opacity: presence,
                              reach: reach,
                              direction: dir,
                              secondary: secondary,
                              blend: blend,
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
      },
    );
  }
}
