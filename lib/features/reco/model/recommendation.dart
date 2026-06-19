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
  });

  final Activity activity;

  /// Final blended score (roughly 0..1, higher is better).
  final double score;

  /// True only for the single best-ranked recommendation in a batch.
  final bool isBestPick;

  /// One-line French "pourquoi ça te va", generated from the matched axes.
  final String why;

  /// The dimensions that contributed most to the match (for the detail view).
  final List<Dimension> topDimensions;
}
