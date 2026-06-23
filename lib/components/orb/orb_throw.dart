import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../../core/theme/app_colors.dart' show OrbDirection;

// ---- S23: the DECISION ZONE -------------------------------------------------
// The single rule that makes the orb's decision precise & controllable: a choice
// commits ONLY when the orb's POSITION reaches a band near the chosen edge — the
// outer [kDecisionZoneFrac] of that axis toward the edge. The whole centre of the
// scene is OUTSIDE every zone, so nothing can commit there. This REPLACES S18's
// travel/velocity-from-origin commit, which fired from a short swipe anywhere
// (even at the centre) — the regression the founder felt as "decides before
// reaching the zone, not controllable".

/// Depth of the decision zone, as a fraction of the relevant axis (width for
/// left/right, height for up/down). Tunable: larger = the zone reaches further
/// inward (easier to trigger, less precise); smaller = you must guide the orb
/// closer to the edge (more precise, more deliberate). Start at the controllable
/// outer ~22%.
const double kDecisionZoneFrac = 0.22;

/// Whether [pos] sits inside [edge]'s decision zone — the outer [zoneFrac] of the
/// scene toward that edge. False for an unlaid-out (zero) scene.
bool inDecisionZone(
  Size bounds,
  OrbDirection edge,
  Offset pos, {
  double zoneFrac = kDecisionZoneFrac,
}) {
  if (bounds.width <= 0 || bounds.height <= 0) return false;
  switch (edge) {
    case OrbDirection.left:
      return pos.dx <= bounds.width * zoneFrac;
    case OrbDirection.right:
      return pos.dx >= bounds.width * (1 - zoneFrac);
    case OrbDirection.up:
      return pos.dy <= bounds.height * zoneFrac;
    case OrbDirection.down:
      return pos.dy >= bounds.height * (1 - zoneFrac);
  }
}

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
///   * commit   — S23: when the orb's POSITION enters the decision zone of the
///                edge it is heading into ([inDecisionZone]), that edge commits —
///                NOT on release velocity, and NOT at the very edge. A flick is a
///                visible glide that "reaches the zone, then commits".
///   * dissolve — if the speed falls below [stopSpeed] before the orb reaches the
///                zone, it dies with no commit (a weak flick that stops short).
class ThrowSimulation {
  ThrowSimulation({
    required this.bounds,
    required Offset position,
    required Offset velocity,
    // S18 (founder fix — throws must actually LAND): a flick carries the orb on a
    // visible glide. Less friction (1.7→1.0) + a lower stop speed (150→80) so it
    // glides across the scene instead of fizzling out mid-image. S23: it now
    // commits when it reaches the DECISION ZONE (see [zoneFrac] / [inDecisionZone])
    // rather than at the very edge, so a deliberate flick reaches the zone and a
    // weak one stops short and dissolves.
    this.zoneFrac = kDecisionZoneFrac,
    this.friction = 1.0,
    this.curveRate = 0.8,
    this.stopSpeed = 80,
  })  : _pos = position,
        _vel = velocity,
        _curveSign = velocity.dx >= 0 ? 1.0 : -1.0;

  /// The scene the orb is flying inside.
  final Size bounds;

  /// Decision-zone depth (fraction of the axis toward the edge) at which the
  /// flying orb commits — see [inDecisionZone].
  final double zoneFrac;

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

    // 4. Decision-zone commit (S23) — the moment the orb's POSITION enters the
    //    decision zone of the edge it is heading INTO, that edge commits.
    //    [headingEdge] is derived from the current velocity, so this can never
    //    commit an edge the orb is leaving; a weak flick that never reaches the
    //    zone falls through to step 5 and dissolves.
    final edge = headingEdge;
    if (edge != null && inDecisionZone(bounds, edge, _pos, zoneFrac: zoneFrac)) {
      return _commit(edge);
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
