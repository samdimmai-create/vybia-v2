import 'activity_kind.dart';

/// Whether an activity is STABLE enough to live in the build-time snapshot, or
/// TIME-SENSITIVE and must be checked LIVE at runtime (S10.1).
///
/// The founder's architecture split: a café, a park, a museum, a getaway or an
/// evergreen at-home idea is the same thing tomorrow as it is today, so it ships
/// in the offline catalog ([Availability.fixed]). A film in cinemas, a film's
/// streaming availability, or a dated event is gone — or simply wrong — the
/// moment its window passes, so it must be served from a LIVE source that knows
/// what is ACTUALLY available right now ([Availability.live]); the snapshot row
/// only survives as an offline fallback, never as a primary recommendation.
enum Availability {
  /// Stable / snapshot-able: served fully offline from the bundled catalog.
  fixed,

  /// Time-sensitive / availability-dependent: served by the live layer at
  /// runtime, with the snapshot row kept only as an offline fallback.
  live;

  /// JSON token — `static` on disk reads truer to the founder's vocabulary than
  /// the Dart-legal identifier [fixed].
  String get jsonName => this == Availability.fixed ? 'static' : 'live';

  /// The default availability for a [kind]: dated events and films (cinema /
  /// streaming) are LIVE; places, getaways and evergreen online/at-home are
  /// stable. An entry may still override this explicitly in its record.
  static Availability ofKind(ActivityKind kind) {
    switch (kind) {
      case ActivityKind.event:
      case ActivityKind.film:
        return Availability.live;
      case ActivityKind.place:
      case ActivityKind.travel:
      case ActivityKind.online:
        return Availability.fixed;
    }
  }

  /// Parse the JSON token (`static` | `live`), falling back to the [kind]
  /// default when absent/unknown so existing rows need no migration.
  static Availability fromJson(String? s, ActivityKind kind) {
    switch (s) {
      case 'static':
      case 'fixed':
        return Availability.fixed;
      case 'live':
        return Availability.live;
      default:
        return ofKind(kind);
    }
  }
}
