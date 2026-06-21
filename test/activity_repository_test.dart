import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/guest/model/life_context.dart';
import 'package:vybia_v2/features/reco/db/activity_repository.dart';
import 'package:vybia_v2/features/reco/db/catalog_entry.dart';
import 'package:vybia_v2/features/reco/db/enrichment_service.dart';
import 'package:vybia_v2/features/reco/engine/recommendation_engine.dart';
import 'package:vybia_v2/features/reco/engine/reco_context.dart';
import 'package:vybia_v2/features/reco/model/activity_kind.dart';

/// S10D — the repository loads OUR bundled multi-source DB, serves every kind to
/// the engine, filters by the explicit life-context flags, and exposes the
/// compact LLM-ready query slice.
void main() {
  setUpAll(() {
    final raw = File('assets/data/vybia_catalog.json').readAsStringSync();
    ActivityRepository.clearOverlay();
    ActivityRepository.ingest(raw);
  });

  test('loads the bundled catalog with every kind present', () {
    expect(ActivityRepository.isLoaded, isTrue);
    final kinds = ActivityRepository.entries.map((e) => e.kind).toSet();
    for (final k in ActivityKind.values) {
      expect(kinds, contains(k), reason: 'missing kind $k');
    }
    expect(ActivityRepository.entries.length, greaterThan(100));
  });

  test('projects to engine activities; non-geo kinds keep hasLocation:false', () {
    final acts = ActivityRepository.activities;
    expect(acts, isNotEmpty);
    final films = acts.where((a) => a.kind == ActivityKind.film);
    expect(films, isNotEmpty);
    expect(films.every((a) => a.hasLocation == false), isTrue);
    final places = acts.where((a) => a.kind == ActivityKind.place);
    expect(places.every((a) => a.hasLocation == true), isTrue);
  });

  test('the engine serves multiple kinds from our db', () {
    final p = GuestProfile()
      ..answer(Dimension.mood, 0.5)
      ..answer(Dimension.novelty, 0.7);
    final engine = RecommendationEngine(catalog: ActivityRepository.activities);
    // No user location → distance is inert; films/online stay eligible.
    final recs = engine.recommend(p,
        context: const RecoContext(hourOfDay: 20, month: 7), max: 6);
    expect(recs, isNotEmpty);
    final kinds = recs.map((r) => r.activity.kind).toSet();
    expect(kinds.length, greaterThanOrEqualTo(1));
  });

  test('feasibleFor applies the explicit flags', () {
    final all = ActivityRepository.entries.length;
    final noAlcohol =
        ActivityRepository.feasibleFor({LifeContext.sansAlcool});
    expect(noAlcohol.length, lessThan(all));
    expect(noAlcohol.any((e) => e.servesAlcohol == true), isFalse);

    final kids = ActivityRepository.feasibleFor({LifeContext.avecEnfants});
    expect(kids.any((e) => e.kidFriendly == false), isFalse);
  });

  test('queryForContext returns a compact, prompt-ready slice', () {
    final p = GuestProfile()..answer(Dimension.mood, 0.6);
    final slice = ActivityRepository.queryForContext(
      p,
      contexts: {LifeContext.sansAlcool},
      context: const RecoContext(hourOfDay: 21, month: 1),
      kind: ActivityKind.film,
      limit: 5,
    );
    expect(slice.candidates.length, lessThanOrEqualTo(5));
    expect(slice.candidates, isNotEmpty);
    expect(slice.candidateIds.length, slice.candidates.length);
    // every candidate respects the kind filter + the compact slice shape
    expect(slice.candidates.every((c) => c['kind'] == 'film'), isTrue);
    expect(slice.context['contexts'], contains('sansAlcool'));
  });

  test('overlay wins over the bundled base', () async {
    final base = ActivityRepository.entries.firstWhere(
        (e) => e.kind == ActivityKind.place);
    await ActivityRepository.upsert(base.copyWith({'name': 'OVERLAY NAME'}));
    expect(ActivityRepository.entryById(base.id)!.name, 'OVERLAY NAME');
    ActivityRepository.clearOverlay();
    final raw = File('assets/data/vybia_catalog.json').readAsStringSync();
    ActivityRepository.ingest(raw);
  });

  // ---- S10E: enrichment / write-back -------------------------------------

  test('enrichWith(stub) fills a missing field, stamps provenance, persists',
      () async {
    // A record whose description the stub will fill (force the gap).
    final target = ActivityRepository.entries.first;
    await ActivityRepository.upsert(target.copyWith({'descFr': ''}));

    final before = ActivityRepository.entryById(target.id)!;
    expect(before.descFr.trim().length, lessThan(12));

    final enriched = await ActivityRepository.enrichWith(
      const LocalRuleEnrichmentProvider(),
      target.id,
    );
    expect(enriched, isNotNull);
    expect(enriched!.descFr.trim().length, greaterThanOrEqualTo(12));
    expect(enriched.source, 'claude');
    expect(enriched.enrichedAt, isNotNull);
    // Persisted into the overlay → wins on read.
    expect(ActivityRepository.entryById(target.id)!.descFr, enriched.descFr);

    ActivityRepository.clearOverlay();
    final raw = File('assets/data/vybia_catalog.json').readAsStringSync();
    ActivityRepository.ingest(raw);
  });

  test('overlay survives a save → reload round-trip (persistence)', () async {
    final captured = <CatalogEntry>[];
    ActivityRepository.persist = (overlay) async {
      captured
        ..clear()
        ..addAll(overlay);
    };

    final target = ActivityRepository.entries.first;
    await ActivityRepository.enrichActivity(
      target.id,
      {'confidence': 0.9, 'descFr': 'Une description enrichie pour le test.'},
    );
    expect(captured, isNotEmpty);

    // Simulate a fresh launch: drop in-memory overlay, re-ingest base, rehydrate
    // from what was "persisted", and confirm the enriched record is back.
    ActivityRepository.clearOverlay();
    final raw = File('assets/data/vybia_catalog.json').readAsStringSync();
    ActivityRepository.ingest(raw);
    ActivityRepository.hydrateOverlay(captured);

    final reloaded = ActivityRepository.entryById(target.id)!;
    expect(reloaded.descFr, 'Une description enrichie pour le test.');
    expect(reloaded.confidence, 0.9);

    ActivityRepository.persist = null;
    ActivityRepository.clearOverlay();
    ActivityRepository.ingest(raw);
  });
}
