import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/engine/recommendation_engine.dart';
import 'package:vybia_v2/features/reco/engine/reco_context.dart';
import 'package:vybia_v2/features/reco/model/activity.dart';
import 'package:vybia_v2/features/reco/model/motive.dart';

const _engine = RecommendationEngine(catalog: kActivityCatalog);
const _ctx = RecoContext(hourOfDay: 14, month: 6);

const MotiveAffinity _motive =
    (hedonic: 0.5, relaxation: 0.5, eudaimonic: 0.5);

/// A neutral profile that isn't novelty-averse (so serendipity applies).
GuestProfile _neutralOpen() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.5);
  p.answer(Dimension.novelty, 0.55);
  return p;
}

GuestProfile _noveltyAverse() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.3);
  p.answer(Dimension.novelty, 0.05); // confidently wants the familiar
  return p;
}

/// Two cafés on the same block + a couple of other categories, to exercise the
/// near-duplicate-venue guard.
Activity _cafe(String id, double lat, double lng, {double novelty = 0.3}) =>
    Activity(
      id: id,
      titleFr: 'Café $id',
      category: ActivityCategory.cafe,
      tags: {
        Dimension.energy: 0.3,
        Dimension.social: 0.5,
        Dimension.novelty: novelty,
        Dimension.distance: 0.2,
        Dimension.indoor: 0.8,
        Dimension.timing: 0.3,
        Dimension.budget: 0.3,
        Dimension.vibe: 0.4,
      },
      motives: _motive,
      budget: 1,
      indoor: true,
      descFr: 'café',
      lat: lat,
      lng: lng,
      image: 'assets/images/places/cafe.jpg',
    );

void main() {
  group('S9E — dosed serendipity', () {
    test('a non-averse profile always gets at least one discovery in the batch',
        () {
      final recs = _engine.recommend(_neutralOpen(), context: _ctx);
      final hasDiscovery =
          recs.skip(1).any((r) => r.activity.tag(Dimension.novelty) >= 0.7);
      expect(hasDiscovery, isTrue,
          reason: 'the alternatives should carry a controlled surprise');
    });

    test('a confidently novelty-averse guest is NOT forced a discovery', () {
      final recs = _engine.recommend(_noveltyAverse(), context: _ctx);
      // Not a hard guarantee of zero, but the lead must not be a high-novelty
      // pick for someone who confidently wants the familiar.
      expect(recs.first.activity.tag(Dimension.novelty) < 0.7, isTrue);
    });

    test('the global best pick still leads (serendipity never steals the top)',
        () {
      final recs = _engine.recommend(_neutralOpen(), context: _ctx);
      expect(recs.first.isBestPick, isTrue);
      for (final r in recs.skip(1)) {
        expect(recs.first.score, greaterThanOrEqualTo(r.score));
      }
    });
  });

  group('S9E — near-duplicate venue guard', () {
    test('two cafés on the same block never both appear', () {
      final catalog = [
        _cafe('a', 45.5230, -73.6000), // ~120m apart → duplicates
        _cafe('b', 45.5232, -73.6001),
        // a few non-café options so the batch can fill without the clone
        ...kActivityCatalog.where((a) => a.category != ActivityCategory.cafe),
      ];
      final engine = RecommendationEngine(catalog: catalog);
      final recs = engine.recommend(_neutralOpen(), context: _ctx);
      final cafes =
          recs.where((r) => r.activity.category == ActivityCategory.cafe).length;
      expect(cafes, lessThanOrEqualTo(1),
          reason: 'near-duplicate cafés must be de-duplicated');
    });
  });

  group('S9E — formula stays well-behaved', () {
    test('still 4–6 ranked recs, best first, deterministic', () {
      final a = _engine.recommend(_neutralOpen(), context: _ctx);
      final b = _engine.recommend(_neutralOpen(), context: _ctx);
      expect(a.length, inInclusiveRange(4, 6));
      expect(a.first.activity.id, b.first.activity.id);
      expect(a.first.score, b.first.score);
    });
  });
}
