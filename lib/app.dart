import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/guest/state/guest_controller.dart';

/// Root application widget. Wires the theme + router and hosts the single
/// shared [GuestController] above the navigator (via [GuestScope]) so every
/// guest screen reads and advances the same session.
class VybiaApp extends StatefulWidget {
  const VybiaApp({super.key});

  @override
  State<VybiaApp> createState() => _VybiaAppState();
}

class _VybiaAppState extends State<VybiaApp> {
  final GuestController _guest = GuestController();

  @override
  void dispose() {
    _guest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vybia',
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
      // GuestScope sits above the navigator so it survives route changes.
      builder: (context, child) =>
          GuestScope(controller: _guest, child: child ?? const SizedBox()),
    );
  }
}
