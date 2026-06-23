import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/data/accueil_backdrop.dart';
import 'package:vybia_v2/features/guest/data/assets.dart';
import 'package:vybia_v2/features/guest/model/moment.dart';

MomentContext _at(int weekday, int hour) =>
    MomentContext(weekday: weekday, hour: hour, date: '2026-06-23');

void main() {
  group('S19E — Accueil backdrop fits the moment', () {
    test('changes with the time of day', () {
      final morning = accueilBackdropFor(moment: _at(DateTime.tuesday, 8)).image;
      final evening = accueilBackdropFor(moment: _at(DateTime.tuesday, 20)).image;
      final night = accueilBackdropFor(moment: _at(DateTime.tuesday, 23)).image;
      expect({morning, evening, night}.length, greaterThan(1),
          reason: 'different slots → different fitting images');
      expect(evening, Img.restaurant);
      expect(night, Img.bar);
    });

    test('a weekend afternoon differs from a weekday afternoon', () {
      final weekday = accueilBackdropFor(moment: _at(DateTime.wednesday, 14)).image;
      final weekend = accueilBackdropFor(moment: _at(DateTime.saturday, 14)).image;
      expect(weekday, isNot(weekend));
    });

    test('a winter morning swaps to a cosy indoor image', () {
      final summer =
          accueilBackdropFor(moment: _at(DateTime.tuesday, 8), winter: false).image;
      final winter =
          accueilBackdropFor(moment: _at(DateTime.tuesday, 8), winter: true).image;
      expect(summer, Img.garden);
      expect(winter, Img.cafe);
    });

    test('the usual mood at that time leads when known', () {
      final calm = accueilBackdropFor(
        moment: _at(DateTime.tuesday, 20),
        usualMood: MoodBucket.calm,
      ).image;
      final lively = accueilBackdropFor(
        moment: _at(DateTime.tuesday, 20),
        usualMood: MoodBucket.lively,
      ).image;
      expect(calm, Img.calm);
      expect(lively, Img.social); // lively in the evening
    });

    test('always carries a time-aware invitation line', () {
      for (final h in [8, 14, 20, 23]) {
        final b = accueilBackdropFor(moment: _at(DateTime.tuesday, h));
        expect(b.invite, isNotEmpty);
      }
    });
  });
}
