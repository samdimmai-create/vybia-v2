import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/guest/model/moment.dart';

void main() {
  group('MomentContext (S19A) — day-of-week + hour → slot', () {
    test('slot derives from the hour', () {
      expect(DaySlot.fromHour(8), DaySlot.morning);
      expect(DaySlot.fromHour(14), DaySlot.afternoon);
      expect(DaySlot.fromHour(19), DaySlot.evening);
      expect(DaySlot.fromHour(23), DaySlot.night);
      expect(DaySlot.fromHour(3), DaySlot.night);
    });

    test('isWeekend reads the weekday', () {
      final sat = MomentContext.now(clock: DateTime(2026, 6, 20, 14)); // Saturday
      final wed = MomentContext.now(clock: DateTime(2026, 6, 17, 14)); // Wednesday
      expect(sat.isWeekend, isTrue);
      expect(wed.isWeekend, isFalse);
    });

    test('captures weekday/hour/date and round-trips through JSON', () {
      final m = MomentContext.now(clock: DateTime(2026, 6, 23, 19, 30));
      expect(m.weekday, DateTime.tuesday);
      expect(m.hour, 19);
      expect(m.slot, DaySlot.evening);
      expect(m.todayKey, '2026-06-23');
      final back = MomentContext.fromJson(m.toJson());
      expect(back.weekday, m.weekday);
      expect(back.hour, m.hour);
      expect(back.slot, m.slot);
      expect(back.todayKey, m.todayKey);
    });
  });

  group('MoodBucket — coarse mood for memory keys', () {
    test('buckets the mood value', () {
      expect(MoodBucket.fromValue(0.1), MoodBucket.calm);
      expect(MoodBucket.fromValue(0.5), MoodBucket.open);
      expect(MoodBucket.fromValue(0.9), MoodBucket.lively);
    });

    test('reads straight off a profile', () {
      final p = GuestProfile()..answer(Dimension.mood, 0.05);
      expect(MoodBucket.of(p), MoodBucket.calm);
    });
  });
}
