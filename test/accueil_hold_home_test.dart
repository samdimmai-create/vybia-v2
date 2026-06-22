import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vybia_v2/core/router/app_router.dart';
import 'package:vybia_v2/features/guest/state/guest_controller.dart';
import 'package:vybia_v2/features/plans/state/plan_controller.dart';

/// S8A: an immobile hold-to-home from any scene lands on the calm Accueil hub.
void main() {
  testWidgets('immobile hold-to-home lands on the calm Accueil', (tester) async {
    await tester.pumpWidget(
      GuestScope(
        controller: GuestController(),
        child: PlanScope(
          controller: PlanController(),
          child: MaterialApp(
            initialRoute: AppRouter.welcome,
            // Build a SINGLE welcome route (mirroring app.dart). Without this,
            // Flutter's default splits '/welcome' into the stack ['/', '/welcome']
            // and also builds the SplashScreen, whose timer would then navigate
            // mid-test. We want a clean welcome-only stack for the hold gesture.
            onGenerateInitialRoutes: (initialRoute) => [
              AppRouter.onGenerateRoute(
                  const RouteSettings(name: AppRouter.welcome)),
            ],
            onGenerateRoute: AppRouter.onGenerateRoute,
          ),
        ),
      ),
    );
    await tester.pump();

    // We start on the Welcome (Explorer) scene, not the hub.
    expect(find.textContaining('te sentir'), findsOneWidget);
    expect(find.text('Explorer'), findsNothing);

    // Press and hold perfectly still: past the immobile threshold, then through
    // the grow, the calm portal opens and we navigate home.
    final gesture = await tester.startGesture(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 1850)); // immobile fires (1.8s)
    await tester.pump(const Duration(milliseconds: 1350)); // grow completes (1.3s)
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // The Accueil hub is now showing its four cahier directions.
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Mes plans'), findsOneWidget);
  });
}
