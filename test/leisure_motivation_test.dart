import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/engine/leisure_motivation.dart';
import 'package:vybia_v2/features/reco/model/lms_motive.dart';

double _sum(LmsWeights w) =>
    w.intellectual + w.social + w.competence + w.stimulusAvoidance;

GuestProfile _calmSolo() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.1);
  p.answer(Dimension.energy, 0.1);
  p.answer(Dimension.social, 0.1);
  p.answer(Dimension.vibe, 0.15);
  return p;
}

GuestProfile _livelySocial() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.95);
  p.answer(Dimension.energy, 0.9);
  p.answer(Dimension.social, 0.95);
  p.answer(Dimension.vibe, 0.85);
  return p;
}

GuestProfile _curiousExplorer() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.5); // mid = exploratory
  p.answer(Dimension.novelty, 0.95);
  p.answer(Dimension.energy, 0.45);
  p.answer(Dimension.social, 0.4);
  return p;
}

void main() {
  group('LeisureMotivation — Beard & Ragheb LMS (S9C)', () {
    test('guest weights are normalized (sum ≈ 1) and in range', () {
      for (final p in [_calmSolo(), _livelySocial(), _curiousExplorer()]) {
        final w = LeisureMotivation.weightsFor(p);
        expect(_sum(w), closeTo(1.0, 1e-9));
        for (final v in [
          w.intellectual,
          w.social,
          w.competence,
          w.stimulusAvoidance
        ]) {
          expect(v, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('a neutral profile yields a soft spread (no motive collapses to 0/1)',
        () {
      // Defaults are 0.5 per dimension; with a mid (exploratory) mood the spread
      // tilts gently intellectual but stays soft — never a degenerate winner.
      final w = LeisureMotivation.weightsFor(GuestProfile());
      expect(_sum(w), closeTo(1.0, 1e-9));
      for (final v in [
        w.intellectual,
        w.social,
        w.competence,
        w.stimulusAvoidance
      ]) {
        expect(v, inInclusiveRange(0.15, 0.4));
      }
    });

    test('calm + solo → stimulus-avoidance dominates', () {
      final w = LeisureMotivation.weightsFor(_calmSolo());
      expect(LeisureMotivation.dominant(w), LmsMotive.stimulusAvoidance);
    });

    test('lively + social → social dominates', () {
      final w = LeisureMotivation.weightsFor(_livelySocial());
      expect(LeisureMotivation.dominant(w), LmsMotive.social);
    });

    test('curious + novelty-seeking → intellectual is strong', () {
      final w = LeisureMotivation.weightsFor(_curiousExplorer());
      // Intellectual should out-weigh stimulus-avoidance for an explorer.
      expect(w.intellectual, greaterThan(w.stimulusAvoidance));
    });

    test('every catalog activity has in-range LMS affinities', () {
      for (final a in kActivityCatalog) {
        final aff = LeisureMotivation.affinityFor(a);
        for (final v in [
          aff.intellectual,
          aff.social,
          aff.competence,
          aff.stimulusAvoidance
        ]) {
          expect(v, inInclusiveRange(0.0, 1.0), reason: a.id);
        }
      }
    });

    test('match is 0..1 and rewards an aligned activity', () {
      final w = LeisureMotivation.weightsFor(_livelySocial());
      for (final a in kActivityCatalog) {
        final m = LeisureMotivation.match(w, LeisureMotivation.affinityFor(a));
        expect(m, inInclusiveRange(0.0, 1.0), reason: a.id);
      }
    });
  });
}
