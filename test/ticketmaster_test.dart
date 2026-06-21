import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/reco/db/catalog_entry.dart';
import 'package:vybia_v2/features/reco/live/live_availability_service.dart';
import 'package:vybia_v2/features/reco/live/live_source.dart';
import 'package:vybia_v2/features/reco/live/live_ticketmaster_provider.dart';
import 'package:vybia_v2/features/reco/model/activity.dart';
import 'package:vybia_v2/features/reco/model/activity_kind.dart';
import 'package:vybia_v2/features/reco/model/availability.dart';

/// S12D — Ticketmaster Discovery (keyed): projects real dated events into our
/// schema for the SAME scorer, stays dormant + "needs key" without a key, and
/// blends/dedupes with the keyless Montréal open-data events.
void main() {
  HttpGet fixed(String? body) =>
      (Uri _, {Duration timeout = Duration.zero}) async => body;

  String tmBody(List<Map<String, Object?>> events) => jsonEncode({
        '_embedded': {'events': events},
      });

  Map<String, Object?> concert(String id, String name) => {
        'id': id,
        'name': name,
        'url': 'https://ticketmaster.ca/$id',
        'images': [
          {'url': 'https://tm.example/$id.jpg', 'width': 1024},
        ],
        'dates': {
          'start': {'dateTime': '2026-07-01T23:00:00Z', 'localDate': '2026-07-01'},
        },
        'classifications': [
          {'segment': {'name': 'Music'}},
        ],
        '_embedded': {
          'venues': [
            {
              'name': 'MTELUS',
              'city': {'name': 'Montréal'},
              'location': {'latitude': '45.5088', 'longitude': '-73.5660'},
            },
          ],
        },
      };

  group('LiveTicketmasterProvider', () {
    test('without a key → unconfigured, empty, needs-key (standby)', () async {
      final p = LiveTicketmasterProvider(httpGet: fixed('ignored'), apiKey: '');
      expect(p.isConfigured, isFalse);
      expect(p.needsKeyNote, isNotNull);
      expect(await p.fetchAvailableNow(LiveQuery(when: DateTime.now())), isEmpty);
    });

    test('projects a Discovery event into a live CatalogEntry', () async {
      final p = LiveTicketmasterProvider(
        httpGet: fixed(tmBody([concert('A1', 'Arcade Fire')])),
        apiKey: 'KEY',
      );
      final items =
          await p.fetchAvailableNow(LiveQuery(when: DateTime(2026, 6, 21), limit: 6));
      expect(items, hasLength(1));
      final e = items.single;
      expect(e.kind, ActivityKind.event);
      expect(e.availability, Availability.live);
      expect(e.id, 'tm_A1');
      expect(e.name, 'Arcade Fire');
      expect(e.startsAt, '2026-07-01T23:00:00Z');
      expect(e.lat, 45.5088);
      expect(e.neighbourhood, 'Montréal');
      expect(e.source, 'ticketmaster');
      expect(e.imageRef, 'https://tm.example/A1.jpg');
      expect(e.url, 'https://ticketmaster.ca/A1');
      // projects cleanly onto the lean scoring Activity
      final a = e.toActivity();
      expect(a.availability, Availability.live);
      expect(a.tag(Dimension.timing), greaterThan(0.5));
    });

    test('offline / unreachable → empty, never throws', () async {
      final p = LiveTicketmasterProvider(httpGet: fixed(null), apiKey: 'KEY');
      expect(
          await p.fetchAvailableNow(LiveQuery(when: DateTime.now())), isEmpty);
    });
  });

  test('service blends Ticketmaster with open-data and dedupes same-title events',
      () async {
    // A Montréal open-data event AND a Ticketmaster event with the SAME title:
    // only one survives (open-data first → wins).
    final openData = _FakeEvents([
      CatalogEntry(
        id: 'mtl_1',
        name: 'Festival de Jazz',
        kind: ActivityKind.event,
        category: ActivityCategory.culture,
        descFr: 'd',
        imageRef: 'assets/images/places/theatre.jpg',
        tags: const {Dimension.energy: 0.5},
        motives: (hedonic: 0.5, relaxation: 0.5, eudaimonic: 0.5),
        priceTier: 0,
        indoor: true,
        availability: Availability.live,
        source: 'montreal_opendata',
      ),
    ]);
    final tm = LiveTicketmasterProvider(
      httpGet: fixed(tmBody([
        concert('TM1', 'Festival de Jazz'), // duplicate title
        concert('TM2', 'Metric'), // unique
      ])),
      apiKey: 'KEY',
    );
    final svc = LiveAvailabilityService([openData, tm]);
    final out = await svc.fetchAvailableNow(LiveQuery(when: DateTime(2026, 6, 21)));

    final names = out.map((e) => e.name).toList();
    expect(names, contains('Festival de Jazz'));
    expect(names, contains('Metric'));
    expect(names.where((n) => n == 'Festival de Jazz'), hasLength(1),
        reason: 'duplicate event title deduped across providers');
    // The survivor is the open-data one (first provider wins).
    final jazz = out.firstWhere((e) => e.name == 'Festival de Jazz');
    expect(jazz.source, 'montreal_opendata');
  });
}

/// A trivial in-memory provider standing in for the keyless open-data events.
class _FakeEvents implements LiveSourceProvider {
  _FakeEvents(this._items);
  final List<CatalogEntry> _items;
  @override
  String get id => 'montreal_events';
  @override
  String get label => 'Open data';
  @override
  ActivityKind get kind => ActivityKind.event;
  @override
  bool get isConfigured => true;
  @override
  String? get needsKeyNote => null;
  @override
  Future<List<CatalogEntry>> fetchAvailableNow(LiveQuery q) async => _items;
}
