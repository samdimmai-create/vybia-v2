/// The kind of thing the engine can recommend (S10).
///
/// V2 started place-only (the OSM snapshot). S10 broadens the catalog to the
/// full spectrum of leisure, so every entry now declares one [ActivityKind].
/// The kind drives which kind-specific fields are meaningful (a [film] has a
/// runtime + where-to-watch, a [travel] has a destination + distance) and lets
/// the repository slice the catalog ("show me a film, an outing, a getaway").
enum ActivityKind {
  /// A physical venue you go to: cafés, restaurants, parks, museums…
  place,

  /// A time-bound happening: a festival, an expo, a screening, a concert.
  event,

  /// A film — at the cinema or to stream at home.
  film,

  /// An at-home / online activity: streaming, an online course, a creative hobby.
  online,

  /// A getaway / day-trip / destination beyond the home city.
  travel;

  String get labelFr {
    switch (this) {
      case ActivityKind.place:
        return 'Lieu';
      case ActivityKind.event:
        return 'Événement';
      case ActivityKind.film:
        return 'Film';
      case ActivityKind.online:
        return 'À la maison';
      case ActivityKind.travel:
        return 'Escapade';
    }
  }

  static ActivityKind fromName(String? s) {
    for (final k in ActivityKind.values) {
      if (k.name == s) return k;
    }
    return ActivityKind.place;
  }
}
