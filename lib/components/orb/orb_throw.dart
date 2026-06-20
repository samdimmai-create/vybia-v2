import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../../core/theme/app_colors.dart' show OrbDirection;

/// The per-step outcome of a [ThrowSimulation].
enum ThrowResult {
  /// Still in flight — keep stepping.
  flying,

  /// Reached a decisive edge → the caller commits that direction.
  commit,

  /// Decelerated below the stop speed without reaching an edge → no commit,
  /// the orb dissolves.
  dissolve,
}

/// Pure, deterministic ballistic motion for a *thrown* orb (S8 — V1 momentum
/// parity). Seeded by the release velocity, it travels on its own along the
/// throw's direction and force, on a gently curved/arced path, with friction.
///
/// It is intentionally free of any Flutter widget/ticker so it can be unit
/// tested directly (step it with fixed `dt`s and assert the outcome). The widget
/// ([VybiaOrb]) drives it from a [Ticker]; the tests drive it with a loop.
///
/// Physics:
///   * friction — exponential per-second velocity decay (frame-rate independent);
///   * curve    — a small constant angular drift, seeded by the throw's
///                horizontal sign, so the path arcs rather than running dead
///                straight;
///   * commit   — when the orb crosses within [edgeMargin] of a screen edge
///                *while still heading into it*, that edge commits;
///   * dissolve — if the speed falls below [stopSpeed] first, it dies with no
///                commit.
class ThrowSimulation {
  ThrowSimulation({
    required this.bounds,
    required Offset position,
    required Offset velocity,
    this.edgeMargin = 44,
    this.friction = 1.7,
    this.curveRate = 0.8,
    this.stopSpeed = 150,
  })  : _pos = position,
        _vel = velocity,
        _curveSign = velocity.dx >= 0 ? 1.0 : -1.0;

  /// The scene the orb is flying inside.
  final Size bounds;

  /// How close (px) to an edge counts as "reached".
  final double edgeMargin;

  /// Exponential velocity decay, per second (higher = stops sooner).
  final double friction;

  /// Constant angular drift, rad/s, giving the path its arc.
  final double curveRate;

  /// Speed (px/s) below which a throw that hasn't reached an edge dies.
  final double stopSpeed;

  Offset _pos;
  Offset _vel;
  final double _curveSign;
  OrbDirection? _committed;

  Offset get position => _pos;
  Offset get velocity => _vel;
  double get speed => _vel.distance;
  OrbDirection? get committedDirection => _committed;

  /// The edge the orb is currently heading toward (dominant velocity axis), used
  /// to recolour the orb decisively as it nears — exactly like a held aim.
  OrbDirection? get headingEdge {
    if (_vel.distance < 1) return null;
    if (_vel.dx.abs() >= _vel.dy.abs()) {
      return _vel.dx < 0 ? OrbDirection.left : OrbDirection.right;
    }
    return _vel.dy < 0 ? OrbDirection.up : OrbDirection.down;
  }

  /// 0 at mid-scene → 1 right at the heading edge (the decisive "reach").
  double get reach {
    final edge = headingEdge;
    if (edge == null) return 0;
    switch (edge) {
      case OrbDirection.left:
        return (1 - _pos.dx / (bounds.width * 0.5)).clamp(0.0, 1.0).toDouble();
      case OrbDirection.right:
        return (1 - (bounds.width - _pos.dx) / (bounds.width * 0.5))
            .clamp(0.0, 1.0)
            .toDouble();
      case OrbDirection.up:
        return (1 - _pos.dy / (bounds.height * 0.5)).clamp(0.0, 1.0).toDouble();
      case OrbDirection.down:
        return (1 - (bounds.height - _pos.dy) / (bounds.height * 0.5))
            .clamp(0.0, 1.0)
            .toDouble();
    }
  }

  /// Advance the simulation by [dt] seconds and report the outcome.
  ThrowResult step(double dt) {
    if (_committed != null) return ThrowResult.commit;
    if (dt <= 0) return ThrowResult.flying;

    // 1. Friction (exponential, frame-rate independent).
    _vel = _vel * (1.0 / (1.0 + friction * dt));

    // 2. Curve — rotate the velocity a touch so the path arcs.
    final ang = curveRate * _curveSign * dt;
    final c = math.cos(ang), s = math.sin(ang);
    _vel = Offset(_vel.dx * c - _vel.dy * s, _vel.dx * s + _vel.dy * c);

    // 3. Integrate position.
    _pos = _pos + _vel * dt;

    // 4. Edge commit — only if still heading INTO that edge (so it can't commit
    //    an edge it is leaving).
    final m = edgeMargin;
    if (_pos.dx <= m && _vel.dx < 0) return _commit(OrbDirection.left);
    if (_pos.dx >= bounds.width - m && _vel.dx > 0) {
      return _commit(OrbDirection.right);
    }
    if (_pos.dy <= m && _vel.dy < 0) return _commit(OrbDirection.up);
    if (_pos.dy >= bounds.height - m && _vel.dy > 0) {
      return _commit(OrbDirection.down);
    }

    // 5. Otherwise, did it run out of momentum?
    if (_vel.distance < stopSpeed) return ThrowResult.dissolve;
    return ThrowResult.flying;
  }

  ThrowResult _commit(OrbDirection d) {
    _committed = d;
    return ThrowResult.commit;
  }
}
