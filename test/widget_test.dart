import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/app.dart';

void main() {
  testWidgets('app boots to the splash and auto-advances to the calm Accueil',
      (tester) async {
    await tester.pumpWidget(const VybiaApp());
    await tester.pump();

    // Splash shows the brand mark before auto-continuing.
    expect(find.text('Vybia'), findsOneWidget);

    // Let the splash timer + nav fire; pump explicit frames (the calm field +
    // orb pulse repeat forever, so never pumpAndSettle).
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();

    // The Accueil hub now hosts the four cahier directions on the orb.
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Planifier'), findsOneWidget);
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Mes plans'), findsOneWidget);
  });
}
