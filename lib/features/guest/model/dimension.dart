/// The preference dimensions the adaptive engine reasons over.
///
/// [mood] is captured first (the Welcome scene asks "Comment veux-tu te
/// sentir ?"); the remaining eight are the classic activity-fit axes the engine
/// probes adaptively, picking whichever is currently least certain.
enum Dimension {
  mood,
  energy,
  social,
  novelty,
  distance,
  indoor, // indoor (1.0) ↔ outdoor (0.0)
  timing,
  budget,
  vibe;

  /// Short French label, used in the "profil prêt" recap.
  String get labelFr {
    switch (this) {
      case Dimension.mood:
        return 'Humeur';
      case Dimension.energy:
        return 'Énergie';
      case Dimension.social:
        return 'Social';
      case Dimension.novelty:
        return 'Nouveauté';
      case Dimension.distance:
        return 'Distance';
      case Dimension.indoor:
        return 'Cadre';
      case Dimension.timing:
        return 'Moment';
      case Dimension.budget:
        return 'Budget';
      case Dimension.vibe:
        return 'Ambiance';
    }
  }
}
