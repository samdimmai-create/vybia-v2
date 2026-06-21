import 'package:flutter/material.dart';

import 'edge_palette.dart';

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

  /// The hue this action filters the image (and the orb) toward, taken from the
  /// [activeEdgePalette] so a palette flip restyles every decisive edge at once.
  Color get color => activeEdgePalette.colorFor(this);

  /// Reject doesn't tint — it desaturates the underlying image toward grayscale.
  bool get desaturates => this == EdgeAction.reject;
}
