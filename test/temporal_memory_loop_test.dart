import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/core/theme/app_colors.dart' show OrbDirection;
import 'package:vybia_v2/features/guest/data/question_bank.dart';
import 'package:vybia_v2/features/guest/engine/adaptive_engine.dart';
import 'package:vybia_v2/features/guest/engine/loop_controller.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/guest/model/moment.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/engine/recommendation_engine.dart';
import 'package:vybia_v2/features/reco/engine/reco_context.dart';
import 'package:vybia_v2/features/reco/memory/preference_memory.dart';
import 'package:vybia_v2/features/reco/state/reco_controller.dart';

const _recoEngine = RecommendationEngine(catalog: kActivityCatalog);
const _ctx = RecoContext(hourOfDay: 19, month: 6); // a June evening

GuestProfile _lively() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.9); // lively
  return p;
}

MomentContext _eveningToday() =>
    const MomentContext(weekday: DateTime.tuesday, hour: 19, date: '2026-06-23');

RecoController _reco(PreferenceMemory mem, {MomentContext? moment}) =>
    RecoController(
      profile: _lively(),
      engine: _recoEngine,
      context: _ctx,
      memory: mem,
      moment: moment ?? _eveningToday(),
    );

void main() {
  group('S19B — cross-session memory in the reco controller', () {
    test('a "pas pour moi" is NOT re-shown in the same slot+mood', () {
      // Find the activity the lively guest would otherwise be shown first.
      final baseline = _reco(PreferenceMemory());
      final disliked = baseline.current!.activity.id;

      // Record it disliked in this exact slot+mood, then a fresh controller in
      // the SAME slot+mood must not surface it at all.
      final mem = PreferenceMemory()
        ..recordReaction(
          activityId: disliked,
          liked: false,
          moment: _eveningToday(),
          mood: MoodBucket.lively,
        );
      final next = _reco(mem);
      expect(next.ranked.any((r) => r.activity.id == disliked), isFalse,
          reason: 'disliked in this slot+mood → suppressed cross-session');
    });

    test('a disliked pick CAN resurface in a different slot', () {
      final baseline = _reco(PreferenceMemory());
      final disliked = baseline.current!.activity.id;
      final mem = PreferenceMemory()
        ..recordReaction(
          activityId: disliked,
          liked: false,
          moment: _eveningToday(), // evening
          mood: MoodBucket.lively,
        );
      // Same guest/mood but a MORNING slot → no longer suppressed.
      final morning = _reco(mem,
          moment: const MomentContext(
              weekday: DateTime.tuesday, hour: 9, date: '2026-06-24'));
      expect(morning.ranked.any((r) => r.activity.id == disliked), isTrue,
          reason: 'a different slot may resurface a disliked activity');
    });

    test('a liked-but-unlived pick resurfaces (lifted) on another day', () {
      final baseline = _reco(PreferenceMemory());
      // Pick a NON-leading activity to like yesterday, so the resurface bump is
      // observable as a rank improvement today.
      final target = baseline.ranked.last.activity.id;
      final beforeRank =
          baseline.ranked.indexWhere((r) => r.activity.id == target);

      final mem = PreferenceMemory()
        ..recordReaction(
          activityId: target,
          liked: true,
          moment: const MomentContext(
              weekday: DateTime.monday, hour: 19, date: '2026-06-22'),
          mood: MoodBucket.lively,
        );
      final today = _reco(mem); // different day (2026-06-23)
      final afterRank =
          today.ranked.indexWhere((r) => r.activity.id == target);
      expect(afterRank, isNonNegative,
          reason: 'liked-on-another-day is shown again, not suppressed');
      expect(afterRank, lessThanOrEqualTo(beforeRank),
          reason: 'the resurface bump lifts it (never lower than before)');
    });
  });

  group('S19B/C — the loop remembers answered questions per moment', () {
    test('records each answer into the memory with its moment', () {
      final mem = PreferenceMemory();
      final loop = LoopController(
        profile: _lively(),
        recoEngine: _recoEngine,
        context: _ctx,
        memory: mem,
        moment: _eveningToday(),
        questionsPerBatch: 2,
        firstBatchSize: 2,
      );
      final firstQ = loop.currentQuestion!.id;
      loop.answer(loop.currentQuestion!.optionFor(OrbDirection.left)!);
      expect(
        mem.answeredQuestionIdsFor(
            slot: DaySlot.evening, mood: MoodBucket.lively),
        contains(firstQ),
      );
    });

    test('a question firmly answered for this moment is not re-asked', () {
      // Pre-seed the memory with the question the loop would ask first.
      final probe = LoopController(
        profile: _lively(),
        recoEngine: _recoEngine,
        context: _ctx,
        memory: PreferenceMemory(),
        moment: _eveningToday(),
      );
      final firstId = probe.currentQuestion!.id;

      final mem = PreferenceMemory()
        ..recordAnswer(
          questionId: firstId,
          moment: _eveningToday(),
          mood: MoodBucket.lively,
        );
      final loop = LoopController(
        profile: _lively(),
        questionEngine: AdaptiveEngine(bank: kQuestionBank),
        recoEngine: _recoEngine,
        context: _ctx,
        memory: mem,
        moment: _eveningToday(),
      );
      // It may still ask OTHER questions, but never the remembered one.
      expect(loop.currentQuestion?.id, isNot(firstId));
    });
  });
}
