/// Bundled situational image assets, named once so screens, the question bank
/// and the place→image mapping never repeat raw paths.
///
/// Two families:
///   * `places/…`  — one CATEGORY-ACCURATE photo per real OSM place category
///     (a café shows a café, a theatre shows a theatre). Mapped to real places
///     by their category in `place_category_mapping.dart`.
///   * `emotions/…` — four mood / atmosphere photos used by the welcome mood
///     capture and the adaptive question bank.
///
/// All images are free-licensed (Wikimedia Commons / Unsplash mirror); see
/// `assets/images/NOTICES.md` for per-image author + licence + source.
class Img {
  Img._();

  // ---- Category-accurate place images -----------------------------------
  static const cafe = 'assets/images/places/cafe.jpg';
  static const restaurant = 'assets/images/places/restaurant.jpg';
  static const bar = 'assets/images/places/bar.jpg';
  static const cinema = 'assets/images/places/cinema.jpg';
  static const theatre = 'assets/images/places/theatre.jpg';
  static const museum = 'assets/images/places/museum.jpg';
  static const gallery = 'assets/images/places/gallery.jpg';
  static const viewpoint = 'assets/images/places/viewpoint.jpg';
  static const park = 'assets/images/places/park.jpg';
  static const garden = 'assets/images/places/garden.jpg';
  static const market = 'assets/images/places/market.jpg';
  static const sports = 'assets/images/places/sports.jpg';

  // S18C — extra REAL, free-licensed variants per generic category so two
  // same-category recommendations no longer share one picture (see
  // tool/fetch_varied_places.mjs + NOTICES.md for attribution).
  static const cafe2 = 'assets/images/places/cafe2.jpg';
  static const cafe3 = 'assets/images/places/cafe3.jpg';
  static const bar2 = 'assets/images/places/bar2.jpg';
  static const bar3 = 'assets/images/places/bar3.jpg';
  static const restaurant2 = 'assets/images/places/restaurant2.jpg';
  static const cinema2 = 'assets/images/places/cinema2.jpg';
  static const museum2 = 'assets/images/places/museum2.jpg';
  static const park2 = 'assets/images/places/park2.jpg';

  // ---- Mood / atmosphere images -----------------------------------------
  static const calm = 'assets/images/emotions/calm.jpg';
  static const curious = 'assets/images/emotions/curious.jpg';
  static const social = 'assets/images/emotions/social.jpg';
  static const energetic = 'assets/images/emotions/energetic.jpg';
}
