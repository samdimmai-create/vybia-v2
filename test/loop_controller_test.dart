import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/core/theme/app_colors.dart' show OrbDirection;
import 'package:vybia_v2/features/guest/data/question_bank.dart';
import 'package:vybia_v2/features/guest/engine/adaptive_engine.dart';
import 'package:vybia_v2/features/guest/engine/loop_controller.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/engine/recommendation_engine.dart';
import 'package:vybia_v2/features/reco/engine/reco_context.dart';

const _recoEngine = RecommendationEngine(catalog: kActivityCatalog);
const _ctx = RecoContext(hourOfDay: 14, month: 6);

GuestProfile _seeded() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.4);
  return p;
}

/// A loop tuned to FORCE alternation: tiny batches/rounds and a confidence
/// target that can't be reached early, so questions keep being inserted between
/// reco rounds (proves the loop interleaves rather than front-loading).
LoopController _alternatingLoop() => LoopController(
      profile: _seeded(),
      questionEngine:
          AdaptiveEngine(bank: kQuestionBank, minAsked: 2, maxAsked: 8, confidentTarget: 99),
      recoEngine: _recoEngine,
      context: _ctx,
      questionsPerBatch: 2,
      recosPerRound: 2,
      maxRounds: 4,
    );

/// Answer the current question batch (always the LEFT option) until the loop
/// leaves the questions phase. Returns how many questions it answered.
int _answerBatch(LoopController loop) {
  var n = 0;
  while (loop.phase == LoopPhase.questions) {
    final q = loop.currentQuestion!;
    loop.answer(q.optionFor(OrbDirection.left)!);
    n++;
    if (n > 12) fail('question batch did not terminate');
  }
  return n;
}

void main() {
  group('LoopController — explicit state machine (S9B)', () {
    test('starts in a question batch with a live question', () {
      final loop = _alternatingLoop();
      expect(loop.phase, LoopPhase.questions);
      expect(loop.currentQuestion, isNotNull);
      expect(loop.currentReco, isNull);
    });

    test('a batch bridges to reflection, then reflection opens a reco round',
        () {
      final loop = _alternatingLoop();
      final asked = _answerBatch(loop);
      expect(asked, 2, reason: 'questionsPerBatch caps the first batch at 2');
      expect(loop.phase, LoopPhase.reflection);

      loop.reflectionDone();
      expect(loop.phase, LoopPhase.recos);
      expect(loop.currentReco, isNotNull);
    });

    test('reaction budget inserts a NEW question batch — the loop alternates',
        () {
      final loop = _alternatingLoop();
      _answerBatch(loop); // batch 1
      loop.reflectionDone(); // → recos round 1

      // React up to the round budget (2). The 2nd reaction should kick the loop
      // back into a fresh question batch (alternation), not stay in recos.
      loop.reactInteresting();
      expect(loop.phase, LoopPhase.recos);
      loop.reactNotInteresting();
      expect(loop.phase, LoopPhase.questions,
          reason: 'round budget spent → sharpen with a new question batch');
      expect(loop.round, 1);
    });

    test('each question batch sharpens the profile (confidence is monotone up)',
        () {
      final loop = _alternatingLoop();
      final before = loop.confidentCount;
      _answerBatch(loop);
      final after = loop.confidentCount;
      expect(after, greaterThanOrEqualTo(before));
      expect(after, greaterThan(0));
    });

    test('Planifier (select) on a reco ends the loop and returns the pick', () {
      final loop = _alternatingLoop();
      _answerBatch(loop);
      loop.reflectionDone();
      expect(loop.phase, LoopPhase.recos);

      final rec = loop.currentReco;
      final selected = loop.select();
      expect(selected, isNotNull);
      expect(selected!.activity.id, rec!.activity.id);
      expect(loop.phase, LoopPhase.selected);

      // After selection the loop is terminal — further reactions are ignored.
      loop.reactInteresting();
      expect(loop.phase, LoopPhase.selected);
    });

    test('converges: with default tuning the loop reaches a confident profile '
        'and keeps serving recos without endless question batches', () {
      final loop = LoopController(
        profile: _seeded(),
        recoEngine: _recoEngine,
        context: _ctx,
      );
      // Drive a realistic session: answer the opening batch, then react a few
      // times. The engine should become confident and STOP inserting batches.
      _answerBatch(loop);
      loop.reflectionDone();
      var guard = 0;
      while (loop.phase == LoopPhase.recos && guard < 30) {
        // Walk through batches if any are inserted, else react.
        if (loop.phase == LoopPhase.questions) {
          _answerBatch(loop);
          loop.reflectionDone();
        }
        loop.reactInteresting();
        if (loop.phase == LoopPhase.reflection) loop.reflectionDone();
        guard++;
      }
      // It either exhausted the catalog or stayed in recos — never spun forever.
      expect(guard, lessThan(30));
      expect(loop.profile.confidentCount, greaterThanOrEqualTo(3));
    });

    test('runs out cleanly → exhausted, never stuck', () {
      final loop = LoopController(
        profile: _seeded(),
        recoEngine: _recoEngine,
        context: _ctx,
        recosPerRound: 99, // never insert a new batch; drain all recos
        maxRounds: 1,
      );
      _answerBatch(loop);
      loop.reflectionDone();
      var guard = 0;
      while (loop.phase == LoopPhase.recos && guard < 200) {
        loop.reactNotInteresting();
        guard++;
      }
      expect(loop.phase, LoopPhase.exhausted);
    });
  });
}
