import '../../guest/model/dimension.dart';
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
  });

  final String id;
  final String titleFr;
  final ActivityCategory category;

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
