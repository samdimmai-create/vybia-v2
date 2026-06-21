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

  static List<Activity>? _activitiesCache;

  static bool get isLoaded => _base.isNotEmpty || _overlay.isNotEmpty;

  /// Every record, overlay taking precedence over the bundled base.
  static List<CatalogEntry> get entries {
    final byId = <String, CatalogEntry>{};
    for (final e in _base) {
      byId[e.id] = e;
    }
    byId.addAll(_overlay);
    return byId.values.toList(growable: false);
  }

  static CatalogEntry? entryById(String id) =>
      _overlay[id] ?? _firstBaseById(id);

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

  /// Insert or replace a record in the writable overlay.
  static void upsert(CatalogEntry e) {
    _overlay[e.id] = e;
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
