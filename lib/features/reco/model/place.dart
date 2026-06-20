/// A real Montréal place, loaded from the bundled OpenStreetMap snapshot
/// (`assets/data/montreal_places.json`). Pure data — no Flutter, no network.
///
/// The snapshot is a BUILD-TIME one-off Overpass export (see
/// `scripts/`/the report), so the app reads it offline and deterministically.
library;

/// The activity-bearing place families curated from OSM tags. Each maps to an
/// engine taste profile via `placeCategoryProfile` (documented mapping table).
enum PlaceCategory {
  cafe,
  restaurant,
  bar, // amenity=bar or pub
  cinema,
  theatre,
  museum,
  gallery,
  viewpoint,
  park,
  garden,
  market, // amenity=marketplace
  sports; // leisure=sports_centre / fitness_centre

  static PlaceCategory? fromId(String? s) {
    for (final c in PlaceCategory.values) {
      if (c.name == s) return c;
    }
    return null;
  }
}

/// One real place: a stable id, a display name, a location and its category.
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.category,
    this.neighbourhood,
  });

  final String id;
  final String name;
  final double lat;
  final double lng;
  final PlaceCategory category;
  final String? neighbourhood;

  /// Parses one snapshot record, returning null for anything malformed so a
  /// single bad row can never crash the whole load.
  static Place? tryFromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final name = j['name'];
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    final cat = PlaceCategory.fromId(j['category'] as String?);
    if (id is! String || name is! String || lat == null || lng == null ||
        cat == null) {
      return null;
    }
    final hood = j['neighbourhood'];
    return Place(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      category: cat,
      neighbourhood: hood is String && hood.isNotEmpty ? hood : null,
    );
  }
}
