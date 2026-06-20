import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/guest/widgets/reflection_slides.dart';
import 'package:vybia_v2/features/guest/widgets/reflection_transition.dart';

/// S8.1E — the calm "Vybia réfléchit" bridge.
void main() {
  const slides = [
    ReflectionSlide(image: 'assets/images/emotions/calm.jpg', label: 'Énergie · doux'),
    ReflectionSlide(image: 'assets/images/emotions/social.jpg', label: 'Social · entouré'),
  ];

  testWidgets('renders the title + first slide label and a skip hint',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReflectionTransition(slides: slides, onDone: () {}),
    ));
    await tester.pump();
    expect(find.text('Vybia réfléchit…'), findsOneWidget);
    expect(find.text('Énergie · doux'), findsOneWidget);
    expect(find.text('touche pour passer'), findsOneWidget);
  });

  testWidgets('a touch skips straight to onDone', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      home: ReflectionTransition(slides: slides, onDone: () => done++),
    ));
    await tester.pump();
    await tester.tap(find.byType(ReflectionTransition));
    await tester.pump();
    expect(done, 1);
  });

  testWidgets('auto-advances through the slides and finishes once',
      (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      home: ReflectionTransition(
        slides: slides,
        perSlide: const Duration(milliseconds: 60),
        onDone: () => done++,
      ),
    ));
    await tester.pump();
    // First tick → second slide.
    await tester.pump(const Duration(milliseconds: 70));
    expect(find.text('Social · entouré'), findsOneWidget);
    // Second tick → finishes (last slide reached).
    await tester.pump(const Duration(milliseconds: 70));
    expect(done, 1);
    // No double-fire on a further tick.
    await tester.pump(const Duration(milliseconds: 70));
    expect(done, 1);
    await tester.pump(const Duration(seconds: 1)); // drain the drift ticker
  });

  testWidgets('empty slides bridge straight through to onDone', (tester) async {
    var done = 0;
    await tester.pumpWidget(MaterialApp(
      home: ReflectionTransition(slides: const [], onDone: () => done++),
    ));
    await tester.pump();
    expect(done, 1);
  });

  test('explore slides come from the most confident captured dimensions', () {
    final p = GuestProfile()
      ..answer(Dimension.energy, 0.2)
      ..answer(Dimension.social, 0.85);
    final s = exploreReflectionSlides(p);
    expect(s, isNotEmpty);
    expect(s.length, lessThanOrEqualTo(3));
    expect(s.every((slide) => slide.label.contains('·')), isTrue);
  });

  test('explore slides degrade to one neutral slide on a cold profile', () {
    final s = exploreReflectionSlides(GuestProfile());
    expect(s.length, 1);
  });
}
