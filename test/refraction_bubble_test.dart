import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/components/bubble/refraction_bubble.dart';

void main() {
  testWidgets('RefractionBubble builds and reports a rendering technique',
      (tester) async {
    RefractionTechnique? reported;
    await tester.pumpWidget(
      MaterialApp(
        home: RefractionBubble(
          image: const AssetImage('assets/images/recos/walk_night.jpg'),
          orbCenter: const Offset(200, 300),
          onTechnique: (t) => reported = t,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(RefractionBubble), findsOneWidget);
    expect(tester.takeException(), isNull);
    // It commits to one of the two paths — never leaves the lens unrendered.
    expect(reported, isNotNull);
  });

  testWidgets('RefractionBubble accepts a null orbCenter (lens hidden) without error',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RefractionBubble(
          image: AssetImage('assets/images/recos/rooftop.jpg'),
          orbCenter: null,
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
