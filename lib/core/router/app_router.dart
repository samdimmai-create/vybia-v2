import 'package:flutter/material.dart';

import '../../features/demo/orb_demo_screen.dart';
import '../../features/demo/orb_preview_screen.dart';
import '../../features/demo/refraction_demo_screen.dart';
import '../../features/dev/dev_menu_screen.dart';
import '../../features/guest/screens/discover_screen.dart';
import '../../features/guest/screens/intention_screen.dart';
import '../../features/guest/screens/profile_ready_screen.dart';
import '../../features/guest/screens/splash_screen.dart';
import '../../features/guest/screens/welcome_screen.dart';

/// Central route table. Kept tiny; every screen is reachable directly (handy
/// for visual tests via `/#<route>` and the hidden `/dev` menu).
class AppRouter {
  AppRouter._();

  // Guest loop.
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String discover = '/discover';
  static const String intention = '/intention';
  static const String profileReady = '/profil-pret';

  // Hidden dev + component demos.
  static const String dev = '/dev';
  static const String bubble = '/bubble';
  static const String orbPreview = '/orb';
  static const String orbDemo = '/orb-demo';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case welcome:
        page = const WelcomeScreen();
      case discover:
        page = const DiscoverScreen();
      case intention:
        page = const IntentionScreen();
      case profileReady:
        page = const ProfileReadyScreen();
      case dev:
        page = const DevMenuScreen();
      case bubble:
        page = const RefractionDemoScreen();
      case orbPreview:
        page = const OrbPreviewScreen();
      case orbDemo:
        page = const OrbDemoScreen();
      case splash:
      default:
        page = const SplashScreen();
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
