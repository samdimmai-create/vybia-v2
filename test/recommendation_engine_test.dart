import 'package:flutter_test/flutter_test.dart';
import 'package:vybia_v2/features/guest/model/activity_axes.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/engine/recommendation_engine.dart';
import 'package:vybia_v2/features/reco/engine/reco_context.dart';
import 'package:vybia_v2/features/reco/state/reco_controller.dart';

const _engine = RecommendationEngine(catalog: kActivityCatalog);

/// A fixed afternoon in June so context never drifts under the tests.
const _ctx = RecoContext(hourOfDay: 14, month: 6);

GuestProfile _calmSoloIndoor() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.1); // posé
  p.answer(Dimension.energy, 0.1);
  p.answer(Dimension.social, 0.1);
  p.answer(Dimension.indoor, 0.9);
  p.answer(Dimension.vibe, 0.15);
  p.answer(Dimension.budget, 0.2);
  return p;
}

GuestProfile _livelySocialOutdoor() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.95); // plein d'énergie
  p.answer(Dimension.energy, 0.9);
  p.answer(Dimension.social, 0.9);
  p.answer(Dimension.indoor, 0.1);
  p.answer(Dimension.vibe, 0.85);
  p.answer(Dimension.budget, 0.6);
  return p;
}

void main() {
  group('catalog', () {
    test('has 16–24 activities with unique ids', () {
      expect(kActivityCatalog.length, inInclusiveRange(16, 24));
      final ids = kActivityCatalog.map((a) => a.id).toSet();
      expect(ids.length, kActivityCatalog.length);
    });

    test('every activity tags all eight axes in range', () {
      for (final a in kActivityCatalog) {
        for (final d in kActivityAxes) {
          final v = a.tag(d);
          expect(v, inInclusiveRange(0.0, 1.0), reason: '${a.id} $d');
        }
      }
    });
  });

  group('engine', () {
    test('returns 4–6 ranked recommendations, best pick first', () {
      final recs = _engine.recommend(_calmSoloIndoor(), context: _ctx);
      expect(recs.length, inInclusiveRange(4, 6));
      expect(recs.first.isBestPick, isTrue);
      // Best pick must out-score the rest.
      for (final r in recs.skip(1)) {
        expect(recs.first.score, greaterThanOrEqualTo(r.score));
        expect(r.isBestPick, isFalse);
      }
    });

    test('different profiles yield different top picks', () {
      final calm = _engine.recommend(_calmSoloIndoor(), context: _ctx).first;
      final lively =
          _engine.recommend(_livelySocialOutdoor(), context: _ctx).first;
      expect(calm.activity.id, isNot(lively.activity.id));
    });

    test('best pick is deterministic for identical input', () {
      final a = _engine.recommend(_calmSoloIndoor(), context: _ctx).first;
      final b = _engine.recommend(_calmSoloIndoor(), context: _ctx).first;
      expect(a.activity.id, b.activity.id);
      expect(a.score, b.score);
    });

    test('every recommendation carries a non-empty "pourquoi"', () {
      final recs = _engine.recommend(_livelySocialOutdoor(), context: _ctx);
      for (final r in recs) {
        expect(r.why.trim(), isNotEmpty);
      }
    });

    test('excludedIds are never recommended', () {
      final first =
          _engine.recommend(_calmSoloIndoor(), context: _ctx).first.activity.id;
      final next = _engine.recommend(
        _calmSoloIndoor(),
        context: _ctx,
        excludedIds: {first},
      );
      expect(next.every((r) => r.activity.id != first), isTrue);
    });
  });

  group('revealed preference (controller)', () {
    test('a Pas-pour-moi removes the pick and re-ranks to a new one', () {
      final reco = RecoController(
        profile: _calmSoloIndoor(),
        engine: _engine,
        context: _ctx,
      );
      final before = reco.current!.activity.id;
      reco.dislike();
      final after = reco.current!.activity.id;
      expect(after, isNot(before));
      // The disliked activity must not resurface.
      expect(reco.ranked.every((r) => r.activity.id != before), isTrue);
    });

    test("a J'aime records the like and moves on", () {
      final reco = RecoController(
        profile: _calmSoloIndoor(),
        engine: _engine,
        context: _ctx,
      );
      final liked = reco.current!.activity.id;
      reco.like();
      expect(reco.liked.map((a) => a.id), contains(liked));
      expect(reco.current?.activity.id, isNot(liked));
    });

    test('repeated likes eventually exhaust the session', () {
      final reco = RecoController(
        profile: _livelySocialOutdoor(),
        engine: _engine,
        context: _ctx,
      );
      var guard = 0;
      while (!reco.isExhausted && guard < 100) {
        reco.like();
        guard++;
      }
      expect(reco.isExhausted, isTrue);
      expect(reco.current, isNull);
    });

    test('likes nudge the profile toward the liked activity axes', () {
      final profile = _calmSoloIndoor();
      final reco =
          RecoController(profile: profile, engine: _engine, context: _ctx);
      final pick = reco.current!.activity;
      final dim = Dimension.energy;
      final before = profile.valueOf(dim);
      reco.like();
      // Profile value should move toward the picked activity's energy tag.
      final moved = (profile.valueOf(dim) - pick.tag(dim)).abs() <
          (before - pick.tag(dim)).abs() + 1e-9;
      expect(moved, isTrue);
    });
  });
}
