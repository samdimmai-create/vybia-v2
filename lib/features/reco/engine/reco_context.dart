import '../../../core/geo/geo.dart';

/// A coarse current-weather signal (S11C). Deliberately optional: Vybia ships
/// with NO runtime network in the deterministic brain, so unless a caller
/// injects a real reading this stays null and the weather feasibility filter is
/// skipped (a noted seam — wire a free weather source here to switch it on).
enum WeatherSignal {
  clear,
  rain,
  snow,
  cold;

  /// Wet weather that makes an open-air outing infeasible.
  bool get isWet => this == rain || this == snow;
}

/// Ambient context the engine folds into scoring: time of day, season and
/// (optionally) weather.
///
/// Injected (rather than read from the clock inside the engine) so tests are
/// fully deterministic. [evening], [winter] and the optional [weather] are the
/// facts scoring + feasibility need today; more (day-of-week) can join later
/// without touching call sites that use [RecoContext.now].
class RecoContext {
  const RecoContext({
    required this.hourOfDay,
    required this.month,
    this.userLat,
    this.userLng,
    this.weather,
  });

  /// 0..23 local hour.
  final int hourOfDay;

  /// 1..12 calendar month.
  final int month;

  /// The guest's location (S7C). Null until resolved; the reco loop defaults it
  /// to the Montréal-centre fallback so distances always render.
  final double? userLat;
  final double? userLng;

  /// Current weather (S11C), or null when no signal is available — in which case
  /// the weather feasibility filter is skipped entirely.
  final WeatherSignal? weather;

  factory RecoContext.now({
    DateTime? clock,
    double? userLat,
    double? userLng,
    WeatherSignal? weather,
  }) {
    final t = clock ?? DateTime.now();
    return RecoContext(
      hourOfDay: t.hour,
      month: t.month,
      userLat: userLat,
      userLng: userLng,
      weather: weather,
    );
  }

  RecoContext withUser(double lat, double lng) => RecoContext(
        hourOfDay: hourOfDay,
        month: month,
        userLat: lat,
        userLng: lng,
        weather: weather,
      );

  /// Fold in a freshly fetched weather signal (S12B) — null clears it, which
  /// leaves the weather feasibility filter skipped exactly as before.
  RecoContext withWeather(WeatherSignal? signal) => RecoContext(
        hourOfDay: hourOfDay,
        month: month,
        userLat: userLat,
        userLng: userLng,
        weather: signal,
      );

  bool get hasUser => userLat != null && userLng != null;

  /// Haversine distance (km) from the user to a place, or null if unknown.
  double? distanceKmTo(double lat, double lng) =>
      hasUser ? haversineKm(userLat!, userLng!, lat, lng) : null;

  /// Evening starts at 18:00 — drives the timing-fit term.
  bool get evening => hourOfDay >= 18 || hourOfDay < 5;

  /// Montréal winter (Dec–Feb) — softly penalizes non-winter-friendly outdoors.
  bool get winter => month == 12 || month == 1 || month == 2;

  /// Smooth 0..1 "eveningness" used to match against an activity's timing tag.
  double get eveningness {
    // Peaks late evening, troughs midday. Cheap cosine-free ramp.
    if (hourOfDay >= 18) return 1.0;
    if (hourOfDay < 5) return 0.9;
    if (hourOfDay < 11) return 0.2;
    return 0.45; // afternoon — neutral-ish
  }
}
