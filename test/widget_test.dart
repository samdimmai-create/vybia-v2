import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vybia_v2/app.dart';
import 'package:vybia_v2/core/persistence/app_store.dart';
import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';

void main() {
  // S16A: the splash routes by first-visit vs return.
  //   * brand-new guest (no saved profile) → FILES straight to value: the mood
  //     capture (Welcome), skipping the abstract 4-direction hub;
  //   * returning guest (saved profile) → lands on the calm Accueil hub.

  testWidgets('first-visit boots to the value path (mood), not the hub',
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

    // We land on the mood capture (Welcome) — value first, no hub detour.
    expect(find.textContaining('te sentir'), findsOneWidget);
    expect(find.text('Mes plans'), findsNothing, reason: 'hub is skipped');
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
