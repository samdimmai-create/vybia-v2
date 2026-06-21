import '../db/catalog_entry.dart';
import '../model/activity_kind.dart';
import 'live_source.dart';

/// LIVE cinema showtimes (S10.1B) — INTERFACE + STUB, documenting the gap.
///
/// There is no clean, free, Canada-wide cinema-showtimes API: the usable sources
/// (Google Showtimes, chain APIs) are keyed/paid or scraping-only. So this
/// provider exists to hold the seam — same shape as the others — and reports as
/// unconfigured so the service skips it gracefully. When a keyed showtimes
/// source is chosen, only [isConfigured] + [fetchAvailableNow] need filling in;
/// nothing downstream changes.
class LiveCinemaProvider implements LiveSourceProvider {
  const LiveCinemaProvider();

  @override
  String get id => 'cinema_showtimes';

  @override
  String get label => 'Films — séances en salle (horaires)';

  @override
  ActivityKind get kind => ActivityKind.film;

  @override
  bool get isConfigured => false; // no free showtimes source available

  @override
  String? get needsKeyNote =>
      'Aucune API d’horaires de cinéma libre fiable au Canada — nécessite une '
      'source payante/à clé (Google Showtimes ou API d’une chaîne de cinémas).';

  @override
  Future<List<CatalogEntry>> fetchAvailableNow(LiveQuery q) async => const [];
}
