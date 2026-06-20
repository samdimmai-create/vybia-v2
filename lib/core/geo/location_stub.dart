/// Non-web fallback: no native geolocation is wired (the iOS simulator has no
/// fix), so the caller falls back to Montréal centre. Web uses location_web.dart.
Future<(double, double)?> getCurrentPosition() async => null;
