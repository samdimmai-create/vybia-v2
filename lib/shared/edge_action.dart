import 'package:flutter/material.dart';

/// The *meaning* of a decisive edge, which drives its colour psychology rather
/// than a fixed per-direction hue. As the orb nears an edge, that edge's colour
/// progressively filters the image and recolours the orb (see [EdgeDecisive]).
enum EdgeAction {
  /// Positive / "Intéressant" / Oui → joy: warm yellow-gold.
  joy,

  /// Negative / "Pas intéressant" / Supprimer → drain colour to B&W + darken.
  reject,

  /// Detail / "Plus d'infos" → curiosity: blue / indigo.
  curious,

  /// Plan / commit / "Planifier" / "Confirmer" → go / contentment: green.
  go,

  /// Plain navigation or a neutral choice → gentle sea-glass brand tint.
  neutral;

  /// The hue this action filters the image (and the orb) toward.
  Color get color {
    switch (this) {
      case EdgeAction.joy:
        return const Color(0xFFFFC24D); // warm gold
      case EdgeAction.reject:
        return const Color(0xFF0E1417); // near-black slate (drain + darken)
      case EdgeAction.curious:
        return const Color(0xFF6E8BFF); // indigo / blue
      case EdgeAction.go:
        return const Color(0xFF4FC98A); // sea-glass green
      case EdgeAction.neutral:
        return const Color(0xFF8FD4D0); // mist cyan (brand)
    }
  }

  /// Reject doesn't tint — it desaturates the underlying image toward grayscale.
  bool get desaturates => this == EdgeAction.reject;
}
