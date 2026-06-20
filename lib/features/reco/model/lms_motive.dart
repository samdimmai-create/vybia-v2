/// The four leisure-motivation components of the **Beard & Ragheb Leisure
/// Motivation Scale** (1983) — the well-established taxonomy of *why* people
/// reach for leisure. The engine reasons over all four (S9C):
///
///  * [intellectual]      — learning, exploring, discovering, imagining, creating.
///  * [social]            — friendship, belonging, interpersonal connection, esteem.
///  * [competence]        — competence-mastery: achieve, challenge, master, improve.
///  * [stimulusAvoidance] — escape, unwind, rest, solitude, decompress.
///
/// Each [activity] has an affinity (0..1) per component; the guest has normalized
/// *weights* (the four sum to ~1) derived from their latent profile + mood. The
/// engine matches the two (see `leisure_motivation.dart`).
enum LmsMotive {
  intellectual,
  social,
  competence,
  stimulusAvoidance;

  String get labelFr {
    switch (this) {
      case LmsMotive.intellectual:
        return 'Découvrir';
      case LmsMotive.social:
        return 'Partager';
      case LmsMotive.competence:
        return 'Se dépasser';
      case LmsMotive.stimulusAvoidance:
        return 'Décompresser';
    }
  }
}

/// A guest's normalized pull toward each LMS component (the four sum to ~1).
typedef LmsWeights = ({
  double intellectual,
  double social,
  double competence,
  double stimulusAvoidance,
});

/// An activity's affinity to each LMS component (independent 0..1 values).
typedef LmsAffinity = ({
  double intellectual,
  double social,
  double competence,
  double stimulusAvoidance,
});
