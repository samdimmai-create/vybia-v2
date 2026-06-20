import '../../guest/model/dimension.dart';
import 'activity.dart';

/// One scored, explained recommendation produced by the engine.
class Recommendation {
  const Recommendation({
    required this.activity,
    required this.score,
    required this.isBestPick,
    required this.why,
    required this.topDimensions,
    this.distanceKm,
    this.imageOverride,
  });

  final Activity activity;

  /// S9F: the engine's smart, vibe-aware image pick for this recommendation.
  /// Falls back to the activity's own bundled image when not set.
  final String? imageOverride;

  /// The image to show — the engine's vibe-aware pick, else the activity's own.
  String get image => imageOverride ?? activity.image;

  /// Real haversine distance (km) from the guest to this place, or null when the
  /// location is unknown (S7C).
  final double? distanceKm;

  /// Final blended score (roughly 0..1, higher is better).
  final double score;

  /// True only for the single best-ranked recommendation in a batch.
  final bool isBestPick;

  /// One-line French "pourquoi ça te va", generated from the matched axes.
  final String why;

  /// The dimensions that contributed most to the match (for the detail view).
  final List<Dimension> topDimensions;
}
