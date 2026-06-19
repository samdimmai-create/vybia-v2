import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/app.dart';

void main() {
  testWidgets('app boots to the splash and auto-advances to Welcome',
      (tester) async {
    await tester.pumpWidget(const VybiaApp());
    await tester.pump();

    // Splash shows the brand mark before auto-continuing to Welcome.
    expect(find.text('Vybia'), findsOneWidget);

    // Let the splash timer + nav fire; pump explicit frames (the orb pulse
    // repeats forever, so never pumpAndSettle).
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump();

    // Welcome's mood headline is now on screen.
    expect(find.textContaining('te sentir'), findsOneWidget);
  });
}
