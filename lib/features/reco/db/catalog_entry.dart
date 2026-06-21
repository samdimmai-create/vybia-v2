import '../../guest/model/dimension.dart';
import '../model/activity.dart';
import '../model/activity_kind.dart';
import '../model/motive.dart';

/// One record in OUR multi-source activity database (S10).
///
/// This is the durable, serializable, LLM-ready schema — the persisted shape on
/// disk (`assets/data/vybia_catalog.json` + the writable overlay) and the exact
/// thing a future Claude call reads, enriches and writes back. It is richer than
/// the engine's lean [Activity] (which is just the scoring shape): a
/// [CatalogEntry] carries provenance, every life-context flag, time/season fit
/// and the kind-specific facts, then projects down to an [Activity] for scoring
/// via [toActivity].
///
/// Design goals:
///   * ONE record type for every [ActivityKind] (place/event/film/online/travel)
///     — kind-specific fields are nullable rather than subclasses, so a slice
///     serialises cheaply into a prompt and the repository stays flat + fast.
///   * Lossless round-trip ([toJson]/[fromJson]) so write-back never degrades a
///     record.
///   * Compact field names where it matters for the prompt slice ([llmSlice]).
class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.name,
    required this.kind,
    required this.category,
    required this.descFr,
    required this.imageRef,
    required this.tags,
    required this.motives,
    required this.priceTier,
    required this.indoor,
    this.subcategory,
    this.lms,
    this.tagList = const [],
    this.kidFriendly,
    this.servesAlcohol,
    this.wheelchairAccessible,
    this.petFriendly,
    this.effortLevel = 0.4,
    this.timeOfDay = const [],
    this.seasons = const [],
    this.winterFriendly = true,
    this.source = 'seed',
    this.sourceId,
    this.enrichedAt,
    this.confidence = 0.5,
    // kind-specific (nullable)
    this.lat,
    this.lng,
    this.neighbourhood,
    this.address,
    this.startsAt,
    this.endsAt,
    this.runtimeMin,
    this.year,
    this.genre,
    this.whereToWatch,
    this.url,
    this.provider,
    this.destination,
    this.distanceKm,
    this.duration,
    this.imageAttribution,
    this.imageLicense,
  });

  // ---- Common ----
  final String id;
  final String name;
  final ActivityKind kind;
  final ActivityCategory category;
  final String? subcategory;
  final String descFr;

  /// Asset path or URL of the one fitting image (S10C).
  final String imageRef;

  /// The eight taste-dim affinities (same axes + polarity as [Activity.tags]).
  final Map<Dimension, double> tags;

  /// The three (hedonic, relaxation, eudaimonic) affinities the engine folds
  /// into LMS at runtime — the engine source of truth.
  final MotiveAffinity motives;

  /// The four Beard & Ragheb LMS-motive affinities, denormalised for the LLM
  /// slice (intellectual, social, competence, stimulusAvoidance). Optional: the
  /// engine recomputes this from [motives]+[tags], so it is informational only.
  final ({
    double intellectual,
    double social,
    double competence,
    double stimulusAvoidance,
  })? lms;

  /// Free-form descriptive tags (genres, themes) — searchable, LLM-friendly.
  final List<String> tagList;

  // ---- Life-context flags ----
  final bool? kidFriendly;
  final bool? servesAlcohol;
  final bool? wheelchairAccessible;
  final bool? petFriendly;

  /// 0 = free, 1 = cheap, 2 = mid, 3 = splurge (== engine budget).
  final int priceTier;

  /// 0 effortless … 1 strenuous.
  final double effortLevel;

  final bool indoor;

  /// Fitting parts of day: any of `matin`, `apresMidi`, `soir`, `nuit`.
  final List<String> timeOfDay;

  /// Fitting seasons: any of `printemps`, `ete`, `automne`, `hiver`.
  final List<String> seasons;

  final bool winterFriendly;

  // ---- Provenance ----
  /// Where this came from: `seed`, `osm`, `wikidata`, `wikivoyage`, `tmdb`,
  /// `commons`, `donneesquebec`, `claude`…
  final String source;
  final String? sourceId;

  /// ISO-8601 instant of the last enrichment write-back, null if never enriched.
  final String? enrichedAt;

  /// 0..1 confidence in the record's completeness/quality.
  final double confidence;

  // ---- Kind-specific (nullable) ----
  // place / event:
  final double? lat;
  final double? lng;
  final String? neighbourhood;
  final String? address;
  // event:
  final String? startsAt; // ISO-8601
  final String? endsAt; // ISO-8601
  // film:
  final int? runtimeMin;
  final int? year;
  final String? genre;
  final String? whereToWatch; // cinema | netflix | prime | …
  // online:
  final String? url;
  final String? provider;
  // travel:
  final String? destination;
  final double? distanceKm; // from the home city
  final String? duration; // e.g. "demi-journée", "week-end"
  // image attribution (S10C):
  final String? imageAttribution;
  final String? imageLicense;

  bool get hasLocation => lat != null && lng != null;

  double tag(Dimension d) => tags[d] ?? 0.5;

  // -------------------------------------------------------------------------
  // Engine projection
  // -------------------------------------------------------------------------

  /// Project this rich record down to the engine's lean scoring [Activity].
  /// Non-geo kinds (film/online and travel without a fix) get `hasLocation:false`
  /// so the engine skips distance for them; a neutral centre coordinate keeps the
  /// types happy without ever reading as "right here".
  Activity toActivity({double fallbackLat = 45.5019, double fallbackLng = -73.5674}) {
    return Activity(
      id: id,
      titleFr: name,
      category: category,
      tags: tags,
      motives: motives,
      budget: priceTier,
      indoor: indoor,
      descFr: descFr,
      lat: lat ?? fallbackLat,
      lng: lng ?? fallbackLng,
      image: imageRef,
      winterFriendly: winterFriendly,
      kind: kind,
      hasLocation: hasLocation,
      kidFriendly: kidFriendly,
      servesAlcohol: servesAlcohol,
      wheelchairAccessible: wheelchairAccessible,
      petFriendly: petFriendly,
      effortLevel: effortLevel,
      source: source,
    );
  }

  // -------------------------------------------------------------------------
  // Serialization (lossless round-trip)
  // -------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'category': category.name,
        if (subcategory != null) 'subcategory': subcategory,
        'descFr': descFr,
        'imageRef': imageRef,
        'tags': {for (final e in tags.entries) e.key.name: e.value},
        'motives': {
          'hedonic': motives.hedonic,
          'relaxation': motives.relaxation,
          'eudaimonic': motives.eudaimonic,
        },
        if (lms != null)
          'lms': {
            'intellectual': lms!.intellectual,
            'social': lms!.social,
            'competence': lms!.competence,
            'stimulusAvoidance': lms!.stimulusAvoidance,
          },
        if (tagList.isNotEmpty) 'tagList': tagList,
        if (kidFriendly != null) 'kidFriendly': kidFriendly,
        if (servesAlcohol != null) 'servesAlcohol': servesAlcohol,
        if (wheelchairAccessible != null)
          'wheelchairAccessible': wheelchairAccessible,
        if (petFriendly != null) 'petFriendly': petFriendly,
        'priceTier': priceTier,
        'effortLevel': effortLevel,
        'indoor': indoor,
        if (timeOfDay.isNotEmpty) 'timeOfDay': timeOfDay,
        if (seasons.isNotEmpty) 'seasons': seasons,
        'winterFriendly': winterFriendly,
        'source': source,
        if (sourceId != null) 'sourceId': sourceId,
        if (enrichedAt != null) 'enrichedAt': enrichedAt,
        'confidence': confidence,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (neighbourhood != null) 'neighbourhood': neighbourhood,
        if (address != null) 'address': address,
        if (startsAt != null) 'startsAt': startsAt,
        if (endsAt != null) 'endsAt': endsAt,
        if (runtimeMin != null) 'runtimeMin': runtimeMin,
        if (year != null) 'year': year,
        if (genre != null) 'genre': genre,
        if (whereToWatch != null) 'whereToWatch': whereToWatch,
        if (url != null) 'url': url,
        if (provider != null) 'provider': provider,
        if (destination != null) 'destination': destination,
        if (distanceKm != null) 'distanceKm': distanceKm,
        if (duration != null) 'duration': duration,
        if (imageAttribution != null) 'imageAttribution': imageAttribution,
        if (imageLicense != null) 'imageLicense': imageLicense,
      };

  /// Parse one record, returning null for anything missing the essentials so a
  /// single malformed row can never crash the whole DB load.
  static CatalogEntry? tryFromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final name = j['name'];
    final cat = _catByName(j['category'] as String?);
    if (id is! String || name is! String || cat == null) return null;

    final tags = <Dimension, double>{};
    final rawTags = j['tags'];
    if (rawTags is Map) {
      for (final e in rawTags.entries) {
        final d = _dimByName(e.key as String?);
        final v = (e.value as num?)?.toDouble();
        if (d != null && v != null) tags[d] = v;
      }
    }

    final m = j['motives'];
    final motives = m is Map
        ? (
            hedonic: (m['hedonic'] as num?)?.toDouble() ?? 0.5,
            relaxation: (m['relaxation'] as num?)?.toDouble() ?? 0.5,
            eudaimonic: (m['eudaimonic'] as num?)?.toDouble() ?? 0.5,
          )
        : (hedonic: 0.5, relaxation: 0.5, eudaimonic: 0.5);

    final lmsRaw = j['lms'];
    final lms = lmsRaw is Map
        ? (
            intellectual: (lmsRaw['intellectual'] as num?)?.toDouble() ?? 0.25,
            social: (lmsRaw['social'] as num?)?.toDouble() ?? 0.25,
            competence: (lmsRaw['competence'] as num?)?.toDouble() ?? 0.25,
            stimulusAvoidance:
                (lmsRaw['stimulusAvoidance'] as num?)?.toDouble() ?? 0.25,
          )
        : null;

    return CatalogEntry(
      id: id,
      name: name,
      kind: ActivityKind.fromName(j['kind'] as String?),
      category: cat,
      subcategory: j['subcategory'] as String?,
      descFr: j['descFr'] as String? ?? '',
      imageRef: j['imageRef'] as String? ?? '',
      tags: tags,
      motives: motives,
      lms: lms,
      tagList: _strList(j['tagList']),
      kidFriendly: j['kidFriendly'] as bool?,
      servesAlcohol: j['servesAlcohol'] as bool?,
      wheelchairAccessible: j['wheelchairAccessible'] as bool?,
      petFriendly: j['petFriendly'] as bool?,
      priceTier: (j['priceTier'] as num?)?.toInt() ?? 1,
      effortLevel: (j['effortLevel'] as num?)?.toDouble() ?? 0.4,
      indoor: j['indoor'] as bool? ?? true,
      timeOfDay: _strList(j['timeOfDay']),
      seasons: _strList(j['seasons']),
      winterFriendly: j['winterFriendly'] as bool? ?? true,
      source: j['source'] as String? ?? 'seed',
      sourceId: j['sourceId'] as String?,
      enrichedAt: j['enrichedAt'] as String?,
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0.5,
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      neighbourhood: j['neighbourhood'] as String?,
      address: j['address'] as String?,
      startsAt: j['startsAt'] as String?,
      endsAt: j['endsAt'] as String?,
      runtimeMin: (j['runtimeMin'] as num?)?.toInt(),
      year: (j['year'] as num?)?.toInt(),
      genre: j['genre'] as String?,
      whereToWatch: j['whereToWatch'] as String?,
      url: j['url'] as String?,
      provider: j['provider'] as String?,
      destination: j['destination'] as String?,
      distanceKm: (j['distanceKm'] as num?)?.toDouble(),
      duration: j['duration'] as String?,
      imageAttribution: j['imageAttribution'] as String?,
      imageLicense: j['imageLicense'] as String?,
    );
  }

  /// A compact, prompt-friendly view of this record — the exact shape a future
  /// Claude enrichment call receives. Drops the heavy/derived fields, keeps the
  /// facts a model needs to reason or fill gaps.
  Map<String, dynamic> llmSlice() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'category': category.name,
        if (subcategory != null) 'sub': subcategory,
        'desc': descFr,
        if (tagList.isNotEmpty) 'tags': tagList,
        'price': priceTier,
        'indoor': indoor,
        if (timeOfDay.isNotEmpty) 'time': timeOfDay,
        if (seasons.isNotEmpty) 'season': seasons,
        if (neighbourhood != null) 'hood': neighbourhood,
        if (genre != null) 'genre': genre,
        if (whereToWatch != null) 'watch': whereToWatch,
        if (destination != null) 'dest': destination,
        if (startsAt != null) 'starts': startsAt,
        'source': source,
        'confidence': confidence,
      };

  /// Copy with a patch applied (used by the enrichment write-back path, S10E).
  CatalogEntry copyWith(Map<String, dynamic> patch) {
    final merged = toJson()..addAll(patch);
    return tryFromJson(merged) ?? this;
  }

  static List<String> _strList(dynamic v) =>
      v is List ? v.whereType<String>().toList(growable: false) : const [];

  static ActivityCategory? _catByName(String? s) {
    for (final c in ActivityCategory.values) {
      if (c.name == s) return c;
    }
    return null;
  }

  static Dimension? _dimByName(String? s) {
    for (final d in Dimension.values) {
      if (d.name == s) return d;
    }
    return null;
  }
}
