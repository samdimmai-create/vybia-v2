/// The transparent, per-term breakdown of one activity's score (S11B).
///
/// Each field is the activity's already-WEIGHTED contribution from one term of
/// the research-grounded blend (so they sum, minus the penalty, to [total]).
/// Keeping the breakdown — rather than only the final number — is what makes the
/// engine honestly explainable: the "pourquoi" (S11D) is built from whichever
/// terms actually carried this pick, and the unit tests can assert that each
/// term moves the ranking the way its principle says it should.
class ScoreBreakdown {
  const ScoreBreakdown({
    required this.pref,
    required this.motive,
    required this.affect,
    required this.context,
    required this.social,
    required this.novelty,
    required this.happiness,
    required this.proximity,
    required this.repeatPenalty,
  });

  /// Confidence-weighted, revealed-corrected taste match (w_pref).
  final double pref;

  /// Beard & Ragheb LMS motive match (w_motive).
  final double motive;

  /// Hedonic↔eudaimonic mood/motive fit (w_affect) — S11.
  final double affect;

  /// Time-of-day / season context fit (w_context).
  final double context;

  /// Social-axis fit (w_social).
  final double social;

  /// Novelty hedonic boost, scaled to the person (w_novelty).
  final double novelty;

  /// Happiness-raising-trait fit (w_happiness) — S11.
  final double happiness;

  /// Proximity reward for nearer real places (w_proximity).
  final double proximity;

  /// Anti-repetition penalty (subtracted).
  final double repeatPenalty;

  double get total =>
      pref +
      motive +
      affect +
      context +
      social +
      novelty +
      happiness +
      proximity -
      repeatPenalty;

  /// The positive terms keyed by a stable id, largest first — the basis for the
  /// explainable "pourquoi" factor list (S11D).
  List<({String key, double value})> get rankedTerms {
    final terms = <({String key, double value})>[
      (key: 'pref', value: pref),
      (key: 'motive', value: motive),
      (key: 'affect', value: affect),
      (key: 'context', value: context),
      (key: 'social', value: social),
      (key: 'novelty', value: novelty),
      (key: 'happiness', value: happiness),
      (key: 'proximity', value: proximity),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return terms;
  }
}
