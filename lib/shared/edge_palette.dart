import 'package:flutter/material.dart';

import 'edge_action.dart';

/// A complete EDGE COLOUR palette: one cohesive hue per decisive action
/// (Intéressant / Pas intéressant / Plus d'infos / Planifier) plus the neutral
/// brand tint. The whole app's edge filter AND edge labels read their colour
/// from the [activeEdgePalette], so flipping the palette restyles every decisive
/// edge at once.
///
/// All three palettes live in Vybia's water / glass / ice / sea-glass world; we
/// keep one colour per *action* (not per direction) so the colour always means
/// the same thing, and so a label's tint matches the wave it triggers.
class EdgePalette {
  const EdgePalette({
    required this.id,
    required this.label,
    required this.joy,
    required this.reject,
    required this.curious,
    required this.go,
    required this.neutral,
  });

  /// Short switcher id shown to the founder: 'A' / 'B' / 'C'.
  final String id;

  /// Human name for the report / switcher subtitle.
  final String label;

  /// Intéressant / J'aime / Oui — the positive reaction.
  final Color joy;

  /// Pas intéressant — drains the image (the slate also tints the label).
  final Color reject;

  /// Plus d'infos — curiosity.
  final Color curious;

  /// Planifier / Confirmer — go / commit.
  final Color go;

  /// Plain navigation / neutral choice.
  final Color neutral;

  Color colorFor(EdgeAction a) {
    switch (a) {
      case EdgeAction.joy:
        return joy;
      case EdgeAction.reject:
        return reject;
      case EdgeAction.curious:
        return curious;
      case EdgeAction.go:
        return go;
      case EdgeAction.neutral:
        return neutral;
    }
  }
}

/// The three selectable palettes. Hex values are documented in the S14 report so
/// the founder can name the one he keeps.
const List<EdgePalette> kEdgePalettes = <EdgePalette>[
  // A — "Aurore glacée": cool ice/glass with a soft warm dawn accent for the
  // positive edge (warmth = welcome, without the harsh gold the founder disliked).
  EdgePalette(
    id: 'A',
    label: 'Aurore glacée',
    joy: Color(0xFFF2C879), // soft champagne-gold
    reject: Color(0xFF33454A), // cold slate (drain)
    curious: Color(0xFF86C5E6), // glacier blue
    go: Color(0xFF5FC9A0), // sea-glass green
    neutral: Color(0xFF8FD4D0), // mist cyan
  ),
  // B — "Lagune profonde": deeper, more saturated water-neon — reads strongest
  // on the hero photos, most "filter-like".
  EdgePalette(
    id: 'B',
    label: 'Lagune profonde',
    joy: Color(0xFF2FD9C3), // turquoise
    reject: Color(0xFF1E2D33), // ink slate (drain)
    curious: Color(0xFF5C8CF0), // cobalt
    go: Color(0xFF3FD17A), // spring green
    neutral: Color(0xFF5FB7A8), // teal
  ),
  // C — "Verre pastel": soft, low-saturation pastel glass — the calmest, most
  // diffuse tint of the three.
  EdgePalette(
    id: 'C',
    label: 'Verre pastel',
    joy: Color(0xFFE8C9A0), // peach-sand
    reject: Color(0xFF3C4A4E), // dove slate (drain)
    curious: Color(0xFFA9C2EE), // periwinkle
    go: Color(0xFF9BE0C2), // seafoam
    neutral: Color(0xFFBFE3DF), // pale aqua
  ),
];

/// The live palette selection. **Palette A (*Aurore glacée*) is the permanent
/// app-wide default** (index 0). The founder can still cycle it with the in-app
/// switcher chip (see [SceneScaffold]); the whole edge system rereads it, so the
/// change is instant and global.
///
/// S15.0: the selection is now PERSISTED across full page reloads. `main()`
/// hydrates this notifier from [AppStore.readPaletteIndex] before first paint
/// (defaulting to A when nothing was ever saved) and saves every change back —
/// so a reload no longer resets to a session default.
///
/// Wrap the app (or any subtree that must restyle on a flip) in a
/// [ValueListenableBuilder] on this notifier.
final ValueNotifier<int> activeEdgePaletteIndex = ValueNotifier<int>(0);

/// The currently-selected palette.
EdgePalette get activeEdgePalette =>
    kEdgePalettes[activeEdgePaletteIndex.value % kEdgePalettes.length];

/// Advance A → B → C → A. Wired to the switcher chip.
void cycleEdgePalette() => activeEdgePaletteIndex.value =
    (activeEdgePaletteIndex.value + 1) % kEdgePalettes.length;
