import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/core/geo/geo.dart';
import 'package:vybia_v2/core/geo/location_service.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/reco/engine/recommendation_engine.dart';
import 'package:vybia_v2/features/reco/engine/reco_context.dart';
import 'package:vybia_v2/features/reco/model/activity.dart';

const _ctxTime = (hour: 14, month: 6);

Activity _act(String id, double lat, double lng) => Activity(
      id: id,
      titleFr: id,
      category: ActivityCategory.cafe,
      tags: const {
        Dimension.energy: 0.5,
        Dimension.social: 0.5,
        Dimension.novelty: 0.5,
        Dimension.distance: 0.5,
        Dimension.indoor: 0.5,
        Dimension.timing: 0.5,
        Dimension.budget: 0.3,
        Dimension.vibe: 0.5,
      },
      motives: (hedonic: 0.5, relaxation: 0.5, eudaimonic: 0.5),
      budget: 1,
      indoor: true,
      descFr: id,
      lat: lat,
      lng: lng,
      image: 'x',
    );

void main() {
  group('haversine + formatting', () {
    test('haversine is ~0 for identical points and grows with distance', () {
      expect(haversineKm(45.5, -73.6, 45.5, -73.6), closeTo(0, 1e-6));
      // ~1.11 km per 0.01° of latitude.
      expect(haversineKm(45.50, -73.6, 45.51, -73.6), closeTo(1.11, 0.1));
    });

    test('distance/eta formatting is French and sensible', () {
      expect(formatDistance(0.4), 'à 400 m');
      expect(formatDistance(2.3), 'à 2,3 km');
      expect(formatEta(0.5), startsWith('~'));
    });
  });

  group('geolocation fallback', () {
    test('GeoResult.fallback is Montréal centre and not a real fix', () {
      expect(GeoResult.fallback.lat, kMontrealLat);
      expect(GeoResult.fallback.lng, kMontrealLng);
      expect(GeoResult.fallback.isReal, isFalse);
    });

    test('LocationService falls back to Montréal centre off-web (no fix)',
        () async {
      // In the Dart VM test host there is no browser geolocation → fallback.
      final r = await const LocationService().locate();
      expect(r.isReal, isFalse);
      expect(r.lat, kMontrealLat);
      expect(r.lng, kMontrealLng);
    });
  });

  group('distance-aware ranking', () {
    final engine = RecommendationEngine(catalog: [
      _act('near_downtown', 45.5019, -73.5674),
      _act('far_north', 45.58, -73.62),
    ]);

    test('the nearer place ranks first, and ranking flips with location', () {
      final near = engine.recommend(
        GuestProfile(),
        context: RecoContext(
          hourOfDay: _ctxTime.hour,
          month: _ctxTime.month,
          userLat: 45.5019,
          userLng: -73.5674,
        ),
      );
      expect(near.first.activity.id, 'near_downtown');
      expect(near.first.distanceKm, closeTo(0, 0.2));

      final north = engine.recommend(
        GuestProfile(),
        context: RecoContext(
          hourOfDay: _ctxTime.hour,
          month: _ctxTime.month,
          userLat: 45.58,
          userLng: -73.62,
        ),
      );
      expect(north.first.activity.id, 'far_north'); // location flipped ranking
    });
  });

  test('feasibility drops places well out of the region (>25 km)', () {
    // Enough in-city options so the "never starve the scene" guard (which falls
    // back to the full pool when <4 are feasible) doesn't re-admit the far one.
    final engine = RecommendationEngine(catalog: [
      _act('in_city_1', 45.5019, -73.5674),
      _act('in_city_2', 45.5119, -73.5774),
      _act('in_city_3', 45.4919, -73.5574),
      _act('in_city_4', 45.5219, -73.5874),
      _act('in_city_5', 45.4819, -73.5474),
      _act('way_out', 46.8, -71.2), // ~250 km (Québec City)
    ]);
    final recs = engine.recommend(
      GuestProfile(),
      context: RecoContext(
        hourOfDay: 14,
        month: 6,
        userLat: 45.5019,
        userLng: -73.5674,
      ),
    );
    expect(recs.any((r) => r.activity.id == 'way_out'), isFalse);
  });
}
