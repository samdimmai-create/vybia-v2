import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../model/activity.dart';
import '../model/place.dart';
import 'place_category_mapping.dart';

/// Loads the bundled OpenStreetMap Montréal snapshot
/// (`assets/data/montreal_places.json`) ONCE at startup and exposes the real
/// places plus the engine [Activity] list built from them via the documented
/// category→dimension mapping. No runtime network — the asset is a build-time
/// Overpass export, so this is offline, deterministic and free.
///
/// A process-wide singleton: `main()` calls [load] before first paint, then the
/// reco loop, the planner and persistence all read the same in-memory catalog.
class OsmPlaceRepository {
  OsmPlaceRepository._();

  static const String asset = 'assets/data/montreal_places.json';

  static List<Place> _places = const [];
  static List<Activity> _activities = const [];
  static final Map<String, Activity> _byId = {};

  /// All real places from the snapshot.
  static List<Place> get places => _places;

  /// Engine activities backed by real places (best fed to [RecommendationEngine]).
  static List<Activity> get activities => _activities;

  /// True once the snapshot has been parsed into at least one activity.
  static bool get isLoaded => _activities.isNotEmpty;

  /// Look up an OSM-backed activity by its place id (for plan restore / detail).
  static Activity? activityById(String id) => _byId[id];

  /// Parse the snapshot JSON into places + activities. Tolerant: a malformed
  /// row is skipped, never fatal. Safe to call more than once (idempotent).
  static void ingest(String jsonStr) {
    final data = jsonDecode(jsonStr);
    if (data is! Map<String, dynamic>) return;
    final rows = data['places'];
    if (rows is! List) return;
    final places = <Place>[];
    for (final row in rows) {
      if (row is Map<String, dynamic>) {
        final p = Place.tryFromJson(row);
        if (p != null) places.add(p);
      }
    }
    _places = places;
    _activities = places.map(activityFromPlace).toList(growable: false);
    _byId
      ..clear()
      ..addEntries(_activities.map((a) => MapEntry(a.id, a)));
  }

  /// Load + parse the bundled asset. Call once before first paint.
  static Future<void> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(asset);
    ingest(raw);
  }
}
