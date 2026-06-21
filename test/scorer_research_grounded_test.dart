import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/engine/recommendation_engine.dart';
import 'package:vybia_v2/features/reco/engine/reco_context.dart';
import 'package:vybia_v2/features/reco/engine/wellbeing_tagger.dart';
import 'package:vybia_v2/features/reco/model/activity.dart';
import 'package:vybia_v2/features/reco/model/motive.dart';
import 'package:vybia_v2/features/reco/model/wellbeing.dart';

const _ctx = RecoContext(hourOfDay: 14, month: 6);

const MotiveAffinity _motive =
    (hedonic: 0.5, relaxation: 0.5, eudaimonic: 0.5);

/// A pair of otherwise-identical activities that differ ONLY on the
/// hedonic↔eudaimonic axis (persisted override), so the affect term is the only
/// thing that can separate them.
// Distinct categories so the diversity / near-duplicate guard keeps BOTH twins
// in the batch — the affect term is still the only scoring difference.
Activity _twin(String id, double he, ActivityCategory category) => Activity(
      id: id,
      titleFr: id,
      category: category,
      tags: {
        for (final d in Dimension.values) d: 0.5,
      },
      motives: _motive,
      budget: 1,
      indoor: true,
      descFr: id,
      lat: 45.5,
      lng: -73.57,
      image: 'assets/x.jpg',
      hasLocation: false, // drop distance so only taste/affect/etc. matter
      wellbeing: WellbeingTags(
        hedoniaEudaimonia: he,
        socialSupport: 0.5,
        intrinsicAppeal: 0.5,
        flexibility: 0.5,
      ),
    );

final _twinEngine = RecommendationEngine(catalog: [
  _twin('hedonic', 0.12, ActivityCategory.cafe),
  _twin('eudaimonic', 0.88, ActivityCategory.culture),
]);

GuestProfile _tiredEscape() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.12); // calm / drained
  p.answer(Dimension.energy, 0.12);
  p.answer(Dimension.social, 0.35);
  p.answer(Dimension.novelty, 0.2);
  return p;
}

GuestProfile _curiousGrowth() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.5); // mid = exploratory
  p.answer(Dimension.energy, 0.5);
  p.answer(Dimension.social, 0.4);
  p.answer(Dimension.novelty, 0.95);
  return p;
}

void main() {
  group('S11B — hedonic↔eudaimonic mood fit flips the pick', () {
    test('a tired/escape guest is steered to the hedonic twin', () {
      final best = _twinEngine.recommend(_tiredEscape(), context: _ctx).first;
      expect(best.activity.id, 'hedonic');
    });

    test('a curious/growth guest is steered to the eudaimonic twin', () {
      final best = _twinEngine.recommend(_curiousGrowth(), context: _ctx).first;
      expect(best.activity.id, 'eudaimonic');
    });

    test('SAME catalog, DIFFERENT top picks driven by mood/motive', () {
      final tired = _twinEngine.recommend(_tiredEscape(), context: _ctx).first;
      final curious =
          _twinEngine.recommend(_curiousGrowth(), context: _ctx).first;
      expect(tired.activity.id, isNot(curious.activity.id));
    });

    test('on the real catalog, the curious pick reads more eudaimonic', () {
      const engine = RecommendationEngine(catalog: kActivityCatalog);
      final tired = engine.recommend(_tiredEscape(), context: _ctx).first;
      final curious = engine.recommend(_curiousGrowth(), context: _ctx).first;
      final tiredHe = WellbeingTagger.of(tired.activity).hedoniaEudaimonia;
      final curiousHe = WellbeingTagger.of(curious.activity).hedoniaEudaimonia;
      expect(curiousHe, greaterThan(tiredHe));
    });
  });

  group('S11B — every term contributes through the breakdown', () {
    test('breakdown.total equals the score for every recommendation', () {
      const engine = RecommendationEngine(catalog: kActivityCatalog);
      final recs = engine.recommend(_curiousGrowth(), context: _ctx);
      for (final r in recs) {
        expect(r.breakdown, isNotNull, reason: r.activity.id);
        expect(r.breakdown!.total, closeTo(r.score, 1e-9), reason: r.activity.id);
      }
    });

    test('the affect term actually moves between the two guests', () {
      final tired = _twinEngine
          .recommend(_tiredEscape(), context: _ctx)
          .firstWhere((r) => r.activity.id == 'hedonic');
      final curious = _twinEngine
          .recommend(_curiousGrowth(), context: _ctx)
          .firstWhere((r) => r.activity.id == 'hedonic');
      // The hedonic twin earns a bigger affect contribution for the tired guest.
      expect(tired.breakdown!.affect,
          greaterThan(curious.breakdown!.affect));
    });
  });

  group('S11B — confidence-weighting leans on what we know', () {
    Activity indoorMatch() => Activity(
          id: 'indoor_match',
          titleFr: 'indoor',
          category: ActivityCategory.cafe,
          tags: {for (final d in Dimension.values) d: 0.5}..[Dimension.indoor] =
              1.0,
          motives: _motive,
          budget: 1,
          indoor: true,
          descFr: 'indoor',
          lat: 45.5,
          lng: -73.57,
          image: 'assets/x.jpg',
          hasLocation: false,
        );

    test('a confident matching dimension scores higher than an unsure one', () {
      final engine = RecommendationEngine(catalog: [indoorMatch()]);

      final confident = GuestProfile()..answer(Dimension.indoor, 1.0);
      final unsure = GuestProfile()..nudge(Dimension.indoor, 1.0, weight: 0.05);

      final cScore =
          engine.recommend(confident, context: _ctx).first.breakdown!.pref;
      final uScore =
          engine.recommend(unsure, context: _ctx).first.breakdown!.pref;
      expect(cScore, greaterThan(uScore),
          reason: 'a known match should weigh more than a barely-inferred one');
    });
  });
}
