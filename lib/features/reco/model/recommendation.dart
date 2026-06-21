import '../../guest/model/dimension.dart';
import '../engine/score_breakdown.dart';
import 'activity.dart';

/// One scored, explained recommendation produced by the engine.
class Recommendation {
  const Recommendation({
    required this.activity,
    required this.score,
    required this.isBestPick,
    required this.why,
    required this.topDimensions,
    this.breakdown,
    this.factors = const [],
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

  /// S11B: the transparent per-term score breakdown behind this pick. Drives the
  /// honest, factor-level "pourquoi" (S11D) and the explainability tests.
  final ScoreBreakdown? breakdown;

  /// S11D: the top contributing factors as short French chips
  /// (e.g. "motif : évasion", "tout près", "nouveau pour toi") — the
  /// deterministic, specific "pourquoi" exposed BEFORE any LLM. Also the
  /// LLM-ready explanation seam.
  final List<String> factors;
}
