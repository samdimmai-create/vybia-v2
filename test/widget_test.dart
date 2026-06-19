import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/app.dart';
import 'package:vybia_v2/components/orb/vybia_orb.dart';

void main() {
  testWidgets('orb demo boots and a drag commits a direction',
      (tester) async {
    await tester.pumpWidget(const VybiaApp());
    await tester.pump();

    // Brand mark renders on the demo surface.
    expect(find.text('Vybia'), findsOneWidget);
    // The orb primitive hosts the surface.
    expect(find.byType(VybiaOrb), findsOneWidget);

    // Drag right past threshold should commit a direction.
    final center = tester.getCenter(find.byType(VybiaOrb));
    final gesture = await tester.startGesture(center);
    await gesture.moveBy(const Offset(140, 0));
    await tester.pump();
    await gesture.up();
    // Pulse animation repeats forever, so pump explicit frames (not settle).
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Direction'), findsOneWidget);
  });
}
