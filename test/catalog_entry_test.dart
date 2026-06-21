import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/reco/db/catalog_entry.dart';
import 'package:vybia_v2/features/reco/db/preference_taxonomy.dart';
import 'package:vybia_v2/features/reco/model/activity.dart';
import 'package:vybia_v2/features/reco/model/activity_kind.dart';

/// S10A — the multi-kind schema must round-trip losslessly for every kind, and
/// project cleanly onto the engine's lean [Activity].
void main() {
  CatalogEntry sample({
    required String id,
    required ActivityKind kind,
    double? lat,
    double? lng,
    String? startsAt,
    int? runtimeMin,
    String? whereToWatch,
    String? url,
    String? destination,
    double? distanceKm,
  }) {
    return CatalogEntry(
      id: id,
      name: 'Entry $id',
      kind: kind,
      category: ActivityCategory.culture,
      subcategory: 'sub',
      descFr: 'Une description.',
      imageRef: 'assets/images/catalog/$id.jpg',
      tags: const {
        Dimension.energy: 0.4,
        Dimension.social: 0.6,
        Dimension.novelty: 0.7,
        Dimension.distance: 0.5,
        Dimension.indoor: 0.8,
        Dimension.timing: 0.7,
        Dimension.budget: 0.3,
        Dimension.vibe: 0.55,
      },
      motives: (hedonic: 0.6, relaxation: 0.4, eudaimonic: 0.7),
      lms: (
        intellectual: 0.4,
        social: 0.3,
        competence: 0.2,
        stimulusAvoidance: 0.1
      ),
      tagList: const ['drame', 'culte'],
      kidFriendly: true,
      servesAlcohol: false,
      wheelchairAccessible: true,
      petFriendly: false,
      priceTier: 1,
      effortLevel: 0.2,
      indoor: true,
      timeOfDay: const ['soir'],
      seasons: const ['hiver'],
      winterFriendly: true,
      source: 'wikidata',
      sourceId: 'Q$id',
      confidence: 0.8,
      lat: lat,
      lng: lng,
      startsAt: startsAt,
      runtimeMin: runtimeMin,
      year: runtimeMin == null ? null : 2024,
      genre: runtimeMin == null ? null : 'drame',
      whereToWatch: whereToWatch,
      url: url,
      provider: url == null ? null : 'youtube',
      destination: destination,
      distanceKm: distanceKm,
      duration: destination == null ? null : 'week-end',
      imageAttribution: 'Author, CC BY-SA 4.0',
      imageLicense: 'CC BY-SA 4.0',
    );
  }

  test('round-trips every kind losslessly', () {
    final entries = [
      sample(id: 'p1', kind: ActivityKind.place, lat: 45.5, lng: -73.5),
      sample(
          id: 'e1',
          kind: ActivityKind.event,
          lat: 45.5,
          lng: -73.5,
          startsAt: '2026-07-01T19:00:00Z'),
      sample(id: 'f1', kind: ActivityKind.film, runtimeMin: 120, whereToWatch: 'cinema'),
      sample(id: 'o1', kind: ActivityKind.online, url: 'https://example.org'),
      sample(
          id: 't1',
          kind: ActivityKind.travel,
          destination: 'Québec',
          distanceKm: 250),
    ];

    for (final e in entries) {
      final restored =
          CatalogEntry.tryFromJson(jsonDecode(jsonEncode(e.toJson())));
      expect(restored, isNotNull, reason: '${e.kind} failed to parse');
      expect(restored!.id, e.id);
      expect(restored.kind, e.kind);
      expect(restored.category, e.category);
      expect(restored.tags[Dimension.novelty], e.tags[Dimension.novelty]);
      expect(restored.motives.eudaimonic, e.motives.eudaimonic);
      expect(restored.lms?.intellectual, e.lms?.intellectual);
      expect(restored.priceTier, e.priceTier);
      expect(restored.source, e.source);
      expect(restored.confidence, e.confidence);
      // kind-specific fields survive the trip
      expect(restored.startsAt, e.startsAt);
      expect(restored.runtimeMin, e.runtimeMin);
      expect(restored.whereToWatch, e.whereToWatch);
      expect(restored.url, e.url);
      expect(restored.destination, e.destination);
      expect(restored.distanceKm, e.distanceKm);
    }
  });

  test('non-geo kinds project with hasLocation:false', () {
    final film = sample(id: 'f', kind: ActivityKind.film, runtimeMin: 100);
    final a = film.toActivity();
    expect(a.hasLocation, isFalse);
    expect(a.kind, ActivityKind.film);
    // a placeholder coordinate is supplied so the type is satisfied
    expect(a.lat, isNot(0.0));

    final place =
        sample(id: 'p', kind: ActivityKind.place, lat: 45.52, lng: -73.6);
    expect(place.toActivity().hasLocation, isTrue);
  });

  test('copyWith merges a patch (enrichment shape)', () {
    final e = sample(id: 'x', kind: ActivityKind.place, lat: 45.5, lng: -73.5);
    final patched = e.copyWith({
      'descFr': 'Enrichi.',
      'source': 'claude',
      'enrichedAt': '2026-06-20T00:00:00Z',
    });
    expect(patched.descFr, 'Enrichi.');
    expect(patched.source, 'claude');
    expect(patched.enrichedAt, '2026-06-20T00:00:00Z');
    // untouched fields preserved
    expect(patched.id, e.id);
    expect(patched.priceTier, e.priceTier);
  });

  test('llmSlice is compact and prompt-ready', () {
    final e = sample(
        id: 'f', kind: ActivityKind.film, runtimeMin: 100, whereToWatch: 'netflix');
    final slice = e.llmSlice();
    expect(slice['id'], 'f');
    expect(slice['kind'], 'film');
    expect(slice['watch'], 'netflix');
    // heavy/derived fields are excluded from the slice
    expect(slice.containsKey('tags'), isTrue); // tagList only (not the dim map)
    expect(slice['tags'], isA<List<dynamic>>());
  });

  test('preference taxonomy parses from data', () {
    const json = '''
    {"dimensions":[{"id":"energy","labelFr":"Énergie"}],
     "categories":[{"id":"cafe","labelFr":"Café"}],
     "kinds":[{"id":"film","labelFr":"Film"}]}
    ''';
    final tax = PreferenceTaxonomy.parse(json);
    expect(tax.idsOf('kinds'), contains('film'));
    expect(tax.labelFor('categories', 'cafe'), 'Café');
    expect(tax.dimensions.first['id'], 'energy');
  });
}
