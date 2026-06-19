import 'package:flutter/material.dart';

import 'core/persistence/app_store.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
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

  @override
  void dispose() {
    _guest.dispose();
    _plans.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      onGenerateInitialRoutes: (initialRoute) =>
          [AppRouter.onGenerateRoute(RouteSettings(name: initialRoute))],
      onGenerateRoute: AppRouter.onGenerateRoute,
      // GuestScope + PlanScope sit above the navigator so session state
      // survives route changes.
      builder: (context, child) => GuestScope(
        controller: _guest,
        child: PlanScope(
          controller: _plans,
          child: child ?? const SizedBox(),
        ),
      ),
    );
  }
}
