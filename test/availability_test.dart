import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/reco/db/activity_repository.dart';
import 'package:vybia_v2/features/reco/db/catalog_entry.dart';
import 'package:vybia_v2/features/reco/model/activity.dart';
import 'package:vybia_v2/features/reco/model/activity_kind.dart';
import 'package:vybia_v2/features/reco/model/availability.dart';

/// S10.1A — the static/live availability model: stable kinds snapshot, films and
/// events are LIVE, the split is byte-stable on disk, and the repository slices
/// the catalog so the live kinds are out of the static recommendation pool while
/// surviving as an offline fallback.
void main() {
  CatalogEntry entry(
    String id,
    ActivityKind kind, {
    Availability? availability,
  }) {
    return CatalogEntry(
      id: id,
      name: 'Entry $id',
      kind: kind,
      category: ActivityCategory.culture,
      descFr: 'desc',
      imageRef: 'assets/images/places/museum.jpg',
      tags: const {Dimension.energy: 0.5},
      motives: (hedonic: 0.5, relaxation: 0.5, eudaimonic: 0.5),
      priceTier: 1,
      indoor: true,
      availability: availability,
    );
  }

  test('availability defaults follow the kind', () {
    expect(Availability.ofKind(ActivityKind.place), Availability.fixed);
    expect(Availability.ofKind(ActivityKind.travel), Availability.fixed);
    expect(Availability.ofKind(ActivityKind.online), Availability.fixed);
    expect(Availability.ofKind(ActivityKind.event), Availability.live);
    expect(Availability.ofKind(ActivityKind.film), Availability.live);

    expect(entry('p', ActivityKind.place).isStatic, isTrue);
    expect(entry('f', ActivityKind.film).isLive, isTrue);
    expect(entry('e', ActivityKind.event).isLive, isTrue);
  });

  test('availability projects onto the lean Activity', () {
    expect(entry('p', ActivityKind.place).toActivity().availability,
        Availability.fixed);
    expect(entry('f', ActivityKind.film).toActivity().availability,
        Availability.live);
  });

  test('JSON stays byte-stable for kind-default rows, persists overrides', () {
    // A film at its kind default omits the field entirely (no migration churn).
    final film = entry('f', ActivityKind.film);
    expect(film.toJson().containsKey('availability'), isFalse);

    // An override (an evergreen "film night" pinned static) is persisted…
    final pinned = entry('f2', ActivityKind.film, availability: Availability.fixed);
    expect(pinned.toJson()['availability'], 'static');

    // …and round-trips losslessly.
    final restored =
        CatalogEntry.tryFromJson(jsonDecode(jsonEncode(pinned.toJson())));
    expect(restored!.availability, Availability.fixed);
    expect(restored.isStatic, isTrue);
  });

  test('absent field parses to the kind default; explicit field wins', () {
    expect(
      Availability.fromJson(null, ActivityKind.film),
      Availability.live,
    );
    expect(
      Availability.fromJson('static', ActivityKind.film),
      Availability.fixed,
    );
    expect(
      Availability.fromJson('live', ActivityKind.place),
      Availability.live,
    );
  });

  test('repository slices keep live kinds out of the static pool', () {
    ActivityRepository.clearOverlay();
    ActivityRepository.ingest(jsonEncode({
      'schema': 'vybia.catalog.v1',
      'entries': [
        entry('p1', ActivityKind.place).toJson(),
        entry('p2', ActivityKind.place).toJson(),
        entry('t1', ActivityKind.travel).toJson(),
        entry('o1', ActivityKind.online).toJson(),
        entry('f1', ActivityKind.film).toJson(),
        entry('e1', ActivityKind.event).toJson(),
      ],
    }));

    final staticIds = ActivityRepository.staticEntries.map((e) => e.id).toSet();
    final liveIds = ActivityRepository.liveEntries.map((e) => e.id).toSet();

    expect(staticIds, {'p1', 'p2', 't1', 'o1'});
    expect(liveIds, {'f1', 'e1'});

    // No live kind leaks into the static recommendation pool.
    expect(
      ActivityRepository.staticActivities.every((a) => a.availability == Availability.fixed),
      isTrue,
    );
    // The live-kind rows survive as a fallback set.
    expect(ActivityRepository.liveFallbackActivities.length, 2);
  });
}
