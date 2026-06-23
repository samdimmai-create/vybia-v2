import 'dimension.dart';
import 'guest_profile.dart';

/// The four coarse day-slots a [MomentContext] falls into. Each reaction and
/// each answered question is filed against one of these so the cross-session
/// memory (S19B) can say "you didn't like this *in the evening*" without
/// forbidding it forever — a different slot may resurface it.
enum DaySlot {
  morning, // 05:00–10:59
  afternoon, // 11:00–16:59
  evening, // 17:00–21:59
  night; // 22:00–04:59

  String get labelFr {
    switch (this) {
      case DaySlot.morning:
        return 'le matin';
      case DaySlot.afternoon:
        return 'l’après-midi';
      case DaySlot.evening:
        return 'en soirée';
      case DaySlot.night:
        return 'tard le soir';
    }
  }

  static DaySlot fromHour(int hour) {
    final h = hour % 24;
    if (h >= 5 && h < 11) return DaySlot.morning;
    if (h >= 11 && h < 17) return DaySlot.afternoon;
    if (h >= 17 && h < 22) return DaySlot.evening;
    return DaySlot.night;
  }

  static DaySlot byName(String? name) {
    for (final s in DaySlot.values) {
      if (s.name == name) return s;
    }
    return DaySlot.afternoon;
  }
}

/// A coarse bucket of the guest's current mood, so the memory keys preferences
/// to "how you felt" as well as "when". A "pas pour moi" in a *lively* mood may
/// still surface later in a *calm* one.
enum MoodBucket {
  calm,
  open,
  lively;

  String get labelFr {
    switch (this) {
      case MoodBucket.calm:
        return 'posé';
      case MoodBucket.open:
        return 'ouvert';
      case MoodBucket.lively:
        return 'plein d’élan';
    }
  }

  static MoodBucket fromValue(double mood) {
    if (mood < 0.4) return MoodBucket.calm;
    if (mood > 0.66) return MoodBucket.lively;
    return MoodBucket.open;
  }

  /// Read the bucket straight off a profile's mood dimension.
  static MoodBucket of(GuestProfile p) =>
      fromValue(p.valueOf(Dimension.mood));

  static MoodBucket byName(String? name) {
    for (final b in MoodBucket.values) {
      if (b.name == name) return b;
    }
    return MoodBucket.open;
  }
}

/// THE MOMENT (S19A): the day-of-week + hour a choice was made, plus the derived
/// [slot] and a calendar [date] key. Pure data, no Flutter — injected (rather
/// than read from the clock deep inside the engine) so tests are deterministic.
///
/// Every answer and every reaction is stamped with the moment so Vybia learns
/// *when* you reach for something, not just *what* — the spine of the temporal
/// preference memory (S19B) and the time-aware Accueil backdrop (S19E).
class MomentContext {
  const MomentContext({required this.weekday, required this.hour, this.date});

  /// 1 (Monday) … 7 (Sunday) — matches [DateTime.weekday].
  final int weekday;

  /// 0..23 local hour.
  final int hour;

  /// `yyyy-mm-dd` calendar key, used to tell "today" from "another day" so a
  /// liked-but-unlived activity can resurface on a DIFFERENT day (S19B).
  final String? date;

  factory MomentContext.now({DateTime? clock}) {
    final t = clock ?? DateTime.now();
    return MomentContext(
      weekday: t.weekday,
      hour: t.hour,
      date: _dateKey(t),
    );
  }

  static String _dateKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';

  DaySlot get slot => DaySlot.fromHour(hour);

  bool get isWeekend =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;

  String get todayKey => date ?? '';

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'hour': hour,
        if (date != null) 'date': date,
      };

  static MomentContext fromJson(Map<String, dynamic> j) => MomentContext(
        weekday: (j['weekday'] as num?)?.toInt() ?? DateTime.monday,
        hour: (j['hour'] as num?)?.toInt() ?? 12,
        date: j['date'] as String?,
      );
}
