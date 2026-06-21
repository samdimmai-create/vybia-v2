import 'dart:convert';

import '../../guest/data/assets.dart';
import '../../guest/model/dimension.dart';
import '../db/catalog_entry.dart';
import '../model/activity.dart';
import '../model/activity_kind.dart';
import '../model/availability.dart';
import 'live_source.dart';

/// LIVE events from the City of Montréal OPEN DATA calendar (S10.1B) — FREE and
/// KEYLESS. Queries the public "Événements publics" datastore over CKAN SQL for
/// happenings dated TODAY onward, drops the governance noise (council meetings,
/// public consultations), and projects each into our [CatalogEntry] schema so a
/// real dated event is scored by the SAME mood/ambiance engine as a static café.
///
/// Source: donnees.montreal.ca — "Événements publics" (Licence Creative Commons
/// Attribution 4.0). CORS-enabled, so it works from the Flutter web runtime; on
/// any failure the service degrades to the static fallback (never blocks).
class LiveEventsProvider implements LiveSourceProvider {
  LiveEventsProvider({
    HttpGet? httpGet,
    this.resourceId = _resourceId,
    this.endpoint = _endpoint,
  }) : _get = httpGet ?? httpGetDefault;

  /// "Événements publics" CSV resource (datastore-active) on the Montréal CKAN.
  static const String _resourceId = '6decf611-6f11-4f34-bb36-324d804c9bad';
  static const String _endpoint =
      'https://donnees.montreal.ca/api/3/action/datastore_search_sql';

  final HttpGet _get;
  final String resourceId;
  final String endpoint;

  @override
  String get id => 'montreal_events';

  @override
  String get label => 'Événements — Ville de Montréal (données ouvertes)';

  @override
  ActivityKind get kind => ActivityKind.event;

  @override
  bool get isConfigured => true; // keyless

  @override
  String? get needsKeyNote => null;

  @override
  Future<List<CatalogEntry>> fetchAvailableNow(LiveQuery q) async {
    final body = await _get(_uriFor(q), timeout: const Duration(seconds: 5));
    if (body == null) return const [];
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['success'] != true) return const [];
      final records = decoded['result']?['records'];
      if (records is! List) return const [];
      final out = <CatalogEntry>[];
      for (final r in records) {
        if (r is! Map) continue;
        final e = _project(r);
        if (e != null) out.add(e);
        if (out.length >= q.limit) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Uri _uriFor(LiveQuery q) {
    final today = _ymd(q.when);
    // Future-dated, geo-located, leisure-relevant events, soonest first.
    final sql = 'SELECT _id,titre,description,date_debut,date_fin,'
        'type_evenement,cout,arrondissement,url_fiche,lat,long '
        'FROM "$resourceId" '
        "WHERE date_debut >= '$today' "
        'AND lat IS NOT NULL AND long IS NOT NULL '
        "AND type_evenement NOT ILIKE '%conseil%' "
        "AND type_evenement NOT ILIKE '%consultation%' "
        "AND type_evenement NOT ILIKE '%séance%' "
        "AND type_evenement NOT ILIKE '%assemblée%' "
        'ORDER BY date_debut ASC '
        'LIMIT ${q.limit * 3}';
    return Uri.parse(endpoint).replace(queryParameters: {'sql': sql});
  }

  CatalogEntry? _project(Map r) {
    final title = _str(r['titre']);
    final start = _str(r['date_debut']);
    final lat = _num(r['lat']);
    final lng = _num(r['long']);
    if (title.isEmpty || start.isEmpty || lat == null || lng == null) return null;

    final type = _str(r['type_evenement']);
    final category = _categoryFor(type);
    final free = _str(r['cout']).toLowerCase().contains('gratuit');
    final hood = _str(r['arrondissement']);
    final url = _str(r['url_fiche']);
    final idRaw = _str(r['_id']);

    return CatalogEntry(
      id: 'mtlevt_${idRaw.isEmpty ? title.hashCode.toRadixString(16) : idRaw}',
      name: title,
      kind: ActivityKind.event,
      availability: Availability.live,
      category: category,
      subcategory: type.isEmpty ? null : type,
      descFr: _trim(_str(r['description']), title),
      imageRef: _assetFor(category), // dataset has no photo → category-accurate
      tags: _tagsFor(category, free),
      motives: (hedonic: 0.6, relaxation: 0.45, eudaimonic: 0.6),
      tagList: type.isEmpty ? const [] : [type],
      priceTier: free ? 0 : 2,
      effortLevel: 0.3,
      indoor: true,
      timeOfDay: const ['apresMidi', 'soir'],
      winterFriendly: true,
      source: 'montreal_opendata',
      sourceId: idRaw.isEmpty ? null : idRaw,
      confidence: 0.7,
      lat: lat,
      lng: lng,
      neighbourhood: hood.isEmpty ? null : hood,
      startsAt: start,
      endsAt: _str(r['date_fin']).isEmpty ? null : _str(r['date_fin']),
      url: url.isEmpty ? null : url,
      imageLicense: 'CC BY 4.0',
      imageAttribution: 'Ville de Montréal — données ouvertes (CC BY 4.0)',
    );
  }

  // Reasonable taste-axis defaults for an event of [category] (events read as a
  // genuine discovery — high novelty — and lean social/daytime/outing).
  Map<Dimension, double> _tagsFor(ActivityCategory c, bool free) => {
        Dimension.energy: c == ActivityCategory.active ? 0.7 : 0.45,
        Dimension.social: 0.6,
        Dimension.novelty: 0.78,
        Dimension.distance: 0.5,
        Dimension.indoor: c == ActivityCategory.nature ? 0.3 : 0.6,
        Dimension.timing: 0.55,
        Dimension.budget: free ? 0.1 : 0.55,
        Dimension.vibe: 0.6,
      };

  ActivityCategory _categoryFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('jardin') || t.contains('nature') || t.contains('plein air') ||
        t.contains('environnement')) {
      return ActivityCategory.nature;
    }
    if (t.contains('sport')) return ActivityCategory.active;
    if (t.contains('art') || t.contains('artisanat') || t.contains('jeu') ||
        t.contains('création') || t.contains('atelier')) {
      return ActivityCategory.creative;
    }
    if (t.contains('gastronom') || t.contains('culinaire') || t.contains('marché')) {
      return ActivityCategory.food;
    }
    // conte, histoire, science, expo, musique, cinéma, théâtre, conférence, famille…
    return ActivityCategory.culture;
  }

  String _assetFor(ActivityCategory c) {
    switch (c) {
      case ActivityCategory.nature:
        return Img.park;
      case ActivityCategory.active:
        return Img.sports;
      case ActivityCategory.creative:
        return Img.gallery;
      case ActivityCategory.food:
        return Img.market;
      case ActivityCategory.cafe:
        return Img.cafe;
      case ActivityCategory.nightlife:
        return Img.bar;
      case ActivityCategory.wellness:
        return Img.garden;
      case ActivityCategory.culture:
        return Img.museum;
    }
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _str(Object? v) => v == null ? '' : v.toString().trim();

  static double? _num(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_str(v));
  }

  /// Trim a description to one tidy clause; fall back to a generic line keyed to
  /// the title so the card always has prose.
  static String _trim(String desc, String title) {
    final d = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (d.isEmpty || d.toLowerCase() == 'nan') {
      return 'Un événement à Montréal, en ce moment.';
    }
    if (d.length <= 200) return d;
    final cut = d.substring(0, 200);
    final lastDot = cut.lastIndexOf('. ');
    return (lastDot > 80 ? cut.substring(0, lastDot + 1) : '$cut…');
  }
}
