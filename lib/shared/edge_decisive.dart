import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart' show OrbDirection;
import 'edge_action.dart';
import 'edge_palette.dart';

/// The reusable DECISIVE-EDGE feedback layer.
///
/// Drop this full-bleed above any orb-driven image (see `SceneScaffold`). As the
/// orb nears a decisive edge, the action colour radiates as a WAVE from the
/// CONTACT POINT — the spot on the aimed screen edge the orb is heading toward:
///   1. it is MOST INTENSE at that contact point and fades progressively with
///      radial distance, so even the far frame is lightly touched while the
///      IMAGE STAYS DISTINCT everywhere (never an opaque flood);
///   2. both the peak intensity and the wave's reach scale with `reach`
///      (proximity): far = a subtle halo at the aim point; very close to the
///      edge = the image is almost fully filtered yet still recognisable;
///   3. `reject` instead drains colour to grayscale + darkens. The grayscale
///      itself is applied web-safely by the scene, which wraps its hero image in
///      a [ColorFiltered] using [rejectColorMatrix] (scaled by `reach`); this
///      overlay then adds the radiating slate darken from the contact point so
///      the drain still reads as a wave. (We deliberately do NOT use
///      [BackdropFilter] here — it is unreliable/clipped under Flutter web /
///      CanvasKit, which was why the filter stopped showing on the web build.)
///   4. the ORB's aura leans toward the same colour (a tinted glow at
///      [orbCenter], or a darkening for `reject`).
///
/// Implemented entirely with a [CustomPaint] (radial gradients) — every part is
/// a plain canvas draw, so it renders identically on mobile AND Flutter web.
///
/// It paints nothing when idle, so it costs ~nothing until the user engages.
class EdgeDecisiveOverlay extends StatelessWidget {
  const EdgeDecisiveOverlay({
    super.key,
    required this.action,
    required this.direction,
    required this.reach,
    required this.orbCenter,
    this.lensRadius = 44,
  });

  /// The action mapped to the currently-aimed edge, or null when idle.
  final EdgeAction? action;

  /// The edge being aimed at, or null in the deadzone.
  final OrbDirection? direction;

  /// 0 at centre → 1 at the commit threshold.
  final double reach;

  /// Live orb position (for the aura + the wave's edge-anchor), or null when
  /// resting.
  final Offset? orbCenter;
  final double lensRadius;

  @override
  Widget build(BuildContext context) {
    final a = action;
    final d = direction;
    if (a == null || d == null || reach <= 0.001) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _EdgeDecisivePainter(
          action: a,
          direction: d,
          reach: reach,
          orbCenter: orbCenter,
          lensRadius: lensRadius,
          // The action→colour mapping comes from the active palette; include its
          // index so a live palette flip repaints the wave even when the orb is
          // held still (same action/reach, different hue).
          paletteRev: activeEdgePaletteIndex.value,
        ),
      ),
    );
  }
}

/// The wave's origin: the point on the aimed screen edge the orb is heading
/// toward (so the colour reads as flowing IN from that edge), anchored to the
/// orb's cross-axis position. Falls back to the edge mid-point at rest.
@visibleForTesting
Offset edgeWaveOrigin(Size size, OrbDirection d, Offset? orb) =>
    _waveOrigin(size, d, orb);

/// How far the wave reaches at this [reach] — exposed for tests.
@visibleForTesting
double edgeWaveRadius(Size size, double reach) => _waveRadius(size, reach);

Offset _waveOrigin(Size size, OrbDirection d, Offset? orb) {
  final c = orb ?? Offset(size.width / 2, size.height / 2);
  switch (d) {
    case OrbDirection.left:
      return Offset(0, c.dy);
    case OrbDirection.right:
      return Offset(size.width, c.dy);
    case OrbDirection.up:
      return Offset(c.dx, 0);
    case OrbDirection.down:
      return Offset(c.dx, size.height);
  }
}

/// How far the wave reaches. Grows with [reach]: a tight halo when far, then
/// past the screen diagonal when very close — so at full reach even the opposite
/// corner still catches a little colour (it sits inside the falloff radius).
double _waveRadius(Size size, double reach) {
  final diag = math.sqrt(size.width * size.width + size.height * size.height);
  return diag * (0.42 + 0.95 * reach);
}

/// A radial wave shader spreading [colors] (near → far) from the contact point.
ui.Shader _waveShader(
  Size size,
  OrbDirection d,
  Offset? orb,
  double reach,
  List<Color> colors,
) {
  final origin = _waveOrigin(size, d, orb);
  final r = _waveRadius(size, reach).clamp(1.0, double.infinity);
  return ui.Gradient.radial(origin, r, colors, const [0.0, 1.0]);
}

/// Grayscale (Rec. 709 luma) + darken to ~0.6 brightness — the reject filter.
const List<double> _desaturateDarken = <double>[
  0.2126 * 0.6, 0.7152 * 0.6, 0.0722 * 0.6, 0, 0, //
  0.2126 * 0.6, 0.7152 * 0.6, 0.0722 * 0.6, 0, 0, //
  0.2126 * 0.6, 0.7152 * 0.6, 0.0722 * 0.6, 0, 0, //
  0, 0, 0, 1, 0,
];

const List<double> _identityMatrix = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 1, 0,
];

/// The web-safe reject filter as a [ColorFilter] matrix interpolated by
/// [amount] (0 = untouched image → 1 = full grayscale + darken). The scene wraps
/// its hero image in `ColorFiltered(colorFilter: ColorFilter.matrix(...))` and
/// feeds the live reject `reach` here, so the image actually drains its colour
/// on Flutter web AND mobile (no [BackdropFilter], which is unreliable on web).
List<double> rejectColorMatrix(double amount) {
  final a = amount.clamp(0.0, 1.0).toDouble();
  return <double>[
    for (var i = 0; i < 20; i++)
      _identityMatrix[i] + (_desaturateDarken[i] - _identityMatrix[i]) * a,
  ];
}

class _EdgeDecisivePainter extends CustomPainter {
  _EdgeDecisivePainter({
    required this.action,
    required this.direction,
    required this.reach,
    required this.orbCenter,
    required this.lensRadius,
    required this.paletteRev,
  });

  final EdgeAction action;
  final OrbDirection direction;
  final double reach;
  final Offset? orbCenter;
  final double lensRadius;
  final int paletteRev;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final reject = action.desaturates;
    // Reject radiates a near-black slate (the grayscale drain itself rides on the
    // hero image's ColorFiltered wrapper); the others radiate their action hue.
    final color = reject ? const Color(0xFF0E1417) : action.color;

    // ---- 1. Decisive colour wave from the contact edge -------------------
    // Floods inward from the aimed screen edge as a radial wave. STRONG peak so
    // it visibly filters the hero image as the orb nears the edge (the founder
    // reported the old, gentler wave didn't read on web).
    final edgePeak = reject ? 0.66 : 0.82;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = _waveShader(size, direction, orbCenter, reach, [
          color.withValues(alpha: (edgePeak * reach).clamp(0, 1)),
          color.withValues(alpha: 0.0),
        ]),
    );

    // ---- 2. Orb hotspot --------------------------------------------------
    // A tighter, brighter pool of the action colour centred RIGHT where the user
    // is looking (the orb), so the filter is unmistakable even when the orb is
    // still mid-screen and far from the edge origin.
    final c = orbCenter;
    if (c == null) return;
    final hotR = lensRadius * 3.0 + size.shortestSide * 0.30 * reach;
    final hotPeak = reject ? 0.55 : 0.58;
    canvas.drawCircle(
      c,
      hotR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: (hotPeak * reach).clamp(0, 1)),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: hotR)),
    );

    // ---- 3. Orb aura recolour -------------------------------------------
    final auraR = lensRadius * 2.0;
    if (action.desaturates) {
      // Darken the orb instead of tinting it (no colour to lean toward).
      canvas.drawCircle(
        c,
        auraR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF0E1417).withValues(alpha: 0.5 * reach),
              const Color(0xFF0E1417).withValues(alpha: 0.0),
            ],
            stops: const [0.0, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: auraR)),
      );
    } else {
      // Additive coloured glow — the orb leans into the action colour.
      canvas.drawCircle(
        c,
        auraR,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.5 * reach),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: auraR)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EdgeDecisivePainter old) =>
      old.action != action ||
      old.direction != direction ||
      old.reach != reach ||
      old.orbCenter != orbCenter ||
      old.lensRadius != lensRadius ||
      old.paletteRev != paletteRev;
}
