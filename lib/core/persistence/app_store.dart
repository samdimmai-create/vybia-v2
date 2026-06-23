import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/guest/model/guest_profile.dart';
import '../../features/guest/state/guest_controller.dart';
import '../geo/geo.dart';
import '../../features/plans/model/plan.dart';
import '../../features/reco/data/activity_catalog.dart';
import '../../features/reco/data/osm_place_repository.dart';
import '../../features/reco/db/activity_repository.dart';
import '../../features/reco/db/catalog_entry.dart';
import '../../features/reco/memory/preference_memory.dart';
import '../../features/reco/model/activity.dart';

/// The single local persistence repository for the whole guest model.
///
/// Backed by [SharedPreferences] (localStorage on web). Pure storage + JSON
/// (de)serialization — no UI, no Flutter widgets. Everything the guest builds up
/// across a session — the taste profile (declared dimensions + the learned
/// values the engine and revealed-preference loop inferred), the current mood,
/// the liked/decided activity history, the chosen intention and the saved plans
/// — is persisted here so recommendations stay consistent across relaunches.
class AppStore {
  AppStore(this._prefs);

  final SharedPreferences _prefs;

  // Versioned keys so a future schema change is a clean migration, not a crash.
  static const _kProfile = 'vybia.profile.v1';
  static const _kLiked = 'vybia.liked.v1'; // liked activity ids (revealed pref)
  static const _kDecided = 'vybia.decided.v1'; // liked OR disliked ids
  static const _kPlans = 'vybia.plans.v1';
  static const _kIntention = 'vybia.intention.v1';
  static const _kSeeded = 'vybia.seeded.v1'; // first-run seed guard
  static const _kGeo = 'vybia.geo.v1'; // last resolved location + status
  static const _kOverlay = 'vybia.db.overlay.v1'; // S10E enriched/upserted records
  static const _kPalette = 'vybia.palette.v1'; // S15.0 edge palette index (persisted)
  static const _kMemory = 'vybia.memory.v1'; // S19B temporal preference memory

  /// Open the store, loading the backing prefs. Call once before first paint.
  static Future<AppStore> open() async =>
      AppStore(await SharedPreferences.getInstance());

  // ---- Profile (declared dimensions + mood + learned values) ---------------

  Map<String, dynamic>? readProfileJson() {
    final raw = _prefs.getString(_kProfile);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> saveProfile(GuestProfile profile) =>
      _prefs.setString(_kProfile, jsonEncode(profile.toJson()));

  // ---- Learned revealed-preference history ---------------------------------

  List<String> readLikedIds() => _prefs.getStringList(_kLiked) ?? const [];
  List<String> readDecidedIds() => _prefs.getStringList(_kDecided) ?? const [];

  Future<void> saveLearned({
    required Iterable<String> likedIds,
    required Iterable<String> decidedIds,
  }) async {
    await _prefs.setStringList(_kLiked, likedIds.toList());
    await _prefs.setStringList(_kDecided, decidedIds.toList());
  }

  // ---- Intention -----------------------------------------------------------

  Intention? readIntention() {
    final name = _prefs.getString(_kIntention);
    if (name == null) return null;
    for (final i in Intention.values) {
      if (i.name == name) return i;
    }
    return null;
  }

  Future<void> saveIntention(Intention? intention) => intention == null
      ? _prefs.remove(_kIntention)
      : _prefs.setString(_kIntention, intention.name);

  // ---- Geolocation (last resolved location + permission status) -------------

  GeoResult? readGeo() {
    final raw = _prefs.getString(_kGeo);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? GeoResult.fromJson(decoded) : null;
  }

  Future<void> saveGeo(GeoResult geo) =>
      _prefs.setString(_kGeo, jsonEncode(geo.toJson()));

  // ---- Plans ---------------------------------------------------------------

  List<Plan> readPlans() {
    final raw = _prefs.getString(_kPlans);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    final out = <Plan>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final plan = _planFromJson(item);
        if (plan != null) out.add(plan);
      }
    }
    return out;
  }

  Future<void> savePlans(Iterable<Plan> plans) => _prefs.setString(
        _kPlans,
        jsonEncode([for (final p in plans) _planToJson(p)]),
      );

  Map<String, dynamic> _planToJson(Plan p) => {
        'id': p.id,
        'activity': p.activity.id,
        'moment': p.moment.name,
        'companions': p.companions.name,
        'when': p.when.toIso8601String(),
        'createdAt': p.createdAt.toIso8601String(),
      };

  Plan? _planFromJson(Map<String, dynamic> j) {
    final activity = _activityById(j['activity'] as String?);
    if (activity == null) return null; // catalog changed → drop stale plan
    final moment = _enumByName(PlanMoment.values, j['moment'] as String?);
    final companions =
        _enumByName(PlanCompanions.values, j['companions'] as String?);
    final when = DateTime.tryParse(j['when'] as String? ?? '');
    if (moment == null || companions == null || when == null) return null;
    return Plan(
      id: j['id'] as String? ?? 'plan_restored',
      activity: activity,
      moment: moment,
      companions: companions,
      when: when,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    );
  }

  Activity? _activityById(String? id) {
    if (id == null) return null;
    // S10: OUR multi-source DB first, then the OSM snapshot, then the seed.
    final db = ActivityRepository.activityById(id);
    if (db != null) return db;
    final osm = OsmPlaceRepository.activityById(id);
    if (osm != null) return osm;
    for (final a in kActivityCatalog) {
      if (a.id == id) return a;
    }
    return null;
  }

  T? _enumByName<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  // ---- DB write-back overlay (S10E) ----------------------------------------

  /// The enriched / upserted records the engine layers over the bundled catalog.
  List<CatalogEntry> readOverlay() {
    final raw = _prefs.getString(_kOverlay);
    if (raw == null) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    final out = <CatalogEntry>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final e = CatalogEntry.tryFromJson(item);
        if (e != null) out.add(e);
      }
    }
    return out;
  }

  Future<void> saveOverlay(Iterable<CatalogEntry> overlay) => _prefs.setString(
        _kOverlay,
        jsonEncode([for (final e in overlay) e.toJson()]),
      );

  // ---- Edge palette selection (S15.0) --------------------------------------

  /// The persisted edge-palette index. Null when the founder never changed it,
  /// so the app keeps the permanent default (A) rather than a stale value.
  int? readPaletteIndex() => _prefs.getInt(_kPalette);

  Future<void> savePaletteIndex(int index) => _prefs.setInt(_kPalette, index);

  // ---- Temporal preference memory (S19B) -----------------------------------

  /// The cross-session reaction/answer memory, stamped by moment. Empty (never
  /// null) on first run so callers can always record into it.
  PreferenceMemory readMemory() {
    final raw = _prefs.getString(_kMemory);
    if (raw == null) return PreferenceMemory();
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic>
        ? PreferenceMemory.fromJson(decoded)
        : PreferenceMemory();
  }

  Future<void> saveMemory(PreferenceMemory memory) =>
      _prefs.setString(_kMemory, jsonEncode(memory.toJson()));

  // ---- First-run seed guard ------------------------------------------------

  bool get hasSeeded => _prefs.getBool(_kSeeded) ?? false;
  Future<void> markSeeded() => _prefs.setBool(_kSeeded, true);

  /// Wipe everything (used by tests and a hypothetical "tout effacer").
  Future<void> clearAll() async {
    await _prefs.remove(_kProfile);
    await _prefs.remove(_kLiked);
    await _prefs.remove(_kDecided);
    await _prefs.remove(_kPlans);
    await _prefs.remove(_kIntention);
    await _prefs.remove(_kSeeded);
    await _prefs.remove(_kGeo);
    await _prefs.remove(_kOverlay);
    await _prefs.remove(_kPalette);
    await _prefs.remove(_kMemory);
  }
}
