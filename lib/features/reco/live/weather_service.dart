import 'dart:convert';

import '../engine/reco_context.dart';
import 'live_source.dart';

/// How the last weather fetch went — surfaced for the report/proof.
enum WeatherFetchState {
  /// Got a reading and derived a signal.
  ok,

  /// Reachable but the reading didn't warrant a feasibility-changing signal
  /// (clear-ish, mild) — still a real fetch.
  clear,

  /// Unreachable / timed out → no signal → S11's weather filter stays skipped.
  offline,
}

/// KEYLESS live weather via Open-Meteo (S12B) — switches ON the S11 weather
/// feasibility seam.
///
/// Open-Meteo is a free, open, NO-KEY API. This service reads the CURRENT
/// conditions for a lat/lng and maps them to the engine's coarse [WeatherSignal]
/// (clear / rain / snow / cold). It is SAFE the same way the other live sources
/// are: a SHORT timeout, a session cache (one fetch per coarse location), and an
/// OFFLINE FALLBACK — on any failure it returns null, which leaves the weather
/// filter SKIPPED exactly as designed (the app stays fully usable offline on the
/// static catalog). Runtime network here is allowed because this is the live
/// layer; the deterministic brain still never reaches out on its own.
class WeatherService {
  WeatherService({HttpGet? httpGet, this.endpoint = _endpoint})
      : _get = httpGet ?? httpGetDefault;

  static const String _endpoint = 'https://api.open-meteo.com/v1/forecast';

  /// Deep-cold threshold (°C): below this, non-winter-friendly OUTDOOR activities
  /// become infeasible (the S11C `cold` rule). Montréal routinely hits this.
  static const double coldThresholdC = -10.0;

  final HttpGet _get;
  final String endpoint;

  WeatherSignal? _cachedSignal;
  String? _cacheKey;
  WeatherFetchState _lastState = WeatherFetchState.offline;

  /// State of the last [currentSignal] call (for the report/proof).
  WeatherFetchState get lastState => _lastState;

  /// The current weather signal for [lat]/[lng], or null when no usable reading
  /// is available (offline / error) — null KEEPS the weather filter skipped.
  /// Cached for the session per coarse location so we fetch once.
  Future<WeatherSignal?> currentSignal(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
    if (_cacheKey == key) return _cachedSignal;

    final body = await _get(_uriFor(lat, lng), timeout: const Duration(seconds: 5));
    if (body == null) {
      _lastState = WeatherFetchState.offline;
      return null; // offline → no signal → filter stays skipped (by design)
    }
    final signal = _parse(body);
    _cachedSignal = signal;
    _cacheKey = key;
    return signal;
  }

  Uri _uriFor(double lat, double lng) =>
      Uri.parse(endpoint).replace(queryParameters: {
        'latitude': lat.toStringAsFixed(4),
        'longitude': lng.toStringAsFixed(4),
        'current': 'temperature_2m,precipitation,weather_code',
        'timezone': 'auto',
      });

  WeatherSignal? _parse(String body) {
    try {
      final decoded = jsonDecode(body);
      final current = decoded is Map ? decoded['current'] : null;
      if (current is! Map) {
        _lastState = WeatherFetchState.offline;
        return null;
      }
      final code = (current['weather_code'] as num?)?.toInt();
      final tempC = (current['temperature_2m'] as num?)?.toDouble();
      final signal = signalFrom(code: code, tempC: tempC);
      _lastState = signal == WeatherSignal.clear || signal == null
          ? WeatherFetchState.clear
          : WeatherFetchState.ok;
      return signal;
    } catch (_) {
      _lastState = WeatherFetchState.offline;
      return null;
    }
  }

  /// Map a WMO [weather code](https://open-meteo.com/en/docs) + temperature to
  /// the engine's coarse [WeatherSignal]. PURE + static, so the mapping is
  /// unit-tested without any network. Precedence: snow → rain → deep cold →
  /// clear. Returns null only when there's nothing to go on.
  static WeatherSignal? signalFrom({int? code, double? tempC}) {
    if (code != null) {
      if (_isSnow(code)) return WeatherSignal.snow;
      if (_isWet(code)) return WeatherSignal.rain;
    }
    if (tempC != null && tempC <= coldThresholdC) return WeatherSignal.cold;
    if (code == null && tempC == null) return null;
    return WeatherSignal.clear;
  }

  // WMO snow / snow-grains / snow-showers.
  static bool _isSnow(int c) =>
      c == 71 || c == 73 || c == 75 || c == 77 || c == 85 || c == 86;

  // WMO drizzle (51–57), rain (61–67), rain-showers (80–82), thunderstorm (95–99).
  static bool _isWet(int c) =>
      (c >= 51 && c <= 67) || (c >= 80 && c <= 82) || (c >= 95 && c <= 99);
}
