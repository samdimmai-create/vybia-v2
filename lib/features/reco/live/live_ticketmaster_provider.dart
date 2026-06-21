import 'dart:convert';

import '../../../core/config/api_config.dart';
import '../../guest/data/assets.dart';
import '../../guest/model/dimension.dart';
import '../db/catalog_entry.dart';
import '../model/activity.dart';
import '../model/activity_kind.dart';
import '../model/availability.dart';
import 'live_source.dart';

/// LIVE events via the TICKETMASTER Discovery API (S12D) — behind a FREE-key seam.
///
/// Returns real, dated concerts / sports / arts / theatre near the guest, each
/// projected into our [CatalogEntry] schema (availability == live) so the SAME
/// mood/ambiance/context engine scores them like everything else. These BLEND
/// with the keyless Montréal open-data events (the [LiveAvailabilityService]
/// dedupes by title+kind). Gated on a free Ticketmaster key:
/// WITHOUT a key → returns [] and reports "needs key" (no crash, no block);
/// the keyless Montréal events still flow. Pass the key with
/// `--dart-define=TICKETMASTER_KEY=...`.
///
/// Source: developer.ticketmaster.com — Discovery API (free tier 5 req/s,
/// 5 000 req/day). Safe: short timeout, never throws (returns [] on any failure).
class LiveTicketmasterProvider implements LiveSourceProvider {
  LiveTicketmasterProvider({
    HttpGet? httpGet,
    String? apiKey,
    this.radiusKm = 25,
    this.market = 'Montréal',
  })  : _get = httpGet ?? httpGetDefault,
        _key = apiKey ?? ApiConfig.ticketmasterKey;

  static const String _endpoint =
      'https://app.ticketmaster.com/discovery/v2/events.json';

  final HttpGet _get;
  final String _key;
  final int radiusKm;
  final String market;

  @override
  String get id => 'ticketmaster_events';

  @override
  String get label => 'Événements — Ticketmaster (billetterie)';

  @override
  ActivityKind get kind => ActivityKind.event;

  @override
  bool get isConfigured => _key.isNotEmpty;

  @override
  String? get needsKeyNote =>
      'Clé API Ticketmaster Discovery (gratuite) → concerts/sports/arts/théâtre '
      'avec dates réelles, fusionnés avec les données ouvertes de Montréal.';

  @override
  Future<List<CatalogEntry>> fetchAvailableNow(LiveQuery q) async {
    if (!isConfigured) return const []; // seam: no key → empty, service logs it
    final body = await _get(_uriFor(q), timeout: const Duration(seconds: 5));
    if (body == null) return const [];
    try {
      final decoded = jsonDecode(body);
      final embedded = decoded is Map ? decoded['_embedded'] : null;
      final events = embedded is Map ? embedded['events'] : null;
      if (events is! List) return const [];
      final out = <CatalogEntry>[];
      for (final e in events) {
        if (e is! Map) continue;
        final entry = _project(e);
        if (entry != null) out.add(entry);
        if (out.length >= q.limit) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Uri _uriFor(LiveQuery q) {
    final params = <String, String>{
      'apikey': _key,
      'sort': 'date,asc',
      'size': '${q.limit * 2}',
      'startDateTime': _iso(q.when),
      'classificationName': 'music,sports,arts,theatre,film',
    };
    if (q.lat != null && q.lng != null) {
      params['latlong'] = '${q.lat},${q.lng}';
      params['radius'] = '$radiusKm';
      params['unit'] = 'km';
    } else {
      params['city'] = market;
    }
    return Uri.parse(_endpoint).replace(queryParameters: params);
  }

  CatalogEntry? _project(Map e) {
    final title = _str(e['name']);
    if (title.isEmpty) return null;

    final dates = e['dates'];
    final startInfo = dates is Map ? dates['start'] : null;
    var start = '';
    if (startInfo is Map) {
      start = _str(startInfo['dateTime']);
      if (start.isEmpty) start = _str(startInfo['localDate']);
    }

    final venues = e['_embedded']?['venues'];
    final venue = venues is List && venues.isNotEmpty ? venues.first : null;
    double? lat, lng;
    String hood = '';
    if (venue is Map) {
      final loc = venue['location'];
      if (loc is Map) {
        lat = _num(loc['latitude']);
        lng = _num(loc['longitude']);
      }
      hood = _str(venue['city']?['name']);
    }

    final segment = _segmentName(e);
    final category = _categoryFor(segment);
    final url = _str(e['url']);
    final idRaw = _str(e['id']);
    final image = _bestImage(e);

    return CatalogEntry(
      id: 'tm_${idRaw.isEmpty ? title.hashCode.toRadixString(16) : idRaw}',
      name: title,
      kind: ActivityKind.event,
      availability: Availability.live,
      category: category,
      subcategory: segment.isEmpty ? null : segment,
      descFr: _descFor(title, segment, hood),
      imageRef: image ?? _assetFor(category),
      tags: _tagsFor(category),
      motives: (hedonic: 0.7, relaxation: 0.35, eudaimonic: 0.45),
      tagList: segment.isEmpty ? const [] : [segment],
      priceTier: 2,
      effortLevel: 0.3,
      indoor: category != ActivityCategory.active,
      timeOfDay: const ['soir', 'nuit'],
      winterFriendly: true,
      source: 'ticketmaster',
      sourceId: idRaw.isEmpty ? null : idRaw,
      confidence: 0.8,
      lat: lat,
      lng: lng,
      neighbourhood: hood.isEmpty ? null : hood,
      startsAt: start.isEmpty ? null : start,
      url: url.isEmpty ? null : url,
      imageAttribution: image == null ? null : 'Ticketmaster',
    );
  }

  String _segmentName(Map e) {
    final cls = e['classifications'];
    if (cls is List && cls.isNotEmpty && cls.first is Map) {
      return _str((cls.first as Map)['segment']?['name']);
    }
    return '';
  }

  ActivityCategory _categoryFor(String segment) {
    final s = segment.toLowerCase();
    if (s.contains('sport')) return ActivityCategory.active;
    if (s.contains('music')) return ActivityCategory.nightlife;
    if (s.contains('film')) return ActivityCategory.culture;
    // Arts & Theatre, Miscellaneous…
    return ActivityCategory.culture;
  }

  Map<Dimension, double> _tagsFor(ActivityCategory c) => {
        Dimension.energy: c == ActivityCategory.active ? 0.75 : 0.6,
        Dimension.social: 0.7,
        Dimension.novelty: 0.7,
        Dimension.distance: 0.55,
        Dimension.indoor: c == ActivityCategory.active ? 0.3 : 0.7,
        Dimension.timing: 0.8,
        Dimension.budget: 0.6,
        Dimension.vibe: 0.75,
      };

  String _descFor(String title, String segment, String hood) {
    final where = hood.isEmpty ? 'à Montréal' : 'à $hood';
    final what = segment.isEmpty ? 'Un événement' : segment;
    return '$what $where — billets en vente, date réelle.';
  }

  String? _bestImage(Map e) {
    final imgs = e['images'];
    if (imgs is! List) return null;
    String? best;
    int bestW = 0;
    for (final i in imgs) {
      if (i is! Map) continue;
      final w = _num(i['width'])?.toInt() ?? 0;
      final u = _str(i['url']);
      if (u.isNotEmpty && w > bestW && w <= 1200) {
        bestW = w;
        best = u;
      }
    }
    return best;
  }

  String _assetFor(ActivityCategory c) {
    switch (c) {
      case ActivityCategory.active:
        return Img.sports;
      case ActivityCategory.nightlife:
        return Img.bar;
      case ActivityCategory.culture:
        return Img.theatre;
      default:
        return Img.museum;
    }
  }

  static String _iso(DateTime d) {
    final u = d.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}-${two(u.month)}-${two(u.day)}T${two(u.hour)}:${two(u.minute)}:${two(u.second)}Z';
  }

  static String _str(Object? v) => v == null ? '' : v.toString().trim();

  static double? _num(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_str(v));
  }
}
