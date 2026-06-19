import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/data/question_bank.dart';
import 'package:vybia_v2/features/guest/engine/adaptive_engine.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';

void main() {
  group('GuestProfile', () {
    test('answer raises confidence and moves the value', () {
      final p = GuestProfile();
      expect(p.confidenceOf(Dimension.energy), 0.0);
      p.answer(Dimension.energy, 0.9);
      expect(p.valueOf(Dimension.energy), closeTo(0.9, 0.0001));
      expect(p.isConfident(Dimension.energy), isTrue);
    });

    test('nudge applies partial pull + partial confidence', () {
      final p = GuestProfile();
      p.nudge(Dimension.vibe, 1.0, weight: 0.3);
      expect(p.valueOf(Dimension.vibe), closeTo(0.5 * 0.7 + 1.0 * 0.3, 0.0001));
      expect(p.confidenceOf(Dimension.vibe), greaterThan(0.0));
      expect(p.isConfident(Dimension.vibe), isFalse); // not enough on its own
    });
  });

  group('AdaptiveEngine', () {
    test('picks the least-certain dimension and never repeats', () {
      final p = GuestProfile();
      final e = AdaptiveEngine(bank: kQuestionBank);

      final first = e.next(p)!;
      final option = first.options.first;
      e.apply(p, first, option);

      expect(e.askedIds, contains(first.id));
      final second = e.next(p);
      expect(second, isNotNull);
      expect(second!.id, isNot(first.id));
    });

    test('stops early once the profile is confident (fewer than all 8)', () {
      final p = GuestProfile();
      final e = AdaptiveEngine(bank: kQuestionBank);

      var guard = 0;
      while (!e.isDone(p) && guard < 20) {
        final q = e.next(p);
        if (q == null) break;
        // Always pick the strong (right) option to spread correlated nudges.
        e.apply(p, q, q.options.last);
        guard++;
      }

      expect(e.isDone(p), isTrue);
      expect(e.askedCount, greaterThanOrEqualTo(e.minAsked));
      expect(e.askedCount, lessThan(kQuestionBank.length),
          reason: 'correlated nudges should let it stop before all 8');
    });

    test('respects the minimum question count', () {
      final p = GuestProfile();
      final e = AdaptiveEngine(bank: kQuestionBank);
      // One very informative answer is not enough to stop.
      final q = e.next(p)!;
      e.apply(p, q, q.options.last);
      expect(e.isDone(p), isFalse);
    });
  });
}
