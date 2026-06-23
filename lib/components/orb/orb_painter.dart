import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Paints the living Vybia orb: a warm pearl core wrapped in layered teal/cyan
/// glow and orbiting rings. [pulse] (0..1) drives a soft breathing motion;
/// [reach] (0..1) is how far the finger has dragged toward [direction], used to
/// bias the glow toward the active edge. [opacity] fades the whole orb for the
/// dissolve.
class OrbPainter extends CustomPainter {
  OrbPainter({
    required this.pulse,
    required this.opacity,
    required this.reach,
    required this.direction,
    this.secondary,
    this.blend = 0,
    this.inZone = false,
  });

  final double pulse;
  final double opacity;
  final double reach;
  final OrbDirection? direction;

  /// S17D: the perpendicular edge to gradient toward near a corner, or null.
  final OrbDirection? secondary;

  /// S17D: how much [secondary]'s colour mixes into the dominant edge's (0..0.5).
  final double blend;

  /// S23: true once the orb's position has entered the chosen edge's DECISION
  /// ZONE — a release now WOULD commit. Adds a single crisp pearl "decision ring"
  /// as the clear threshold cue. Purely ADDITIVE: when false (everywhere outside
  /// the zone) the orb paints exactly as the validated S22 orb did, so the
  /// approach look never regresses; the cue only appears in the near-edge zone.
  final bool inZone;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.001) return;
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = size.shortestSide / 2;
    final phase = pulse * 2 * math.pi;
    // S20C: ONE calm, slow breath. The S17B two-frequency shimmer + drifting
    // caustic read as jitter on the phone, so they are removed — a steady,
    // reliable orb beats a fancy one.
    final breathe = 1.0 + 0.035 * math.sin(phase);
    final r = baseR * breathe;

    // S17C: the directional coloration is PROXIMITY-GATED — at reach 0 (centre /
    // not close to an edge) the orb stays neutral accent, and the edge colour
    // only leans in as it approaches the edge.
    var aimedColor =
        direction == null ? AppColors.accent : AppColors.edgeFor(direction!);
    // S17D: near a corner, gradient the dominant edge colour toward the
    // secondary edge's (the dominant still wins the commit).
    if (direction != null && secondary != null && blend > 0) {
      aimedColor = Color.lerp(
            aimedColor,
            AppColors.edgeFor(secondary!),
            blend.clamp(0.0, 1.0),
          ) ??
          aimedColor;
    }
    final edgeColor =
        Color.lerp(AppColors.accent, aimedColor, reach) ?? aimedColor;

    // Bias offset: glow leans toward the active edge as reach grows.
    Offset bias = Offset.zero;
    if (direction != null) {
      final amt = baseR * 0.18 * reach;
      switch (direction!) {
        case OrbDirection.left:
          bias = Offset(-amt, 0);
          break;
        case OrbDirection.right:
          bias = Offset(amt, 0);
          break;
        case OrbDirection.up:
          bias = Offset(0, -amt);
          break;
        case OrbDirection.down:
          bias = Offset(0, amt);
          break;
      }
    }

    // ---- Outer atmospheric glow ----------------------------------------
    // S8.1A: tighter halo (1.55× vs the old 1.9×) so the smaller orb stays a
    // crisp jewel rather than a soft, oversized cloud.
    final glowCenter = center + bias;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          edgeColor.withValues(alpha: 0.42 * opacity),
          AppColors.primary.withValues(alpha: 0.22 * opacity),
          AppColors.primary.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: glowCenter, radius: r * 1.55));
    canvas.drawCircle(glowCenter, r * 1.55, glowPaint);

    // ---- Orbiting rings -------------------------------------------------
    // S20C: calm ripples — softened opacity, NO per-frame maskFilter blur (the
    // blur passes were extra GPU cost on a tiny orb every frame → stutter).
    for (var i = 0; i < 3; i++) {
      final t = (pulse + i / 3) % 1.0;
      // Tighter ring spread (0.26 vs 0.32) keeps the footprint compact.
      final ringR = r * (1.05 + 0.26 * t);
      final ringOpacity = (1.0 - t) * 0.45 * opacity;
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3 + 1.1 * (1 - t)
        ..color = AppColors.accent.withValues(alpha: ringOpacity);
      canvas.drawCircle(center, ringR, ringPaint);
    }

    // ---- Glass body -----------------------------------------------------
    final bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [
          AppColors.pearl.withValues(alpha: 0.95 * opacity),
          AppColors.accent.withValues(alpha: 0.78 * opacity),
          AppColors.primary.withValues(alpha: 0.55 * opacity),
          edgeColor.withValues(alpha: 0.45 * opacity),
        ],
        stops: const [0.0, 0.4, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, bodyPaint);

    // ---- Inner pearl core (specular highlight) -------------------------
    final coreCenter = center + Offset(-r * 0.22, -r * 0.26);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.pearl.withValues(alpha: 0.98 * opacity),
          AppColors.pearl.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: coreCenter, radius: r * 0.5));
    canvas.drawCircle(coreCenter, r * 0.5, corePaint);

    // ---- Refractive water rim (static) ----------------------------------
    // A faint cyan rim keeps the liquid-glass sea-glass feel — STATIC (no blur,
    // no drift) so it never shimmers (S20C).
    canvas.drawCircle(
      center,
      r * 0.985,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.accent.withValues(alpha: 0.20 * opacity),
    );

    // ---- Rim light ------------------------------------------------------
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.pearl.withValues(alpha: 0.30 * opacity);
    canvas.drawCircle(center, r * 0.98, rimPaint);

    // ---- S23: decision ring (threshold cue) -----------------------------
    // The unmistakable "you've ENTERED the decision zone" cue: one crisp pearl
    // ring just outside the body, breathing with the orb. Only drawn inside the
    // zone, so it cleanly signals that a release now commits — and its absence
    // confirms you can still stop short and release safely.
    if (inZone) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = AppColors.pearl.withValues(alpha: 0.85 * opacity);
      canvas.drawCircle(center, r * 1.16, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant OrbPainter old) =>
      old.pulse != pulse ||
      old.opacity != opacity ||
      old.reach != reach ||
      old.direction != direction ||
      old.secondary != secondary ||
      old.blend != blend ||
      old.inZone != inZone;
}
