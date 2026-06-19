import 'package:flutter/material.dart';

/// Vybia V2 sea-glass palette.
///
/// The whole brand lives in the teal/cyan/aqua/pearl/champagne family.
/// There is intentionally NO pure black and NO purple anywhere in the base
/// palette — only the lavender *edge* accent leans violet, and only as a
/// directional cue on the orb.
class AppColors {
  AppColors._();

  // ---- Core surfaces ----------------------------------------------------
  /// Deep sea-glass background. Never pure black.
  static const Color bg = Color(0xFF0E1518);

  /// Raised surface (cards, sheets).
  static const Color surface = Color(0xFF12211F);

  /// A slightly lifted surface for layering glass over glass.
  static const Color surfaceRaised = Color(0xFF18302C);

  // ---- Brand ------------------------------------------------------------
  static const Color primary = Color(0xFF5FB7A8); // teal
  static const Color accent = Color(0xFF8FD4D0); // mist cyan
  static const Color pearl = Color(0xFFF3EDE3); // warm pearl
  static const Color champagne = Color(0xFFE9D9B8); // champagne

  // ---- Text ------------------------------------------------------------
  static const Color textPrimary = pearl;
  static const Color textSecondary = Color(0xFFB6C7C2);
  static const Color textMuted = Color(0xFF7C9088);

  // ---- Directional edge colors -----------------------------------------
  static const Color edgeLeft = Color(0xFFF2B65C); // amber / gold
  static const Color edgeRight = Color(0xFF6FD3E0); // cyan / cold blue
  static const Color edgeUp = Color(0xFFB9A8E8); // lavender / sky violet
  static const Color edgeDown = Color(0xFF7FCBA8); // sea-glass green

  static Color edgeFor(OrbDirection d) {
    switch (d) {
      case OrbDirection.left:
        return edgeLeft;
      case OrbDirection.right:
        return edgeRight;
      case OrbDirection.up:
        return edgeUp;
      case OrbDirection.down:
        return edgeDown;
    }
  }

  // ---- Gradients --------------------------------------------------------
  /// Ambient background wash — keeps the deep sea-glass from reading flat.
  static const LinearGradient bgWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF101C1F), Color(0xFF0C1316), Color(0xFF0E1518)],
    stops: [0.0, 0.55, 1.0],
  );
}

/// The four committable orb directions. Kept here so colors + the orb agree.
enum OrbDirection { left, right, up, down }
