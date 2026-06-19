import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'orb_painter.dart';

/// The Vybia brand primitive.
///
/// Wraps [child] in a [Listener] (pointer events — never GestureDetector). An
/// orb is *born* at the touch point on pointer-down (a ~150ms fade + scale-in,
/// never an instant pop), *follows* the finger, and either:
///   * commits a direction (left/right/up/down) when dragged past [threshold],
///     firing [onDirection]; or
///   * progressively dissolves in ~150ms on release when below threshold.
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
    this.showOrb = true,
    this.threshold = 72,
    this.orbSize = 88,
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

  /// When false the orb's gesture/state machine still runs (and
  /// [onPositionChanged] / [onPresence] still fire) but the painted orb body is
  /// hidden, so a custom visual (the refraction bubble) can stand in for it.
  final bool showOrb;

  final double threshold;
  final double orbSize;

  @override
  State<VybiaOrb> createState() => _VybiaOrbState();
}

class _VybiaOrbState extends State<VybiaOrb> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _appear; // 0→1 birth
  late final AnimationController _dissolve; // 1→0 death

  bool _active = false;
  Offset _origin = Offset.zero;
  Offset _current = Offset.zero;
  Timer? _dissolveTimer;

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
  }

  @override
  void dispose() {
    _dissolveTimer?.cancel();
    _pulse.dispose();
    _appear.dispose();
    _dissolve.dispose();
    super.dispose();
  }

  // ---- Life force --------------------------------------------------------
  // Birth ramps [_appear] 0→1 while [_dissolve] holds at 1; death reverses
  // [_dissolve] 1→0 while [_appear] holds at 1. The product is a single smooth
  // 0→1→0 curve over the orb's whole life.
  double get _presence =>
      (_appear.value * _dissolve.value).clamp(0.0, 1.0).toDouble();

  void _emitPresence() => widget.onPresence?.call(_presence);

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

  // ---- Pointer lifecycle ------------------------------------------------
  void _onDown(PointerDownEvent e) {
    _dissolveTimer?.cancel();
    _dissolve.value = 1.0;
    setState(() {
      _active = true;
      _origin = e.localPosition;
      _current = e.localPosition;
    });
    _appear.forward(from: 0.0); // smooth birth, never an instant pop
    widget.onPositionChanged?.call(e.localPosition);
  }

  void _onMove(PointerMoveEvent e) {
    if (!_active) return;
    setState(() => _current = e.localPosition);
    widget.onPositionChanged?.call(e.localPosition);
  }

  void _onRelease() {
    if (!_active) return;
    final dir = _delta.distance >= widget.threshold ? _direction : null;

    // Cancel every timer before committing — no lingering work.
    _dissolveTimer?.cancel();

    if (dir != null) {
      widget.onDirection(dir);
    }

    // Progressive dissolve, then hard-reset all state so nothing can persist.
    _dissolve.reverse(from: 1.0);
    _dissolveTimer = Timer(const Duration(milliseconds: 160), _reset);
  }

  void _reset() {
    _dissolveTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _active = false;
      _origin = Offset.zero;
      _current = Offset.zero;
    });
    _appear.value = 0.0;
    _dissolve.value = 1.0;
    _emitPresence(); // presence == 0 now
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
              animation: Listenable.merge([_pulse, _appear, _dissolve]),
              builder: (context, _) {
                final presence = _presence;
                // Pop-in: scales from 0.62 → 1.0 with the birth curve.
                final scale = 0.62 + 0.38 * presence;
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
