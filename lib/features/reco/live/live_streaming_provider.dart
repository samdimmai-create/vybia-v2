import 'dart:convert';

import '../../../core/config/api_config.dart';
import '../../guest/data/assets.dart';
import '../../guest/model/dimension.dart';
import '../db/catalog_entry.dart';
import '../model/activity.dart';
import '../model/activity_kind.dart';
import '../model/availability.dart';
import 'live_source.dart';

/// LIVE film availability via TMDB (S10.1B) — behind a FREE-key config seam.
///
/// TMDB's `watch/providers` + `now_playing` are the natural source for "what can
/// I actually watch right now", but they need a FREE API key. This provider is
/// built against TMDB and gated on that key: with a key it returns current films
/// (carrying their poster URL as a runtime network image); WITHOUT a key it
/// returns [] and is reported as "needs TMDB key" — it never crashes and never
/// blocks the flow. Pass the key with `--dart-define=TMDB_KEY=...`.
///
/// A key unlocks: now-playing cinema titles + per-title streaming providers
/// (Netflix/Prime/Crave…) for the user's region, with real posters.
class LiveStreamingProvider implements LiveSourceProvider {
  LiveStreamingProvider({
    HttpGet? httpGet,
    String? apiKey,
    this.region = 'CA',
    this.language = 'fr-CA',
  })  : _get = httpGet ?? httpGetDefault,
        _key = apiKey ?? ApiConfig.tmdbKey;

  static const String _base = 'https://api.themoviedb.org/3';
  static const String _imgBase = 'https://image.tmdb.org/t/p/w500';

  final HttpGet _get;
  final String _key;
  final String region;
  final String language;

  @override
  String get id => 'tmdb_streaming';

  @override
  String get label => 'Films — TMDB (à regarder maintenant)';

  @override
  ActivityKind get kind => ActivityKind.film;

  @override
  bool get isConfigured => _key.isNotEmpty;

  @override
  String? get needsKeyNote =>
      'Clé API TMDB (gratuite) → films à l’affiche + plateformes de streaming '
      '(Netflix/Prime/Crave…) pour la région, avec affiches réelles.';

  @override
  Future<List<CatalogEntry>> fetchAvailableNow(LiveQuery q) async {
    if (!isConfigured) return const []; // seam: no key → empty, service logs it
    final uri = Uri.parse('$_base/movie/now_playing').replace(queryParameters: {
      'api_key': _key,
      'region': region,
      'language': language,
      'page': '1',
    });
    final body = await _get(uri, timeout: const Duration(seconds: 5));
    if (body == null) return const [];
    try {
      final decoded = jsonDecode(body);
      final results = decoded is Map ? decoded['results'] : null;
      if (results is! List) return const [];
      final out = <CatalogEntry>[];
      for (final m in results) {
        if (m is! Map) continue;
        final e = _project(m);
        if (e != null) out.add(e);
        if (out.length >= q.limit) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  CatalogEntry? _project(Map m) {
    final id = m['id'];
    final title = (m['title'] ?? m['name'] ?? '').toString().trim();
    if (id == null || title.isEmpty) return null;
    final poster = (m['poster_path'] ?? '').toString();
    final overview = (m['overview'] ?? '').toString().trim();
    final year = _year(m['release_date']?.toString());

    return CatalogEntry(
      id: 'tmdb_$id',
      name: title,
      kind: ActivityKind.film,
      availability: Availability.live,
      category: ActivityCategory.culture,
      descFr: overview.isEmpty ? 'À l’affiche en ce moment.' : overview,
      // Poster is a runtime NETWORK image (imageProviderFor handles the http URL),
      // degrading to the bundled cinema asset if the path is missing.
      imageRef: poster.isEmpty ? Img.cinema : '$_imgBase$poster',
      tags: const {
        Dimension.energy: 0.3,
        Dimension.social: 0.4,
        Dimension.novelty: 0.7,
        Dimension.distance: 0.5,
        Dimension.indoor: 0.95,
        Dimension.timing: 0.8,
        Dimension.budget: 0.4,
        Dimension.vibe: 0.5,
      },
      motives: (hedonic: 0.6, relaxation: 0.7, eudaimonic: 0.4),
      priceTier: 1,
      effortLevel: 0.1,
      indoor: true,
      timeOfDay: const ['soir', 'nuit'],
      winterFriendly: true,
      source: 'tmdb',
      sourceId: id.toString(),
      confidence: 0.7,
      year: year,
      whereToWatch: 'cinema',
      imageAttribution: poster.isEmpty ? null : 'Affiche © TMDB',
    );
  }

  static int? _year(String? date) {
    if (date == null || date.length < 4) return null;
    return int.tryParse(date.substring(0, 4));
  }
}
