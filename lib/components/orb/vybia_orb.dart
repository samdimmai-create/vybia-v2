import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'orb_painter.dart';

/// The Vybia brand primitive.
///
/// Wraps [child] in a [Listener] (pointer events — never GestureDetector). An
/// orb is *born* at the touch point on pointer-down, *follows* the finger, and
/// either:
///   * commits a direction (left/right/up/down) when dragged past [threshold],
///     firing [onDirection]; or
///   * dissolves in ~150ms on release when below threshold.
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
    this.showOrb = true,
    this.threshold = 72,
    this.orbSize = 132,
  });

  final Widget child;
  final ValueChanged<OrbDirection> onDirection;

  /// Fires the live pointer position while the orb is active (born → follows),
  /// and `null` once it resets. Lets an overlay — e.g. the refraction lens —
  /// track the orb without re-implementing the gesture state machine.
  final ValueChanged<Offset?>? onPositionChanged;

  /// When false the orb's gesture/state machine still runs (and
  /// [onPositionChanged] still fires) but the painted orb body is hidden, so a
  /// custom visual (the refraction bubble) can stand in for the orb.
  final bool showOrb;

  final double threshold;
  final double orbSize;

  @override
  State<VybiaOrb> createState() => _VybiaOrbState();
}

class _VybiaOrbState extends State<VybiaOrb> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _dissolve;

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
    _dissolve = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _dissolveTimer?.cancel();
    _pulse.dispose();
    _dissolve.dispose();
    super.dispose();
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

    // Dissolve, then hard-reset all state so nothing can persist.
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
    _dissolve.value = 1.0;
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
              animation: Listenable.merge([_pulse, _dissolve]),
              builder: (context, _) {
                return Positioned(
                  left: _current.dx - widget.orbSize / 2,
                  top: _current.dy - widget.orbSize / 2,
                  width: widget.orbSize,
                  height: widget.orbSize,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: OrbPainter(
                        pulse: _pulse.value,
                        opacity: _dissolve.value,
                        reach: _reach,
                        direction: _direction,
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
