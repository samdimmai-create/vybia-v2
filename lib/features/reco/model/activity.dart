import '../../guest/model/dimension.dart';
import 'activity_kind.dart';
import 'motive.dart';

/// Broad activity families — used for light diversification and labelling.
enum ActivityCategory {
  cafe,
  nature,
  culture,
  nightlife,
  food,
  wellness,
  active,
  creative;

  String get labelFr {
    switch (this) {
      case ActivityCategory.cafe:
        return 'Café';
      case ActivityCategory.nature:
        return 'Nature';
      case ActivityCategory.culture:
        return 'Culture';
      case ActivityCategory.nightlife:
        return 'Soirée';
      case ActivityCategory.food:
        return 'Gourmand';
      case ActivityCategory.wellness:
        return 'Bien-être';
      case ActivityCategory.active:
        return 'Actif';
      case ActivityCategory.creative:
        return 'Créatif';
    }
  }
}

/// One concrete Montréal activity the engine can recommend.
///
/// [tags] positions the activity on the same eight taste axes the guest profile
/// uses (excluding [Dimension.mood], which is captured separately and folded
/// into the motive weights). Each axis value is 0..1 with the same polarity as
/// the profile, so a match is simply `1 - |profile − activity|`.
class Activity {
  const Activity({
    required this.id,
    required this.titleFr,
    required this.category,
    required this.tags,
    required this.motives,
    required this.budget,
    required this.indoor,
    required this.descFr,
    required this.lat,
    required this.lng,
    required this.image,
    this.winterFriendly = true,
    this.kind = ActivityKind.place,
    this.hasLocation = true,
    this.kidFriendly,
    this.servesAlcohol,
    this.wheelchairAccessible,
    this.petFriendly,
    this.effortLevel = 0.4,
    this.source = 'seed',
  });

  final String id;
  final String titleFr;
  final ActivityCategory category;

  /// What sort of thing this is (S10). `place` for everything pre-S10; the new
  /// multi-source catalog also carries `event | film | online | travel`. Drives
  /// which kind-specific facts the detail/why surface should show.
  final ActivityKind kind;

  /// Whether [lat]/[lng] are a real, on-the-map position (S10). `false` for
  /// films, streaming and other at-home/online kinds, which have no geography —
  /// the engine then skips the distance filter and proximity reward for them
  /// instead of treating a placeholder coordinate as "right here".
  final bool hasLocation;

  // ---- Explicit life-context flags (S10) ----------------------------------
  // When non-null these drive feasibility directly; when null the engine falls
  // back to category inference (the pre-S10 behaviour), so seed entries that
  // never set them keep working unchanged.

  /// Safe / welcoming with children in tow.
  final bool? kidFriendly;

  /// Alcohol is central (a bar/club) — excluded for `sansAlcool`.
  final bool? servesAlcohol;

  /// Step-free / wheelchair accessible.
  final bool? wheelchairAccessible;

  /// Dogs/pets are welcome.
  final bool? petFriendly;

  /// Physical effort required, 0 effortless … 1 strenuous (a hike, a climb).
  /// Drives the `mobiliteReduite` filter alongside category.
  final double effortLevel;

  /// Where this entry came from (provenance): `seed`, `osm`, `wikidata`,
  /// `wikivoyage`, `tmdb`, `claude`… Mirrors the catalog record's source.
  final String source;

  /// Position on the eight activity-fit axes (see [Dimension]). Polarity matches
  /// the profile, e.g. `Dimension.indoor` → 1 indoor / 0 outdoor.
  final Map<Dimension, double> tags;

  final MotiveAffinity motives;

  /// 0 = free, 1 = cheap, 2 = mid, 3 = splurge.
  final int budget;

  final bool indoor;

  /// `false` for activities that don't make sense in a Montréal winter
  /// (open water, cycling, gardens) — softly penalized Dec–Feb.
  final bool winterFriendly;

  final String descFr;
  final double lat;
  final double lng;

  /// Bundled full-bleed asset (always shown under the universal bubble).
  final String image;

  double tag(Dimension d) => tags[d] ?? 0.5;
}
