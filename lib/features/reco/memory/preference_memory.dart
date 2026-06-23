import '../../guest/model/moment.dart';

/// One remembered reaction, stamped with its MOMENT (S19B).
///
/// `liked` is the revealed preference (Intéressant vs Pas-pour-moi); `planned`
/// flips true once the guest actually turned it into a plan, so a lived pick is
/// no longer "a preference you haven't lived yet".
class ReactionRecord {
  ReactionRecord({
    required this.activityId,
    required this.liked,
    required this.slot,
    required this.mood,
    required this.weekday,
    required this.date,
    this.planned = false,
  });

  final String activityId;
  final bool liked;
  final DaySlot slot;
  final MoodBucket mood;
  final int weekday;

  /// `yyyy-mm-dd` the reaction was made — distinguishes "today" from "another
  /// day" so a liked pick can resurface later (S19B).
  final String date;
  bool planned;

  Map<String, dynamic> toJson() => {
        'a': activityId,
        'liked': liked,
        'slot': slot.name,
        'mood': mood.name,
        'wd': weekday,
        'date': date,
        'planned': planned,
      };

  static ReactionRecord? tryFromJson(Map<String, dynamic> j) {
    final id = j['a'];
    if (id is! String) return null;
    return ReactionRecord(
      activityId: id,
      liked: j['liked'] == true,
      slot: DaySlot.byName(j['slot'] as String?),
      mood: MoodBucket.byName(j['mood'] as String?),
      weekday: (j['wd'] as num?)?.toInt() ?? DateTime.monday,
      date: j['date'] as String? ?? '',
      planned: j['planned'] == true,
    );
  }
}

/// One question firmly answered for a given (slot, mood) context, so Vybia
/// doesn't re-ask what it already knows about you AT THIS MOMENT (S19B/C).
class AnsweredRecord {
  AnsweredRecord({
    required this.questionId,
    required this.slot,
    required this.mood,
  });

  final String questionId;
  final DaySlot slot;
  final MoodBucket mood;

  Map<String, dynamic> toJson() =>
      {'q': questionId, 'slot': slot.name, 'mood': mood.name};

  static AnsweredRecord? tryFromJson(Map<String, dynamic> j) {
    final id = j['q'];
    if (id is! String) return null;
    return AnsweredRecord(
      questionId: id,
      slot: DaySlot.byName(j['slot'] as String?),
      mood: MoodBucket.byName(j['mood'] as String?),
    );
  }
}

/// THE TEMPORAL PREFERENCE MEMORY (S19B) — pure logic, no Flutter, no storage.
///
/// It remembers every reaction and every firmly-answered question WITH the
/// moment it happened, and turns that history into three cross-session rules the
/// reco loop and the adaptive engine consult:
///
///   * [suppressedFor] — a "pas pour moi" activity is NOT re-proposed in the
///     SAME slot+mood (it may resurface on a different time-slot or mood); a
///     liked pick isn't shown twice the SAME day; a planned pick is done.
///   * [resurfacedFor] — a liked-but-not-yet-lived activity is gently re-surfaced
///     on OTHER days, "a reminder of a preference you haven't lived yet".
///   * [answeredQuestionIdsFor] — questions firmly answered for this context are
///     not re-asked, so Vybia feels like it REMEMBERS you.
class PreferenceMemory {
  PreferenceMemory({
    List<ReactionRecord>? reactions,
    List<AnsweredRecord>? answered,
  })  : reactions = reactions ?? [],
        answered = answered ?? [];

  final List<ReactionRecord> reactions;
  final List<AnsweredRecord> answered;

  bool get isEmpty => reactions.isEmpty && answered.isEmpty;

  /// Record (or update) a reaction for the given moment. Re-reacting to the same
  /// activity in the same slot+mood replaces the prior verdict rather than
  /// piling up duplicates, so the latest feeling wins.
  void recordReaction({
    required String activityId,
    required bool liked,
    required MomentContext moment,
    required MoodBucket mood,
  }) {
    reactions.removeWhere((r) =>
        r.activityId == activityId && r.slot == moment.slot && r.mood == mood);
    reactions.add(ReactionRecord(
      activityId: activityId,
      liked: liked,
      slot: moment.slot,
      mood: mood,
      weekday: moment.weekday,
      date: moment.todayKey,
    ));
  }

  /// Mark every remembered reaction for [activityId] as lived/planned, so it
  /// stops resurfacing as an unlived preference.
  void markPlanned(String activityId) {
    for (final r in reactions) {
      if (r.activityId == activityId) r.planned = true;
    }
  }

  void recordAnswer({
    required String questionId,
    required MomentContext moment,
    required MoodBucket mood,
  }) {
    final exists = answered.any((a) =>
        a.questionId == questionId && a.slot == moment.slot && a.mood == mood);
    if (exists) return;
    answered.add(AnsweredRecord(
      questionId: questionId,
      slot: moment.slot,
      mood: mood,
    ));
  }

  /// Activity ids that must NOT be shown right now (this slot + mood + today):
  ///   * disliked in THIS slot+mood (a different slot/mood may resurface them),
  ///   * already planned (lived — they belong to Mes Plans now),
  ///   * liked earlier TODAY (don't repeat the same pick the same day).
  Set<String> suppressedFor({
    required DaySlot slot,
    required MoodBucket mood,
    required String today,
  }) {
    final out = <String>{};
    for (final r in reactions) {
      if (r.planned) {
        out.add(r.activityId);
      } else if (!r.liked && r.slot == slot && r.mood == mood) {
        out.add(r.activityId);
      } else if (r.liked && r.date == today) {
        out.add(r.activityId);
      }
    }
    return out;
  }

  /// Liked-but-not-yet-lived activity ids from ANOTHER day — gently re-surfaced
  /// now as "a preference you haven't lived yet" (S19B). Excludes anything the
  /// same-slot/mood rule is currently suppressing.
  Set<String> resurfacedFor({
    required DaySlot slot,
    required MoodBucket mood,
    required String today,
  }) {
    final suppressed = suppressedFor(slot: slot, mood: mood, today: today);
    final out = <String>{};
    for (final r in reactions) {
      if (!r.liked || r.planned) continue;
      if (r.date == today) continue; // same day → not a "reminder"
      if (suppressed.contains(r.activityId)) continue;
      out.add(r.activityId);
    }
    return out;
  }

  /// Questions firmly answered for this (slot, mood) — not to be re-asked.
  Set<String> answeredQuestionIdsFor({
    required DaySlot slot,
    required MoodBucket mood,
  }) {
    final out = <String>{};
    for (final a in answered) {
      if (a.slot == slot && a.mood == mood) out.add(a.questionId);
    }
    return out;
  }

  /// The mood the guest is MOST often in during [slot] (their "usual mood at
  /// that time"), or null when there's no history yet — used to choose the
  /// time-aware Accueil backdrop (S19E).
  MoodBucket? usualMoodFor(DaySlot slot) {
    final counts = <MoodBucket, int>{};
    for (final r in reactions) {
      if (r.slot != slot) continue;
      counts[r.mood] = (counts[r.mood] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    MoodBucket? best;
    var bestN = -1;
    for (final e in counts.entries) {
      if (e.value > bestN) {
        bestN = e.value;
        best = e.key;
      }
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
        'reactions': [for (final r in reactions) r.toJson()],
        'answered': [for (final a in answered) a.toJson()],
      };

  static PreferenceMemory fromJson(Map<String, dynamic> j) {
    final rxs = <ReactionRecord>[];
    final ans = <AnsweredRecord>[];
    final rawR = j['reactions'];
    if (rawR is List) {
      for (final item in rawR) {
        if (item is Map<String, dynamic>) {
          final r = ReactionRecord.tryFromJson(item);
          if (r != null) rxs.add(r);
        }
      }
    }
    final rawA = j['answered'];
    if (rawA is List) {
      for (final item in rawA) {
        if (item is Map<String, dynamic>) {
          final a = AnsweredRecord.tryFromJson(item);
          if (a != null) ans.add(a);
        }
      }
    }
    return PreferenceMemory(reactions: rxs, answered: ans);
  }
}
