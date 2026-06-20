import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Soft legibility shadow worn by floating glass-chip / bubble text so it reads
/// instantly over ANY photo without an opaque background. A tight dark glow hugs
/// each glyph; a wider, softer one lifts it off bright/busy regions. Shared by
/// the info bubble (S9.2) and the liquid-glass chrome (S9.3) so reading is fast
/// no matter the background.
const List<Shadow> kGlassTextShadow = [
  Shadow(color: Colors.black, blurRadius: 4),
  Shadow(color: Colors.black87, blurRadius: 14),
];

/// A small liquid-glass capsule — Vybia's sea-glass / water / ice / bubble
/// material applied to the SMALL chrome elements only (the info-bubble badge +
/// tag chips and the edge/choice labels), so it reads as one family with the
/// orb without ever frosting the whole hero image.
///
/// It hits the four S9.3 balance goals at once:
/// * **Light** — the body is translucent (low alphas), so the photo reads
///   through; no backdrop blur, nothing heavy.
/// * **Distinct** — a thin bright glass rim + a faint tinted outer glow lift the
///   bead off busy/bright photos so it never dissolves into the image.
/// * **On-theme** — translucent sea-glass body with a top specular sheen, the
///   glass rim and the glow, fully rounded (capsule); reads as a dew/glass bead.
/// * **Legible** — pair with [kGlassTextShadow] + a strong weight on the child
///   text and it stays glanceable in a second.
///
/// Cheap by design (gradient + border + two shadows): several can sit on screen
/// at ~60fps.
class GlassCapsule extends StatelessWidget {
  const GlassCapsule({
    super.key,
    required this.child,
    this.tint = AppColors.accent,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    this.strong = false,
  });

  /// Usually a single [Text]. The capsule supplies the glass; the child supplies
  /// the (shadowed) glyphs.
  final Widget child;

  /// The decisive-action / brand colour glassily tinting the bead (e.g. the
  /// edge colour for a choice label, brand teal/cyan for the info chips).
  final Color tint;

  final EdgeInsetsGeometry padding;

  /// Primary chips (the badge, the edge labels) carry a touch more body + rim
  /// than secondary ones (tags) so the hierarchy survives the translucency.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final bodyTop = strong ? 0.26 : 0.18;
    final bodyBottom = strong ? 0.40 : 0.30;
    // A bright, mostly-white rim carrying a hint of the tint — the specular
    // edge of a glass bead.
    final rim = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.45),
      tint,
    ).withValues(alpha: 0.60);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // Translucent sea-glass body: a top specular sheen melting into a
        // slightly denser, darker foot — glass, not a flat fill. The low alphas
        // keep the photo readable through it.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: 0.16),
              tint.withValues(alpha: bodyTop),
            ),
            AppColors.surface.withValues(alpha: bodyBottom),
          ],
        ),
        // Thin bright glass rim — the specular edge of the bead.
        border: Border.all(color: rim, width: 1),
        // Faint tinted glow + a soft drop: lifts the bead off busy/bright photos
        // (distinct) without frosting the image.
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.22),
            blurRadius: 12,
            spreadRadius: -3,
          ),
          const BoxShadow(
            color: Colors.black38,
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
