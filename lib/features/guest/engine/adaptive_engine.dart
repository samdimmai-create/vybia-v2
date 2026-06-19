import '../model/guest_profile.dart';
import '../model/question.dart';

/// Deterministic, on-device adaptive question picker (no LLM).
///
/// Strategy — pure information-greedy:
///   * Never re-ask a question already answered.
///   * Among the rest, ask the one whose target dimension is *least certain*
///     (lowest [GuestProfile.confidence]) — the most informative next probe.
///   * Stop early once the profile is "confident enough": at least [minAsked]
///     answered AND ([confidentTarget] dimensions known OR [maxAsked] reached).
///
/// Because each answer also nudges correlated dimensions (see the question
/// bank), confidence spreads faster than one-axis-per-question, so a typical
/// guest finishes in 3–4 swipes rather than all eight — that is the "stops
/// early" behaviour the brief asks for.
class AdaptiveEngine {
  AdaptiveEngine({
    required this.bank,
    this.minAsked = 3,
    this.maxAsked = 6,
    this.confidentTarget = 5,
  });

  final List<Question> bank;
  final int minAsked;
  final int maxAsked;

  /// How many dimensions (incl. mood) must be confident to allow an early stop.
  final int confidentTarget;

  final List<String> _askedIds = [];

  List<String> get askedIds => List.unmodifiable(_askedIds);
  int get askedCount => _askedIds.length;

  /// True once we've gathered enough signal to move on.
  bool isDone(GuestProfile p) {
    if (_askedIds.length < minAsked) return false;
    if (_askedIds.length >= maxAsked) return true;
    if (remaining.isEmpty) return true;
    return p.confidentCount >= confidentTarget;
  }

  List<Question> get remaining =>
      bank.where((q) => !_askedIds.contains(q.id)).toList(growable: false);

  /// The next most-informative question, or null when none remain.
  Question? next(GuestProfile p) {
    final pool = remaining;
    if (pool.isEmpty) return null;
    pool.sort((a, b) =>
        p.confidenceOf(a.target).compareTo(p.confidenceOf(b.target)));
    return pool.first;
  }

  /// Records that [q] was answered with [option], updating [p] and the engine.
  void apply(GuestProfile p, Question q, QOption option) {
    if (!_askedIds.contains(q.id)) _askedIds.add(q.id);
    p.answer(q.target, option.value);
    option.nudges.forEach((dim, v) => p.nudge(dim, v));
  }

  void reset() => _askedIds.clear();
}
