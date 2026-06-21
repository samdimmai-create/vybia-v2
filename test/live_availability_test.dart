import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vybia_v2/core/media/image_ref.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/reco/db/activity_repository.dart';
import 'package:vybia_v2/features/reco/db/catalog_entry.dart';
import 'package:vybia_v2/features/reco/live/live_availability_service.dart';
import 'package:vybia_v2/features/reco/live/live_cinema_provider.dart';
import 'package:vybia_v2/features/reco/live/live_events_provider.dart';
import 'package:vybia_v2/features/reco/live/live_source.dart';
import 'package:vybia_v2/features/reco/live/live_streaming_provider.dart';
import 'package:vybia_v2/features/reco/model/activity.dart';
import 'package:vybia_v2/features/reco/model/activity_kind.dart';
import 'package:vybia_v2/features/reco/model/availability.dart';
import 'package:vybia_v2/features/reco/state/reco_controller.dart';

/// S10.1B — the live availability layer: providers project a live source into our
/// schema (so the same scorer applies), every call is SAFE (timeout/offline →
/// graceful fallback, never a crash), and live + static blend in the pool.
void main() {
  HttpGet fixed(String? body) => (Uri _, {Duration timeout = Duration.zero}) async => body;

  String ckanBody(List<Map<String, Object?>> records) => jsonEncode({
        'success': true,
        'result': {'records': records},
      });

  group('LiveEventsProvider', () {
    test('projects an open-data event into a live CatalogEntry', () async {
      final body = ckanBody([
        {
          '_id': 42,
          'titre': 'Jardinage au potager urbain',
          'description': 'Un atelier pour planter et entretenir le potager.',
          'date_debut': '2026-06-21',
          'date_fin': '2026-06-21',
          'type_evenement': 'Jardinage',
          'cout': 'Gratuit',
          'arrondissement': 'Le Plateau-Mont-Royal',
          'url_fiche': 'https://montreal.ca/evenements/jardinage',
          'lat': 45.52,
          'long': -73.58,
        },
      ]);
      final p = LiveEventsProvider(httpGet: fixed(body));
      final items = await p.fetchAvailableNow(LiveQuery(when: DateTime(2026, 6, 21)));

      expect(items, hasLength(1));
      final e = items.single;
      expect(e.kind, ActivityKind.event);
      expect(e.availability, Availability.live);
      expect(e.id, 'mtlevt_42');
      expect(e.name, contains('Jardinage'));
      expect(e.startsAt, '2026-06-21');
      expect(e.lat, 45.52);
      expect(e.neighbourhood, 'Le Plateau-Mont-Royal');
      expect(e.priceTier, 0); // gratuit
      expect(e.category, ActivityCategory.nature); // jardinage → nature
      expect(e.source, 'montreal_opendata');
      // projects cleanly onto the lean scoring Activity
      final a = e.toActivity();
      expect(a.availability, Availability.live);
      expect(a.tag(Dimension.novelty), greaterThan(0.5));
    });

    test('offline / unreachable → empty, never throws', () async {
      final p = LiveEventsProvider(httpGet: fixed(null));
      expect(await p.fetchAvailableNow(LiveQuery(when: DateTime(2026, 6, 21))),
          isEmpty);
    });

    test('malformed rows are skipped, not fatal', () async {
      final body = ckanBody([
        {'titre': '', 'date_debut': '2026-06-21', 'lat': 45.5, 'long': -73.5},
        {'_id': 7, 'titre': 'Valide', 'date_debut': '2026-06-21', 'lat': 45.5, 'long': -73.5},
      ]);
      final p = LiveEventsProvider(httpGet: fixed(body));
      final items = await p.fetchAvailableNow(LiveQuery(when: DateTime(2026, 6, 21)));
      expect(items, hasLength(1));
      expect(items.single.name, 'Valide');
    });
  });

  group('keyed seams', () {
    test('TMDB streaming returns empty without a key (logged as needs-key)',
        () async {
      final p = LiveStreamingProvider(httpGet: fixed('ignored'), apiKey: '');
      expect(p.isConfigured, isFalse);
      expect(p.needsKeyNote, isNotNull);
      expect(await p.fetchAvailableNow(LiveQuery(when: DateTime.now())), isEmpty);
    });

    test('cinema showtimes stub is unconfigured and empty', () async {
      const p = LiveCinemaProvider();
      expect(p.isConfigured, isFalse);
      expect(await p.fetchAvailableNow(LiveQuery(when: DateTime.now())), isEmpty);
    });
  });

  group('LiveAvailabilityService safety', () {
    test('a slow provider times out and degrades to fallback', () async {
      final svc = LiveAvailabilityService([_SlowProvider()])
        ..perProviderTimeout = const Duration(milliseconds: 50);
      final out = await svc.fetchAvailableNow(LiveQuery(when: DateTime.now()));
      expect(out, isEmpty);
      expect(svc.statuses['slow']!.state, LiveFetchState.failed);
      expect(svc.freshKinds, isEmpty);
    });

    test('mixes ok + needs-key statuses, caches per moment', () async {
      final events = LiveEventsProvider(
        httpGet: fixed(ckanBody([
          {
            '_id': 1,
            'titre': 'Expo',
            'date_debut': '2026-06-21',
            'type_evenement': 'Exposition',
            'cout': 'Gratuit',
            'lat': 45.5,
            'long': -73.5,
          }
        ])),
      );
      final svc = LiveAvailabilityService([
        events,
        LiveStreamingProvider(httpGet: fixed('x'), apiKey: ''),
        const LiveCinemaProvider(),
      ]);
      final q = LiveQuery(when: DateTime(2026, 6, 21));
      final out = await svc.fetchAvailableNow(q);
      expect(out, hasLength(1));
      expect(svc.statuses['montreal_events']!.state, LiveFetchState.ok);
      expect(svc.statuses['tmdb_streaming']!.state, LiveFetchState.needsKey);
      expect(svc.statuses['cinema_showtimes']!.state, LiveFetchState.needsKey);
      expect(svc.freshKinds, contains(ActivityKind.event));
      // second call same moment → served from cache (no new fetch)
      identical(await svc.fetchAvailableNow(q), out);
    });
  });

  test('blend: fresh live replaces its snapshot fallback, other live kinds keep it',
      () {
    ActivityRepository.clearOverlay();
    ActivityRepository.clearLiveNow();
    CatalogEntry snap(String id, ActivityKind kind) => CatalogEntry(
          id: id,
          name: id,
          kind: kind,
          category: ActivityCategory.culture,
          descFr: 'd',
          imageRef: 'assets/images/places/museum.jpg',
          tags: const {Dimension.energy: 0.5},
          motives: (hedonic: 0.5, relaxation: 0.5, eudaimonic: 0.5),
          priceTier: 1,
          indoor: true,
          lat: kind == ActivityKind.place ? 45.5 : null,
          lng: kind == ActivityKind.place ? -73.5 : null,
        );
    ActivityRepository.ingest(jsonEncode({
      'entries': [
        snap('place1', ActivityKind.place).toJson(),
        snap('snapfilm', ActivityKind.film).toJson(), // live-kind snapshot
        snap('snapevent', ActivityKind.event).toJson(), // live-kind snapshot
      ],
    }));
    // A fresh live EVENT arrives; no fresh film.
    ActivityRepository.setLiveNow([
      snap('freshevent', ActivityKind.event).copyWith({'source': 'montreal_opendata'}),
    ]);

    final ids = liveActivityCatalog().map((a) => a.id).toSet();
    expect(ids, contains('place1')); // static always
    expect(ids, contains('freshevent')); // fresh live served
    expect(ids, contains('snapfilm')); // film had no fresh → snapshot fallback
    expect(ids, isNot(contains('snapevent'))); // event covered by fresh → no stale row
    ActivityRepository.clearLiveNow();
  });

  test('image resolver: http → network, asset path → asset', () {
    expect(imageProviderFor('https://image.tmdb.org/x.jpg'), isA<NetworkImage>());
    expect(imageProviderFor('assets/images/places/cafe.jpg'), isA<AssetImage>());
  });
}

class _SlowProvider implements LiveSourceProvider {
  @override
  String get id => 'slow';
  @override
  String get label => 'Slow';
  @override
  ActivityKind get kind => ActivityKind.event;
  @override
  bool get isConfigured => true;
  @override
  String? get needsKeyNote => null;
  @override
  Future<List<CatalogEntry>> fetchAvailableNow(LiveQuery q) =>
      Future.delayed(const Duration(seconds: 5), () => const []);
}
