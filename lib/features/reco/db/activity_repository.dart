import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../../core/geo/geo.dart';
import '../../guest/model/dimension.dart';
import '../../guest/model/guest_profile.dart';
import '../../guest/model/life_context.dart';
import '../engine/reco_context.dart';
import '../model/activity.dart';
import '../model/activity_kind.dart';
import 'catalog_entry.dart';
import 'enrichment_service.dart';

/// OUR multi-source activity database, loaded from `assets/data/vybia_catalog.json`
/// (S10D). The single catalog the engine + planner read across ALL kinds
/// (place/event/film/online/travel), replacing the thin OSM-only snapshot.
///
/// Loads ONCE before first paint into an in-memory list + indexes (by id, by
/// kind), then layers a small WRITABLE OVERLAY on top (S10E) so enriched /
/// upserted records win without rewriting the bundled asset. Pure data — no
/// runtime network.
class ActivityRepository {
  ActivityRepository._();

  static const String asset = 'assets/data/vybia_catalog.json';

  static final List<CatalogEntry> _base = [];
  static final Map<String, CatalogEntry> _overlay = {}; // S10E write-back wins
  // S10.1B: fresh LIVE items fetched at runtime (events, films). Held in memory
  // ONLY — never persisted, because time-sensitive availability goes stale; a
  // relaunch re-fetches. Distinct ids (mtlevt_/tmdb_) so they never collide.
  static final Map<String, CatalogEntry> _liveNow = {};

  static List<Activity>? _activitiesCache;

  /// Persistence hook (S10E): wired by `main` to the local store so every
  /// overlay change survives a relaunch. Null in tests = in-memory only.
  static Future<void> Function(List<CatalogEntry> overlay)? persist;

  static bool get isLoaded => _base.isNotEmpty || _overlay.isNotEmpty;

  /// Every record: bundled base, then the persisted overlay, then the fresh
  /// in-memory live items (each layer winning over the previous for its id).
  static List<CatalogEntry> get entries {
    final byId = <String, CatalogEntry>{};
    for (final e in _base) {
      byId[e.id] = e;
    }
    byId.addAll(_overlay);
    byId.addAll(_liveNow);
    return byId.values.toList(growable: false);
  }

  static CatalogEntry? entryById(String id) =>
      _liveNow[id] ?? _overlay[id] ?? _firstBaseById(id);

  static CatalogEntry? _firstBaseById(String id) {
    for (final e in _base) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// The engine's lean scoring activities, projected from every record.
  static List<Activity> get activities =>
      _activitiesCache ??= entries.map((e) => e.toActivity()).toList(growable: false);

  static Activity? activityById(String id) => entryById(id)?.toActivity();

  // ---- Static / live slices (S10.1) ---------------------------------------

  /// The bundled + overlaid snapshot, WITHOUT the fresh live-now items.
  static List<CatalogEntry> get _snapshotEntries {
    final byId = <String, CatalogEntry>{};
    for (final e in _base) {
      byId[e.id] = e;
    }
    byId.addAll(_overlay);
    return byId.values.toList(growable: false);
  }

  /// The STABLE snapshot records — the recommendation pool that is always
  /// served, fully offline.
  static List<CatalogEntry> get staticEntries =>
      _snapshotEntries.where((e) => e.isStatic).toList(growable: false);

  /// The TIME-SENSITIVE snapshot records (films/events). NOT served as primary
  /// recommendations — the live layer (S10.1B) supplies fresh ones; these remain
  /// only as an offline fallback.
  static List<CatalogEntry> get liveEntries =>
      _snapshotEntries.where((e) => e.isLive).toList(growable: false);

  /// Scoring activities for the static pool — what the engine ranks by default.
  static List<Activity> get staticActivities =>
      staticEntries.map((e) => e.toActivity()).toList(growable: false);

  /// Scoring activities for the live-kind snapshot rows, used ONLY as a graceful
  /// fallback when no live source is reachable (S10.1B).
  static List<Activity> get liveFallbackActivities =>
      liveEntries.map((e) => e.toActivity()).toList(growable: false);

  // ---- Fresh live-now items (S10.1B) --------------------------------------

  /// Replace the in-memory live-now set with freshly fetched items (never
  /// persisted). Clears the activities cache so the next rank sees them.
  static void setLiveNow(Iterable<CatalogEntry> items) {
    _liveNow
      ..clear()
      ..addEntries(items.map((e) => MapEntry(e.id, e)));
    _activitiesCache = null;
  }

  static void clearLiveNow() {
    if (_liveNow.isEmpty) return;
    _liveNow.clear();
    _activitiesCache = null;
  }

  static List<CatalogEntry> get liveNowEntries =>
      _liveNow.values.toList(growable: false);

  /// The kinds that currently have at least one fresh live item.
  static Set<ActivityKind> get liveNowKinds =>
      _liveNow.values.map((e) => e.kind).toSet();

  // ---- Loading -------------------------------------------------------------

  /// Parse + index the JSON (tolerant: a malformed row is skipped). Safe to call
  /// more than once.
  static void ingest(String jsonStr) {
    final data = jsonDecode(jsonStr);
    if (data is! Map<String, dynamic>) return;
    final rows = data['entries'];
    if (rows is! List) return;
    _base.clear();
    for (final row in rows) {
      if (row is Map<String, dynamic>) {
        final e = CatalogEntry.tryFromJson(row);
        if (e != null) _base.add(e);
      }
    }
    _activitiesCache = null;
  }

  /// Load the bundled catalog asset. Call once before first paint.
  static Future<void> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(asset);
    ingest(raw);
  }

  // ---- Write path (S10E) ---------------------------------------------------

  /// Insert or replace a record in the writable overlay + persist (if wired).
  static Future<void> upsert(CatalogEntry e) async {
    _overlay[e.id] = e;
    _activitiesCache = null;
    await persist?.call(overlayEntries);
  }

  /// Read a record (base or overlay), apply [patch] with provenance, write the
  /// merged record to the overlay and persist it. Returns the new record, or
  /// null if [id] is unknown / the patch is empty. This is the single write-back
  /// entry point an enrichment provider (stub today, Claude tomorrow) calls.
  static Future<CatalogEntry?> enrichActivity(
    String id,
    Map<String, dynamic> patch, {
    String source = 'claude',
    String? enrichedAt,
  }) async {
    if (patch.isEmpty) return entryById(id);
    final current = entryById(id);
    if (current == null) return null;
    final merged = current.copyWith({
      ...patch,
      'source': source,
      'enrichedAt': enrichedAt ?? DateTime.now().toIso8601String(),
    });
    await upsert(merged);
    return merged;
  }

  /// read → propose → enrich → save, end to end. The same call works unchanged
  /// when the stub is swapped for a Claude-backed [EnrichmentService].
  static Future<CatalogEntry?> enrichWith(
    EnrichmentService service,
    String id,
  ) async {
    final current = entryById(id);
    if (current == null) return null;
    final patch = await service.proposeEnrichment(current);
    if (patch.isEmpty) return current;
    return enrichActivity(id, patch, source: 'claude');
  }

  /// Hydrate the overlay from persisted records (call once at startup, after
  /// [load], BEFORE first paint). Does not re-persist.
  static void hydrateOverlay(Iterable<CatalogEntry> saved) {
    for (final e in saved) {
      _overlay[e.id] = e;
    }
    _activitiesCache = null;
  }

  /// Drop the overlay (tests / "reset").
  static void clearOverlay() {
    _overlay.clear();
    _activitiesCache = null;
  }

  /// The overlay snapshot, for persistence.
  static List<CatalogEntry> get overlayEntries =>
      _overlay.values.toList(growable: false);

  // ---- Queries (fast, in-memory) ------------------------------------------

  static List<CatalogEntry> byKind(ActivityKind kind) =>
      entries.where((e) => e.kind == kind).toList(growable: false);

  static List<CatalogEntry> byCategory(ActivityCategory cat) =>
      entries.where((e) => e.category == cat).toList(growable: false);

  /// Records feasible under EVERY active life-context flag (uses the explicit
  /// flags this DB carries; see also the engine's runtime feasibility).
  static List<CatalogEntry> feasibleFor(
    Set<LifeContext> contexts, {
    double? userLat,
    double? userLng,
    double maxKm = 25,
  }) {
    return entries.where((e) {
      for (final c in contexts) {
        if (!_flagOk(c, e, userLat, userLng)) return false;
      }
      return true;
    }).toList(growable: false);
  }

  static bool _flagOk(LifeContext c, CatalogEntry e, double? lat, double? lng) {
    switch (c) {
      case LifeContext.avecEnfants:
        return e.kidFriendly != false;
      case LifeContext.sansAlcool:
        return e.servesAlcohol != true;
      case LifeContext.budgetSerre:
        return e.priceTier < 3;
      case LifeContext.mobiliteReduite:
        if (e.wheelchairAccessible == false) return false;
        if (e.effortLevel > 0.6) return false;
        return true;
      case LifeContext.sansVoiture:
        if (!e.hasLocation || lat == null || lng == null) return true;
        return haversineKm(lat, lng, e.lat!, e.lng!) <= 6;
      case LifeContext.avecAnimal:
        if (!e.indoor) return true;
        return e.petFriendly != false;
    }
  }

  // -------------------------------------------------------------------------
  // LLM-ready seam: queryForContext
  // -------------------------------------------------------------------------

  /// The compact candidate slice for the current moment — the EXACT shape a
  /// future Claude enrichment/curation call will receive (S10D). Deterministic,
  /// on-device, no network: filter by feasibility + (optional) kind + time/season,
  /// rank by a light taste affinity, and return the small relevant set as
  /// prompt-friendly [CatalogEntry.llmSlice] maps plus a context header.
  static CandidateSlice queryForContext(
    GuestProfile profile, {
    Set<LifeContext> contexts = const {},
    RecoContext? context,
    ActivityKind? kind,
    int limit = 8,
  }) {
    final ctx = context ?? RecoContext.now();
    var pool = feasibleFor(
      contexts,
      userLat: ctx.userLat,
      userLng: ctx.userLng,
    );
    if (kind != null) pool = pool.where((e) => e.kind == kind).toList();

    // Light, transparent taste affinity over the eight axes.
    double affinity(CatalogEntry e) {
      var sum = 0.0;
      for (final d in Dimension.values) {
        if (d == Dimension.mood) continue;
        sum += 1 - (profile.valueOf(d) - e.tag(d)).abs();
      }
      // small recency/timing nudge
      final timeFit = 1 - (e.tag(Dimension.timing) - ctx.eveningness).abs();
      return sum + 0.5 * timeFit;
    }

    final ranked = pool.toList()
      ..sort((a, b) => affinity(b).compareTo(affinity(a)));
    final picked = ranked.take(limit).toList();

    return CandidateSlice(
      context: {
        'mood': profile.valueOf(Dimension.mood),
        'profile': {
          for (final d in Dimension.values)
            if (d != Dimension.mood) d.name: profile.valueOf(d),
        },
        'contexts': contexts.map((c) => c.name).toList(),
        'location': ctx.hasUser ? {'lat': ctx.userLat, 'lng': ctx.userLng} : null,
        'hour': ctx.hourOfDay,
        'month': ctx.month,
        if (kind != null) 'kind': kind.name,
      },
      candidates: picked.map((e) => e.llmSlice()).toList(growable: false),
      candidateIds: picked.map((e) => e.id).toList(growable: false),
    );
  }
}

/// The compact context + candidate slice handed to a future LLM curation call.
class CandidateSlice {
  const CandidateSlice({
    required this.context,
    required this.candidates,
    required this.candidateIds,
  });

  /// The moment: mood, profile axes, active life-contexts, location, clock.
  final Map<String, dynamic> context;

  /// The small relevant set as prompt-friendly slices.
  final List<Map<String, dynamic>> candidates;

  /// The ids of the candidates (to map a model's pick back to a record).
  final List<String> candidateIds;

  Map<String, dynamic> toJson() => {
        'context': context,
        'candidates': candidates,
      };
}
