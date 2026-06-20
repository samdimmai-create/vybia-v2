import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/guest/model/life_context.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/engine/life_context_rules.dart';
import 'package:vybia_v2/features/reco/engine/recommendation_engine.dart';
import 'package:vybia_v2/features/reco/engine/reco_context.dart';
import 'package:vybia_v2/features/reco/model/activity.dart';

const _engine = RecommendationEngine(catalog: kActivityCatalog);
const _ctx = RecoContext(hourOfDay: 19, month: 6); // evening, so bars rank well

Activity _byCategory(ActivityCategory c) =>
    kActivityCatalog.firstWhere((a) => a.category == c);

GuestProfile _social() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.85);
  p.answer(Dimension.social, 0.85);
  p.answer(Dimension.vibe, 0.8);
  p.answer(Dimension.timing, 0.8); // wants the evening
  return p;
}

void main() {
  group('LifeContextRules — feasibility table (S9D)', () {
    test('sans alcool drops nightlife', () {
      final bar = _byCategory(ActivityCategory.nightlife);
      expect(
          LifeContextRules.feasible({LifeContext.sansAlcool}, bar), isFalse);
      final cafe = _byCategory(ActivityCategory.cafe);
      expect(
          LifeContextRules.feasible({LifeContext.sansAlcool}, cafe), isTrue);
    });

    test('avec enfants drops nightlife', () {
      final bar = _byCategory(ActivityCategory.nightlife);
      expect(
          LifeContextRules.feasible({LifeContext.avecEnfants}, bar), isFalse);
    });

    test('budget serré drops splurges (tier 3)', () {
      final splurge =
          kActivityCatalog.firstWhere((a) => a.budget >= 3);
      expect(LifeContextRules.feasible({LifeContext.budgetSerre}, splurge),
          isFalse);
      final cheap = kActivityCatalog.firstWhere((a) => a.budget == 0);
      expect(LifeContextRules.feasible({LifeContext.budgetSerre}, cheap),
          isTrue);
    });

    test('mobilité réduite drops high-effort active activities', () {
      final active = _byCategory(ActivityCategory.active);
      expect(LifeContextRules.feasible({LifeContext.mobiliteReduite}, active),
          isFalse);
    });

    test('sans voiture drops places across town (>6km)', () {
      final cafe = _byCategory(ActivityCategory.cafe);
      expect(
          LifeContextRules.feasible({LifeContext.sansVoiture}, cafe,
              distanceKm: 12),
          isFalse);
      expect(
          LifeContextRules.feasible({LifeContext.sansVoiture}, cafe,
              distanceKm: 2),
          isTrue);
    });

    test('no contexts → everything is feasible', () {
      for (final a in kActivityCatalog) {
        expect(LifeContextRules.feasible(const {}, a, distanceKm: 3), isTrue);
      }
    });
  });

  group('engine respects active life-contexts', () {
    test('avec enfants removes every nightlife pick from the recommendations',
        () {
      final p = _social();
      // Without the context, a social/evening profile surfaces nightlife.
      final before = _engine.recommend(p, context: _ctx);
      final hadNightlife =
          before.any((r) => r.activity.category == ActivityCategory.nightlife);
      expect(hadNightlife, isTrue,
          reason: 'baseline should include a bar for a social evening profile');

      p.setContext(LifeContext.avecEnfants, true);
      final after = _engine.recommend(p, context: _ctx);
      expect(
        after.every((r) => r.activity.category != ActivityCategory.nightlife),
        isTrue,
        reason: 'avec enfants must filter out all nightlife',
      );
      // Still gives a usable batch (never starves the scene).
      expect(after, isNotEmpty);
    });
  });

  group('persistence (S9D)', () {
    test('active contexts survive a profile toJson → restore round-trip', () {
      final p = GuestProfile();
      p.answer(Dimension.mood, 0.5);
      p.setContext(LifeContext.budgetSerre, true);
      p.setContext(LifeContext.sansVoiture, true);

      final restored = GuestProfile()..restore(p.toJson());
      expect(restored.hasContext(LifeContext.budgetSerre), isTrue);
      expect(restored.hasContext(LifeContext.sansVoiture), isTrue);
      expect(restored.hasContext(LifeContext.avecEnfants), isFalse);
    });

    test('clear() drops contexts too', () {
      final p = GuestProfile()..setContext(LifeContext.avecAnimal, true);
      p.clear();
      expect(p.contexts, isEmpty);
    });
  });
}
