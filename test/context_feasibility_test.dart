import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/guest/model/life_context.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/engine/recommendation_engine.dart';
import 'package:vybia_v2/features/reco/engine/reco_context.dart';
import 'package:vybia_v2/features/reco/model/activity.dart';

const _engine = RecommendationEngine(catalog: kActivityCatalog);

// Montréal centre, so the catalog's real coordinates resolve to sane distances.
const _lat = 45.5019;
const _lng = -73.5674;

RecoContext _ctx({WeatherSignal? weather}) => RecoContext(
      hourOfDay: 14,
      month: 6,
      userLat: _lat,
      userLng: _lng,
      weather: weather,
    );

/// Leans toward the open air but NOT confidently, so indoor venues stay
/// feasible — otherwise a confident outdoor preference would itself filter
/// indoor out, and rain would starve the pool (the guard would then relax).
GuestProfile _outdoorsy() {
  final p = GuestProfile();
  p.nudge(Dimension.indoor, 0.2, weight: 0.3); // soft open-air lean
  p.answer(Dimension.energy, 0.55);
  return p;
}

void main() {
  group('S11C — weather feasibility (hard filter, only when signalled)', () {
    test('no weather signal → outdoor picks are still allowed (noted seam)', () {
      final recs = _engine.recommend(_outdoorsy(), context: _ctx());
      final outdoor = recs.where((r) => !r.activity.indoor).length;
      expect(outdoor, greaterThan(0),
          reason: 'with no signal the weather filter must not fire');
    });

    test('wet weather hard-filters every open-air activity out', () {
      for (final w in [WeatherSignal.rain, WeatherSignal.snow]) {
        final recs =
            _engine.recommend(_outdoorsy(), context: _ctx(weather: w));
        // The starve-guard may relax soft fit, but it must never KEEP an outdoor
        // pick when there are enough indoor options to fill the batch.
        final indoorPool =
            kActivityCatalog.where((a) => a.indoor).length;
        if (indoorPool >= 4) {
          expect(recs.every((r) => r.activity.indoor), isTrue,
              reason: 'wet weather ($w) should leave only indoor picks');
        }
      }
    });

    test('deep cold hard-filters non-winter-friendly outdoor activities', () {
      final recs =
          _engine.recommend(_outdoorsy(), context: _ctx(weather: WeatherSignal.cold));
      final badColdOutdoor = recs.where(
          (r) => !r.activity.indoor && !r.activity.winterFriendly);
      expect(badColdOutdoor, isEmpty);
    });

    test('clear weather keeps outdoor picks available', () {
      final recs =
          _engine.recommend(_outdoorsy(), context: _ctx(weather: WeatherSignal.clear));
      expect(recs.any((r) => !r.activity.indoor), isTrue);
    });
  });

  group('S11C — starve-guard never blanks the scene', () {
    test('a pile-up of contexts still returns recommendations', () {
      final p = _outdoorsy()
        ..setContext(LifeContext.avecEnfants, true)
        ..setContext(LifeContext.sansAlcool, true)
        ..setContext(LifeContext.budgetSerre, true)
        ..setContext(LifeContext.mobiliteReduite, true);
      final recs = _engine.recommend(p, context: _ctx(weather: WeatherSignal.snow));
      expect(recs, isNotEmpty);
    });
  });

  group('S11C — life-context hard filters still hold', () {
    test('sans alcool removes alcohol-serving venues', () {
      final p = GuestProfile()..setContext(LifeContext.sansAlcool, true);
      final recs = _engine.recommend(p, context: _ctx());
      expect(recs.every((r) => r.activity.category != ActivityCategory.nightlife),
          isTrue);
    });
  });
}
