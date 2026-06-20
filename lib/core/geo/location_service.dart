import 'geo.dart';
import 'location_stub.dart' if (dart.library.html) 'location_web.dart' as impl;

/// Guest-friendly geolocation. Requested AFTER the guest has seen value (never a
/// hard gate). Always resolves — a real fix when granted, otherwise the
/// Montréal-centre fallback — so the recommendation flow never blocks.
class LocationService {
  const LocationService();

  Future<GeoResult> locate() async {
    try {
      final pos = await impl.getCurrentPosition();
      if (pos != null) {
        return GeoResult(pos.$1, pos.$2, GeoStatus.granted);
      }
    } catch (_) {
      // fall through to the fallback
    }
    return GeoResult.fallback;
  }
}
