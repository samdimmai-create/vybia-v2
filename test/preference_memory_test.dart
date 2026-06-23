import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/moment.dart';
import 'package:vybia_v2/features/reco/memory/preference_memory.dart';

MomentContext _moment(int weekday, int hour, String date) =>
    MomentContext(weekday: weekday, hour: hour, date: date);

void main() {
  group('PreferenceMemory (S19B) — temporal, moment-aware learning', () {
    test('a "pas pour moi" is suppressed in the SAME slot+mood only', () {
      final mem = PreferenceMemory();
      final eveningMon = _moment(DateTime.monday, 19, '2026-06-15');
      mem.recordReaction(
        activityId: 'club_x',
        liked: false,
        moment: eveningMon,
        mood: MoodBucket.lively,
      );

      // Same slot + mood → suppressed.
      expect(
        mem.suppressedFor(
            slot: DaySlot.evening, mood: MoodBucket.lively, today: '2026-06-16'),
        contains('club_x'),
      );
      // Different slot → may resurface (not suppressed).
      expect(
        mem.suppressedFor(
            slot: DaySlot.morning, mood: MoodBucket.lively, today: '2026-06-16'),
        isNot(contains('club_x')),
      );
      // Different mood → may resurface (not suppressed).
      expect(
        mem.suppressedFor(
            slot: DaySlot.evening, mood: MoodBucket.calm, today: '2026-06-16'),
        isNot(contains('club_x')),
      );
    });

    test('a liked-but-unlived pick resurfaces on OTHER days, not the same day',
        () {
      final mem = PreferenceMemory();
      mem.recordReaction(
        activityId: 'gallery_y',
        liked: true,
        moment: _moment(DateTime.monday, 14, '2026-06-15'),
        mood: MoodBucket.open,
      );

      // Same day → suppressed (no repeat), not resurfaced.
      expect(
        mem.suppressedFor(
            slot: DaySlot.afternoon, mood: MoodBucket.open, today: '2026-06-15'),
        contains('gallery_y'),
      );
      expect(
        mem.resurfacedFor(
            slot: DaySlot.afternoon, mood: MoodBucket.open, today: '2026-06-15'),
        isEmpty,
      );

      // Another day → resurfaced as a reminder, and NOT suppressed.
      expect(
        mem.resurfacedFor(
            slot: DaySlot.evening, mood: MoodBucket.lively, today: '2026-06-18'),
        contains('gallery_y'),
      );
      expect(
        mem.suppressedFor(
            slot: DaySlot.evening, mood: MoodBucket.lively, today: '2026-06-18'),
        isNot(contains('gallery_y')),
      );
    });

    test('a planned pick is suppressed everywhere and never resurfaces', () {
      final mem = PreferenceMemory();
      mem.recordReaction(
        activityId: 'hike_z',
        liked: true,
        moment: _moment(DateTime.sunday, 10, '2026-06-14'),
        mood: MoodBucket.open,
      );
      mem.markPlanned('hike_z');
      expect(
        mem.suppressedFor(
            slot: DaySlot.morning, mood: MoodBucket.open, today: '2026-06-20'),
        contains('hike_z'),
      );
      expect(
        mem.resurfacedFor(
            slot: DaySlot.morning, mood: MoodBucket.open, today: '2026-06-20'),
        isEmpty,
      );
    });

    test('re-reacting in the same slot+mood replaces the prior verdict', () {
      final mem = PreferenceMemory();
      final m = _moment(DateTime.tuesday, 14, '2026-06-16');
      mem.recordReaction(
          activityId: 'cafe_a', liked: false, moment: m, mood: MoodBucket.open);
      mem.recordReaction(
          activityId: 'cafe_a', liked: true, moment: m, mood: MoodBucket.open);
      expect(mem.reactions.where((r) => r.activityId == 'cafe_a').length, 1);
      expect(
        mem.suppressedFor(
            slot: DaySlot.afternoon, mood: MoodBucket.open, today: '2026-06-20'),
        isNot(contains('cafe_a')),
      );
    });

    test('answered questions are remembered per (slot, mood), not re-asked', () {
      final mem = PreferenceMemory();
      final m = _moment(DateTime.wednesday, 19, '2026-06-17');
      mem.recordAnswer(questionId: 'energy', moment: m, mood: MoodBucket.lively);
      mem.recordAnswer(questionId: 'energy', moment: m, mood: MoodBucket.lively);
      expect(mem.answered.length, 1, reason: 'no duplicate answer records');
      expect(
        mem.answeredQuestionIdsFor(slot: DaySlot.evening, mood: MoodBucket.lively),
        contains('energy'),
      );
      expect(
        mem.answeredQuestionIdsFor(slot: DaySlot.morning, mood: MoodBucket.lively),
        isNot(contains('energy')),
      );
    });

    test('usualMoodFor returns the most frequent mood in a slot', () {
      final mem = PreferenceMemory();
      for (final id in ['a', 'b', 'c']) {
        mem.recordReaction(
          activityId: id,
          liked: true,
          moment: _moment(DateTime.monday, 19, '2026-06-1$id'),
          mood: MoodBucket.lively,
        );
      }
      mem.recordReaction(
        activityId: 'd',
        liked: true,
        moment: _moment(DateTime.monday, 19, '2026-06-20'),
        mood: MoodBucket.calm,
      );
      expect(mem.usualMoodFor(DaySlot.evening), MoodBucket.lively);
      expect(mem.usualMoodFor(DaySlot.morning), isNull);
    });

    test('round-trips through JSON', () {
      final mem = PreferenceMemory();
      final m = _moment(DateTime.friday, 20, '2026-06-19');
      mem.recordReaction(
          activityId: 'bar_q', liked: false, moment: m, mood: MoodBucket.lively);
      mem.recordAnswer(questionId: 'vibe', moment: m, mood: MoodBucket.lively);
      final back = PreferenceMemory.fromJson(mem.toJson());
      expect(back.reactions.single.activityId, 'bar_q');
      expect(back.reactions.single.liked, isFalse);
      expect(back.answered.single.questionId, 'vibe');
      expect(
        back.suppressedFor(
            slot: DaySlot.evening, mood: MoodBucket.lively, today: '2026-06-25'),
        contains('bar_q'),
      );
    });
  });
}
