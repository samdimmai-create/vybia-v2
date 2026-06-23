import '../model/dimension.dart';
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

  /// S19C: the dimensions the LAST answer nudged — used to follow the THREAD,
  /// preferring an interrelated next question among equally-uncertain ones.
  Set<Dimension> _lastRelated = const {};

  /// S19B/C: epsilon within which two questions count as "equally uncertain", so
  /// the tie can be broken by interrelation instead of float noise.
  static const double _tieEpsilon = 0.08;

  List<String> get askedIds => List.unmodifiable(_askedIds);
  int get askedCount => _askedIds.length;

  /// S19B: mark [ids] as already answered (e.g. firmly answered for this moment
  /// in a previous session) so they are never re-asked — Vybia remembers you.
  void seedAnswered(Iterable<String> ids) {
    for (final id in ids) {
      if (!_askedIds.contains(id)) _askedIds.add(id);
    }
  }

  /// True once we've gathered enough signal to move on.
  bool isDone(GuestProfile p) {
    if (_askedIds.length < minAsked) return false;
    if (_askedIds.length >= maxAsked) return true;
    if (remaining.isEmpty) return true;
    return p.confidentCount >= confidentTarget;
  }

  List<Question> get remaining =>
      bank.where((q) => !_askedIds.contains(q.id)).toList(growable: false);

  /// The next question to ask. Information-greedy first — the least-certain
  /// target dimension — but among questions that are *equally* uncertain (within
  /// [_tieEpsilon]) it follows the THREAD (S19C): it prefers one whose target the
  /// LAST answer just touched, so each answer visibly steers the next question
  /// instead of jumping to an unrelated, generic probe. Null when none remain.
  Question? next(GuestProfile p) {
    final pool = remaining;
    if (pool.isEmpty) return null;
    pool.sort((a, b) =>
        p.confidenceOf(a.target).compareTo(p.confidenceOf(b.target)));
    final lowest = p.confidenceOf(pool.first.target);
    // The interrelated tie-break: among the near-least-certain probes, surface
    // one related to what the guest just told us.
    if (_lastRelated.isNotEmpty) {
      for (final q in pool) {
        if (p.confidenceOf(q.target) - lowest > _tieEpsilon) break;
        if (_lastRelated.contains(q.target)) return q;
      }
    }
    return pool.first;
  }

  /// Records that [q] was answered with [option], updating [p] and the engine.
  void apply(GuestProfile p, Question q, QOption option) {
    if (!_askedIds.contains(q.id)) _askedIds.add(q.id);
    p.answer(q.target, option.value);
    option.nudges.forEach((dim, v) => p.nudge(dim, v));
    // S19C: remember the thread — the dimensions this answer related to — so the
    // next pick can follow it (the question's own target plus what it nudged).
    _lastRelated = {q.target, ...option.nudges.keys};
  }

  void reset() {
    _askedIds.clear();
    _lastRelated = const {};
  }
}
