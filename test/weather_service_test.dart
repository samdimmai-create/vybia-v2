import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/engine/recommendation_engine.dart';
import 'package:vybia_v2/features/reco/engine/reco_context.dart';
import 'package:vybia_v2/features/reco/live/live_source.dart';
import 'package:vybia_v2/features/reco/live/weather_service.dart';

/// S12B — live weather (Open-Meteo, keyless): the WMO-code mapping is pure +
/// tested, the service degrades offline to null (filter stays skipped), and the
/// SAME context flips its feasible set from clear to rainy weather.
void main() {
  HttpGet fixed(String? body) =>
      (Uri _, {Duration timeout = Duration.zero}) async => body;

  String omBody({required int code, required double temp}) => jsonEncode({
        'current': {
          'temperature_2m': temp,
          'precipitation': 0,
          'weather_code': code,
        },
      });

  group('WeatherService.signalFrom (pure WMO mapping)', () {
    test('snow codes → snow (takes precedence over cold)', () {
      for (final c in [71, 73, 75, 77, 85, 86]) {
        expect(WeatherService.signalFrom(code: c, tempC: -20),
            WeatherSignal.snow);
      }
    });
    test('rain/drizzle/showers/thunderstorm codes → rain', () {
      for (final c in [51, 61, 63, 67, 80, 82, 95, 99]) {
        expect(WeatherService.signalFrom(code: c, tempC: 5), WeatherSignal.rain);
      }
    });
    test('clear sky but deep cold → cold', () {
      expect(WeatherService.signalFrom(code: 0, tempC: -15), WeatherSignal.cold);
    });
    test('clear + mild → clear', () {
      expect(WeatherService.signalFrom(code: 1, tempC: 18), WeatherSignal.clear);
    });
    test('nothing to go on → null (filter stays skipped)', () {
      expect(WeatherService.signalFrom(), isNull);
    });
  });

  group('WeatherService fetch', () {
    test('parses Open-Meteo current → rain signal, caches per location',
        () async {
      var calls = 0;
      final svc = WeatherService(httpGet: (uri, {timeout = Duration.zero}) async {
        calls++;
        return omBody(code: 61, temp: 9);
      });
      final s1 = await svc.currentSignal(45.50, -73.56);
      final s2 = await svc.currentSignal(45.50, -73.56); // same coarse loc
      expect(s1, WeatherSignal.rain);
      expect(s2, WeatherSignal.rain);
      expect(calls, 1, reason: 'session cache → one fetch per coarse location');
      expect(svc.lastState, WeatherFetchState.ok);
    });

    test('offline → null signal, state offline (never throws)', () async {
      final svc = WeatherService(httpGet: fixed(null));
      expect(await svc.currentSignal(45.5, -73.5), isNull);
      expect(svc.lastState, WeatherFetchState.offline);
    });

    test('garbage body → null, no crash', () async {
      final svc = WeatherService(httpGet: fixed('<<not json>>'));
      expect(await svc.currentSignal(45.5, -73.5), isNull);
    });
  });

  group('weather flips feasibility on the SAME context', () {
    const engine = RecommendationEngine(catalog: kActivityCatalog);
    RecoContext ctx(WeatherSignal? w) => RecoContext(
          hourOfDay: 14,
          month: 6,
          userLat: 45.5019,
          userLng: -73.5674,
          weather: w,
        );
    GuestProfile outdoorsy() {
      final p = GuestProfile();
      p.nudge(Dimension.indoor, 0.2, weight: 0.3);
      p.answer(Dimension.energy, 0.55);
      return p;
    }

    test('clear keeps open-air; rain drops it', () {
      final clear = engine.recommend(outdoorsy(), context: ctx(WeatherSignal.clear));
      final rain = engine.recommend(outdoorsy(), context: ctx(WeatherSignal.rain));
      expect(clear.any((r) => !r.activity.indoor), isTrue,
          reason: 'clear weather keeps at least one open-air pick');
      final indoorPool = kActivityCatalog.where((a) => a.indoor).length;
      if (indoorPool >= 4) {
        expect(rain.every((r) => r.activity.indoor), isTrue,
            reason: 'rain removes open-air picks → strictly smaller feasible set');
      }
    });
  });
}
