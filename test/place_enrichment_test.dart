import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/reco/db/catalog_entry.dart';
import 'package:vybia_v2/features/reco/model/activity.dart';
import 'package:vybia_v2/features/reco/model/activity_kind.dart';

/// S12C — build-time place enrichment (Geoapify/Foursquare): the new openingHours
/// + rating fields round-trip losslessly, project onto the scoring Activity, and
/// the BUNDLED catalog actually carries real enriched hours (so the runtime, which
/// reads only this offline asset, shows them).
void main() {
  CatalogEntry place({String? hours, double? rating}) => CatalogEntry(
        id: 'p1',
        name: 'Café Test',
        kind: ActivityKind.place,
        category: ActivityCategory.cafe,
        descFr: 'Un café.',
        imageRef: 'assets/images/places/cafe.jpg',
        tags: const {Dimension.energy: 0.5},
        motives: (hedonic: 0.5, relaxation: 0.5, eudaimonic: 0.5),
        priceTier: 1,
        indoor: true,
        lat: 45.5,
        lng: -73.5,
        openingHours: hours,
        rating: rating,
        source: 'osm+geoapify',
      );

  test('openingHours + rating round-trip through toJson/fromJson', () {
    final e = place(hours: 'Lun-Ven 09:00-18:00', rating: 4.3);
    final back = CatalogEntry.tryFromJson(jsonDecode(jsonEncode(e.toJson())))!;
    expect(back.openingHours, 'Lun-Ven 09:00-18:00');
    expect(back.rating, 4.3);
    expect(back.source, 'osm+geoapify');
  });

  test('absent enrichment fields stay null (purely additive)', () {
    final back = CatalogEntry.tryFromJson(jsonDecode(jsonEncode(place().toJson())))!;
    expect(back.openingHours, isNull);
    expect(back.rating, isNull);
  });

  test('enriched facts project onto the scoring Activity for the detail card', () {
    final a = place(hours: 'Lun-Dim 11:30-3:00', rating: 4.1).toActivity();
    expect(a.openingHours, 'Lun-Dim 11:30-3:00');
    expect(a.rating, 4.1);
  });

  test('the bundled catalog carries REAL enriched opening hours (offline)', () {
    final file = File('assets/data/vybia_catalog.json');
    expect(file.existsSync(), isTrue);
    final db = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final entries = (db['entries'] as List).cast<Map<String, dynamic>>();
    final enriched =
        entries.where((e) => (e['openingHours'] as String?)?.isNotEmpty ?? false);
    expect(enriched.length, greaterThanOrEqualTo(10),
        reason: 'S12C enrichment should have added real hours to many places');
    // Every enriched place is provenance-tagged so the source is auditable.
    for (final e in enriched) {
      expect((e['source'] as String).contains('geoapify') ||
          (e['source'] as String).contains('foursquare'), isTrue);
    }
  });
}
