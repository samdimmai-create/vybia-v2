import 'package:flutter/material.dart';

import 'core/persistence/app_store.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/dev/s8_1_proof_tour.dart';
import 'features/dev/s8_proof_tour.dart';
import 'features/dev/s9_1_engine_proof_tour.dart';
import 'features/dev/s9_2_proof_tour.dart';
import 'features/dev/s9_3_proof_tour.dart';
import 'features/dev/s10_1_proof_tour.dart';
import 'features/dev/s10_proof_tour.dart';
import 'features/dev/s11_proof_tour.dart';
import 'features/dev/s12_proof_tour.dart';
import 'features/guest/state/guest_controller.dart';
import 'features/plans/state/plan_controller.dart';

/// Root application widget. Wires the theme + router and hosts the single
/// shared [GuestController] above the navigator (via [GuestScope]) so every
/// guest screen reads and advances the same session. The shared [AppStore]
/// (loaded in main before first paint) is threaded into the controllers so the
/// whole guest model persists across relaunches.
class VybiaApp extends StatefulWidget {
  const VybiaApp({super.key, this.store});

  /// Local persistence repository. Null in lightweight widget tests (in-memory).
  final AppStore? store;

  /// App-level navigator key. Lets the immersive flows (and visible tests) push
  /// routes without threading a context, and keeps a single source of truth for
  /// navigation above the route stack.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<VybiaApp> createState() => _VybiaAppState();
}

class _VybiaAppState extends State<VybiaApp> {
  late final GuestController _guest = GuestController(store: widget.store);
  late final PlanController _plans = PlanController(store: widget.store);

  // Debug-only visual-proof tour: with `--dart-define=VYBIA_AUTODRIVE=true` the
  // app walks reco → welcome → profil via the navigator (no pointer), so the
  // universal bubble can be screenshotted on every image in a single run,
  // crosshair-free. Each hop prints `VYBIA_SCENE <name>` for the capture script.
  static const bool _kAutoDrive = bool.fromEnvironment('VYBIA_AUTODRIVE');

  // When a single start route is pinned (`--dart-define=VYBIA_START=/reco`) the
  // multi-scene hop tour is skipped so the app stays on that one scene — the
  // scene's own orb autodrive still runs. This makes single-route proof
  // captures deterministic (no 42s scene-hop racing the screenshot).
  static const String _kStart = String.fromEnvironment('VYBIA_START');

  // Debug-only S8 visual-proof tour (calm accueil + hold portal + throw +
  // category-accurate reco images). `--dart-define=VYBIA_PROOF=true`.
  static const bool _kProof = bool.fromEnvironment('VYBIA_PROOF');

  // Debug-only S8.1 visual-proof tour (smaller orb + radial edge-wave + bottom
  // bubble + reflection transition + hold states). `--dart-define=VYBIA_PROOF81=true`.
  static const bool _kProof81 = bool.fromEnvironment('VYBIA_PROOF81');

  // S9.1: VISIBLE-IN-CHROME proof tour of the adaptive engine LOOP
  // (`--dart-define=VYBIA_PROOF91=true`). Keeps the router so the loop's
  // Planifier handoff to /plan works.
  static const bool _kProof91 = bool.fromEnvironment('VYBIA_PROOF91');

  // S9.2: VISIBLE-IN-CHROME proof of the now-TRANSPARENT bottom description
  // bubble (`--dart-define=VYBIA_PROOF92=true`): image stays fully visible
  // behind the floating text at rest, gone on contact.
  static const bool _kProof92 = bool.fromEnvironment('VYBIA_PROOF92');

  // S9.3: VISIBLE-IN-CHROME proof of the liquid-glass info bubble + edge labels
  // (`--dart-define=VYBIA_PROOF93=true`) on a bright AND a dark background.
  static const bool _kProof93 = bool.fromEnvironment('VYBIA_PROOF93');

  // S10: VISIBLE-IN-CHROME proof tour of OUR multi-source database
  // (`--dart-define=VYBIA_PROOF10=true`): different-kind recs backed by the DB,
  // a life-context filter on the new flags, and an enriched/persisted entry.
  static const bool _kProof10 = bool.fromEnvironment('VYBIA_PROOF10');

  // S10.1: VISIBLE-IN-CHROME proof of the static/live split + real per-activity
  // images (`--dart-define=VYBIA_PROOF101=true`): a real-image gallery, live
  // open-data events, the keyed-source seam status, and the offline fallback.
  static const bool _kProof101 = bool.fromEnvironment('VYBIA_PROOF101');

  // S11: VISIBLE-IN-CHROME proof tour of the research-grounded deterministic
  // scorer (`--dart-define=VYBIA_PROOF11=true`): same catalog, different top
  // picks driven by mood/motive (hedonic vs eudaimonic), a context hard-filter,
  // and the honest per-term factor breakdown behind a "pourquoi".
  static const bool _kProof11 = bool.fromEnvironment('VYBIA_PROOF11');

  // S12: VISIBLE-IN-CHROME proof tour of the real data providers wired behind
  // secrets-safe keys (`--dart-define=VYBIA_PROOF12=true`): weather flips
  // feasibility, a place enriched with real hours, the Ticketmaster/TMDB
  // provider status (keyed or "needs key" standby), and the offline fallback.
  static const bool _kProof12 = bool.fromEnvironment('VYBIA_PROOF12');

  @override
  void initState() {
    super.initState();
    if (_kAutoDrive && _kStart.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runProofTour());
    }
  }

  void _runProofTour() {
    const scenes = [AppRouter.reco, AppRouter.welcome, AppRouter.profil];
    var i = 0;
    void hop() {
      final nav = VybiaApp.navigatorKey.currentState;
      if (nav == null || !mounted) return;
      final route = scenes[i];
      debugPrint('VYBIA_SCENE ${route.replaceAll('/', '')}');
      // Reset to the first scene (clears splash), then push each later hop —
      // robust to whatever the initial route resolved to.
      if (i == 0) {
        nav.pushNamedAndRemoveUntil(route, (_) => false);
      } else {
        nav.pushNamed(route);
      }
      i++;
      if (i < scenes.length) {
        Future.delayed(const Duration(seconds: 42), hop);
      }
    }

    hop();
  }

  @override
  void dispose() {
    _guest.dispose();
    _plans.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_kProof91) {
      return MaterialApp(
        title: 'Vybia',
        navigatorKey: VybiaApp.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: GuestScope(
          controller: _guest,
          child: PlanScope(
            controller: _plans,
            child: const S91EngineProofTour(),
          ),
        ),
      );
    }
    if (_kProof ||
        _kProof81 ||
        _kProof92 ||
        _kProof93 ||
        _kProof10 ||
        _kProof101 ||
        _kProof11 ||
        _kProof12) {
      return MaterialApp(
        title: 'Vybia',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: GuestScope(
          controller: _guest,
          child: PlanScope(
            controller: _plans,
            child: _kProof12
                ? const S12ProofTour()
                : _kProof11
                ? const S11ProofTour()
                : _kProof101
                ? const S101ProofTour()
                : _kProof10
                ? const S10ProofTour()
                : _kProof93
                ? const S93ProofTour()
                : _kProof92
                ? const S92ProofTour()
                : _kProof81
                ? const S81ProofTour()
                : const S8ProofTour(),
          ),
        ),
      );
    }
    return MaterialApp(
      title: 'Vybia',
      navigatorKey: VybiaApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // Honour the browser hash deep-link (`/#/discover`, `/#/bubble`, …) with
      // a SINGLE initial route. The framework default would build a
      // [splash, target] stack, and the splash's auto-advance pushReplacement
      // then clobbers the deep-linked top route → everything wrongly lands on
      // welcome. Generating one route fixes that; a bare `/` still maps to the
      // splash via onGenerateRoute's default case.
      // Debug-only launch deep-link for visual proofs:
      // `--dart-define=VYBIA_START=/reco` lands straight on a scene.
      initialRoute: const String.fromEnvironment(
        'VYBIA_START',
        defaultValue: AppRouter.splash,
      ),
      onGenerateInitialRoutes: (initialRoute) => [
        AppRouter.onGenerateRoute(RouteSettings(name: initialRoute)),
      ],
      onGenerateRoute: AppRouter.onGenerateRoute,
      // GuestScope + PlanScope sit above the navigator so session state
      // survives route changes.
      builder: (context, child) => GuestScope(
        controller: _guest,
        child: PlanScope(controller: _plans, child: child ?? const SizedBox()),
      ),
    );
  }
}
