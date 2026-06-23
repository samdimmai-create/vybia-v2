import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vybia_v2/app.dart';
import 'package:vybia_v2/core/persistence/app_store.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';

void main() {
  // S21B: the splash ALWAYS lands on the Accueil hub — reverting S16's
  // "first-visit skips the hub". Whether the guest is brand-new or returning,
  // after the splash they arrive on the calm 4-direction hub; Explorer is then
  // one swipe away, but the hub is never bypassed.

  testWidgets('first-visit boots to the Accueil hub (never bypassed)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.open(); // empty → no saved profile

    await tester.pumpWidget(VybiaApp(store: store));
    await tester.pump();

    // Splash shows the brand mark before auto-continuing.
    expect(find.text('Vybia'), findsOneWidget);

    // Let the splash timer + nav fire; pump explicit frames (the bubble drift +
    // orb pulse repeat forever, so never pumpAndSettle).
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();

    // We land on the Accueil hub — the four cahier directions on the orb.
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Planifier'), findsOneWidget);
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Mes plans'), findsOneWidget);
  });

  testWidgets('returning guest boots to the calm Accueil hub', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.open();
    // Seed a saved profile so the controller reads the guest as returning.
    await store.saveProfile(GuestProfile()..answer(Dimension.mood, 0.5));

    await tester.pumpWidget(VybiaApp(store: store));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();

    // The Accueil hub hosts the four cahier directions on the orb.
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Planifier'), findsOneWidget);
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Mes plans'), findsOneWidget);
  });
}
