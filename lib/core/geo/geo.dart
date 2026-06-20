import 'dart:math' as math;

/// Montréal city centre — the deterministic fallback whenever real geolocation
/// is denied, unavailable, or the iOS simulator has no location fix. The app
/// never blocks on location: it proceeds from here.
const double kMontrealLat = 45.5019;
const double kMontrealLng = -73.5674;

/// Outcome of a geolocation attempt.
enum GeoStatus { granted, denied, unavailable }

/// A resolved location plus how we got it. [isReal] is true only for a genuine
/// device/browser fix; otherwise these are the Montréal-centre fallback coords.
class GeoResult {
  const GeoResult(this.lat, this.lng, this.status);

  final double lat;
  final double lng;
  final GeoStatus status;

  bool get isReal => status == GeoStatus.granted;

  /// Montréal centre fallback — used on denial / unavailable / no fix.
  static const GeoResult fallback =
      GeoResult(kMontrealLat, kMontrealLng, GeoStatus.unavailable);

  static GeoResult denied() =>
      const GeoResult(kMontrealLat, kMontrealLng, GeoStatus.denied);

  Map<String, dynamic> toJson() =>
      {'lat': lat, 'lng': lng, 'status': status.name};

  static GeoResult? fromJson(Map<String, dynamic> j) {
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    GeoStatus status = GeoStatus.unavailable;
    for (final s in GeoStatus.values) {
      if (s.name == j['status']) status = s;
    }
    return GeoResult(lat, lng, status);
  }
}

/// Great-circle distance in kilometres between two lat/lng points (haversine).
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthKm = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double deg) => deg * math.pi / 180.0;

/// "à 750 m" / "à 2,3 km" — French, no trailing-zero noise.
String formatDistance(double km) {
  if (km < 1.0) return 'à ${(km * 1000).round()} m';
  return 'à ${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Rough Montréal travel estimate: a short hop is a walk (~13 min/km), anything
/// further reads as transit (~4 min/km + a 6 min base).
String formatEta(double km) {
  final mins = km <= 1.2 ? (km * 13).round() : (km * 4).round() + 6;
  return '~$mins min';
}

/// Combined card label, e.g. "à 2,3 km · ~15 min".
String formatDistanceEta(double km) => '${formatDistance(km)} · ${formatEta(km)}';
