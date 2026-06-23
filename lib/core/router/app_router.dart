import 'package:flutter/material.dart';

import '../../features/demo/orb_demo_screen.dart';
import '../../features/demo/orb_preview_screen.dart';
import '../../features/demo/refraction_demo_screen.dart';
import '../../features/dev/dev_menu_screen.dart';
import '../../features/dev/edge_decisive_demo_screen.dart';
import '../../features/guest/screens/accueil_screen.dart';
import '../../features/guest/screens/discover_screen.dart';
import '../../features/guest/screens/engine_loop_screen.dart';
import '../../features/guest/screens/intention_screen.dart';
import '../../features/guest/screens/profile_ready_screen.dart';
import '../../features/guest/screens/splash_screen.dart';
import '../../features/guest/screens/welcome_screen.dart';
import '../../features/plans/screens/mes_plans_screen.dart';
import '../../features/plans/screens/planifier_screen.dart';
import '../../features/plans/screens/recap_screen.dart';
import '../../features/profile/screens/profil_screen.dart';
import '../../features/reco/live/live_availability_service.dart';
import '../../features/reco/live/weather_service.dart';
import '../../features/reco/screens/reco_screen.dart';

/// Central route table. Kept tiny; every screen is reachable directly (handy
/// for visual tests via `/#<route>` and the hidden `/dev` menu).
/// One shared LIVE availability layer (S10.1B) for the whole app, so the events/
/// films fetched on the reco path are cached once per session and reused. Only
/// the real app touches this (via the router); widget tests build screens
/// directly with `liveService: null` → fully offline.
final LiveAvailabilityService _liveService = LiveAvailabilityService.standard();

/// One shared keyless weather source (S12B): fetched once per coarse location and
/// reused across the session so the reco rounds reflect the real sky.
final WeatherService _weatherService = WeatherService();

class AppRouter {
  AppRouter._();

  // Guest loop.
  static const String splash = '/';
  static const String accueil = '/accueil';
  static const String welcome = '/welcome';
  static const String discover = '/discover';
  static const String engine = '/engine'; // S9B: the adaptive question↔reco loop
  static const String intention = '/intention';
  static const String profileReady = '/profil-pret';
  static const String reco = '/reco';
  static const String plan = '/plan';
  static const String recap = '/recap'; // S19D: recap/confirm before saving a plan
  static const String mesPlans = '/mes-plans';
  static const String profil = '/profil';

  // Hidden dev + component demos.
  static const String dev = '/dev';
  static const String bubble = '/bubble';
  static const String orbPreview = '/orb';
  static const String orbDemo = '/orb-demo';
  static const String edgeDemo = '/edge-demo';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case accueil:
        page = const AccueilScreen();
      case welcome:
        page = const WelcomeScreen();
      case discover:
        page = const DiscoverScreen();
      case engine:
        page = EngineLoopScreen(
          liveService: _liveService,
          weatherService: _weatherService,
        );
      case intention:
        page = const IntentionScreen();
      case profileReady:
        page = const ProfileReadyScreen();
      case reco:
        page = RecoScreen(
          liveService: _liveService,
          weatherService: _weatherService,
        );
      case plan:
        page = PlanifierScreen.fromRoute(settings);
      case recap:
        page = RecapScreen.fromRoute(settings);
      case mesPlans:
        page = const MesPlansScreen();
      case profil:
        page = const ProfilScreen();
      case dev:
        page = const DevMenuScreen();
      case bubble:
        page = const RefractionDemoScreen();
      case orbPreview:
        page = const OrbPreviewScreen();
      case orbDemo:
        page = const OrbDemoScreen();
      case edgeDemo:
        page = const EdgeDecisiveDemoScreen();
      case splash:
      default:
        page = const SplashScreen();
    }
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
