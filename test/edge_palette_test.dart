import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/shared/edge_action.dart';
import 'package:vybia_v2/shared/edge_palette.dart';

void main() {
  // Keep the global selection from leaking between tests / suites.
  tearDown(() => activeEdgePaletteIndex.value = 0);

  group('EdgePalette', () {
    test('there are exactly three labelled palettes A / B / C', () {
      expect(kEdgePalettes.length, 3);
      expect(kEdgePalettes.map((p) => p.id).toList(), ['A', 'B', 'C']);
      for (final p in kEdgePalettes) {
        expect(p.label, isNotEmpty);
      }
    });

    test('colorFor maps every action to that palette\'s hue', () {
      final p = kEdgePalettes.first;
      expect(p.colorFor(EdgeAction.joy), p.joy);
      expect(p.colorFor(EdgeAction.reject), p.reject);
      expect(p.colorFor(EdgeAction.curious), p.curious);
      expect(p.colorFor(EdgeAction.go), p.go);
      expect(p.colorFor(EdgeAction.neutral), p.neutral);
    });

    test('each palette gives every action a distinct colour (a guest can tell '
        'the edges apart)', () {
      for (final p in kEdgePalettes) {
        final colours = {p.joy, p.reject, p.curious, p.go, p.neutral};
        expect(colours.length, 5, reason: 'palette ${p.id} has a duplicate');
      }
    });
  });

  group('active selection + switcher', () {
    test('defaults to palette A', () {
      expect(activeEdgePalette.id, 'A');
    });

    test('cycleEdgePalette advances A → B → C → A', () {
      expect(activeEdgePalette.id, 'A');
      cycleEdgePalette();
      expect(activeEdgePalette.id, 'B');
      cycleEdgePalette();
      expect(activeEdgePalette.id, 'C');
      cycleEdgePalette();
      expect(activeEdgePalette.id, 'A');
    });

    test('EdgeAction.color follows the active palette', () {
      activeEdgePaletteIndex.value = 0;
      expect(EdgeAction.joy.color, kEdgePalettes[0].joy);
      activeEdgePaletteIndex.value = 1;
      expect(EdgeAction.joy.color, kEdgePalettes[1].joy);
    });
  });
}
