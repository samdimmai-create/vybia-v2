import 'package:flutter/material.dart';

import '../../features/demo/orb_demo_screen.dart';
import '../../features/demo/orb_preview_screen.dart';
import '../../features/demo/refraction_demo_screen.dart';

/// Minimal route table. Kept tiny and centralized so future features (welcome,
/// explore, plan, profile) slot in without touching main.dart.
class AppRouter {
  AppRouter._();

  static const String demo = '/';
  static const String orbPreview = '/orb';
  static const String bubble = '/bubble';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case orbPreview:
        return MaterialPageRoute(
          builder: (_) => const OrbPreviewScreen(),
          settings: settings,
        );
      case bubble:
        return MaterialPageRoute(
          builder: (_) => const RefractionDemoScreen(),
          settings: settings,
        );
      case demo:
      default:
        return MaterialPageRoute(
          builder: (_) => const OrbDemoScreen(),
          settings: settings,
        );
    }
  }
}
