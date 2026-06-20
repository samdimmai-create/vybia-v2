// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Browser geolocation via the Geolocation API. Returns null on denial /
/// timeout / no support — the caller then falls back to Montréal centre.
Future<(double, double)?> getCurrentPosition() async {
  final geo = html.window.navigator.geolocation;
  try {
    final pos = await geo.getCurrentPosition(
      enableHighAccuracy: false,
      timeout: const Duration(seconds: 8),
      maximumAge: const Duration(minutes: 5),
    );
    final coords = pos.coords;
    final lat = coords?.latitude?.toDouble();
    final lng = coords?.longitude?.toDouble();
    if (lat == null || lng == null) return null;
    return (lat, lng);
  } catch (_) {
    return null;
  }
}
