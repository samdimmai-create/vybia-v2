import '../../../core/geo/geo.dart';

/// Ambient context the engine folds into scoring: time of day and season.
///
/// Injected (rather than read from the clock inside the engine) so tests are
/// fully deterministic. [evening] and [winter] are the only two facts scoring
/// needs today; more (weather, day-of-week) can join later without touching
/// call sites that use [RecoContext.now].
class RecoContext {
  const RecoContext({
    required this.hourOfDay,
    required this.month,
    this.userLat,
    this.userLng,
  });

  /// 0..23 local hour.
  final int hourOfDay;

  /// 1..12 calendar month.
  final int month;

  /// The guest's location (S7C). Null until resolved; the reco loop defaults it
  /// to the Montréal-centre fallback so distances always render.
  final double? userLat;
  final double? userLng;

  factory RecoContext.now({DateTime? clock, double? userLat, double? userLng}) {
    final t = clock ?? DateTime.now();
    return RecoContext(
      hourOfDay: t.hour,
      month: t.month,
      userLat: userLat,
      userLng: userLng,
    );
  }

  RecoContext withUser(double lat, double lng) => RecoContext(
        hourOfDay: hourOfDay,
        month: month,
        userLat: lat,
        userLng: lng,
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
