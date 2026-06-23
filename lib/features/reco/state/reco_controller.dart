import 'package:flutter/foundation.dart';

import '../../../core/geo/geo.dart';
import '../../../core/persistence/app_store.dart';
import '../../guest/model/activity_axes.dart';
import '../../guest/model/guest_profile.dart';
import '../../guest/model/moment.dart';
import '../content/llm_content_provider.dart';
import '../data/activity_catalog.dart';
import '../data/osm_place_repository.dart';
import '../db/activity_repository.dart';
import '../engine/recommendation_engine.dart';
import '../engine/reco_context.dart';
import '../live/live_availability_service.dart';
import '../live/live_source.dart';
import '../live/weather_service.dart';
import '../memory/preference_memory.dart';
import '../model/activity.dart';
import '../model/recommendation.dart';

/// The STABLE recommendation pool (S10.1): OUR multi-source database, sliced to
/// static-availability rows only (places/travel/online), then the thin OSM
/// snapshot, then the hand-authored seed catalog — each a safe fallback for the
/// next so the loop never starves. Films/events are deliberately excluded: they
/// are time-sensitive and served by the live layer (S10.1B), not these snapshot
/// rows.
List<Activity> staticActivityCatalog() {
  if (ActivityRepository.isLoaded) return ActivityRepository.staticActivities;
  if (OsmPlaceRepository.isLoaded) return OsmPlaceRepository.activities;
  return kActivityCatalog;
}

/// The full pool the reco engine ranks (S10.1B): the always-present static pool,
/// PLUS the fresh live items the live layer fetched, PLUS — for any LIVE kind the
/// live layer could NOT supply (offline, no key, error) — the snapshot rows of
/// that kind as a graceful OFFLINE FALLBACK. So events/films served live when
/// available, degrade to stale-but-safe snapshot suggestions otherwise, and the
/// loop never starves.
List<Activity> liveActivityCatalog() {
  if (!ActivityRepository.isLoaded) return staticActivityCatalog();
  final out = <Activity>[...ActivityRepository.staticActivities];
  out.addAll(ActivityRepository.liveNowEntries.map((e) => e.toActivity()));
  final fresh = ActivityRepository.liveNowKinds;
  for (final e in ActivityRepository.liveEntries) {
    if (!fresh.contains(e.kind)) out.add(e.toActivity());
  }
  return out;
}

/// Drives the immersive reco loop with live revealed-preference learning.
///
/// Wraps the shared [GuestProfile]: it shows the current best recommendation,
/// and each Intéressant / Pas intéressant *reaction* (S9A) nudges the profile
/// toward (or away from) that activity's axes, records an anti-repeat decision,
/// and re-ranks immediately — so the next scene already reflects what was just
/// learned. Reactions FEED the profile; they never end the loop (only Planifier,
/// handled by the screen, selects an activity).
class RecoController extends ChangeNotifier {
  RecoController({
    required this.profile,
    RecommendationEngine? engine,
    RecoContext? context,
    GeoResult? location,
    this.store,
    this.liveService,
    this.weatherService,
    PreferenceMemory? memory,
    MomentContext? moment,
  })  :
        // ignore: prefer_initializing_formals — kept explicit alongside _moment.
        _memory = memory,
        _moment = moment ?? MomentContext.now(),
        engine = engine ??
            RecommendationEngine(
              catalog: liveActivityCatalog(),
              // S15C: pick the LLM-backed content provider when a proxy is
              // configured, else the deterministic templated one.
              content: appContentProvider(),
            ),
        _location = location ?? store?.readGeo() ?? GeoResult.fallback,
        context = context ??
            RecoContext.now(
              userLat: (location ?? store?.readGeo() ?? GeoResult.fallback).lat,
              userLng: (location ?? store?.readGeo() ?? GeoResult.fallback).lng,
            ) {
    _hydrate();
    _rank();
    // S10.1B: fetch the LIVE availability layer in the background. Safe: the
    // service never throws, and on failure/empty the static + snapshot fallback
    // already ranked above stays exactly as-is.
    if (liveService != null) _loadLive();
    // S12B: fetch live weather in the background and fold the signal into the
    // context so S11's feasibility flips ON (rain/snow → drop open-air; deep
    // cold → drop non-winter-friendly outdoors). Offline → null → filter stays
    // skipped, ranking already shown is untouched.
    if (weatherService != null) _loadWeather();
  }

  final GuestProfile profile;
  RecommendationEngine engine;
  RecoContext context;
  final AppStore? store;

  /// The LIVE availability layer (S10.1B). Null in tests / pure-offline mode →
  /// no runtime network, recommendations come from the static pool + fallback.
  final LiveAvailabilityService? liveService;

  /// The keyless live weather source (S12B). Null in tests / pure-offline mode →
  /// no weather signal, so the weather feasibility filter stays skipped.
  final WeatherService? weatherService;

  /// S19B: the cross-session temporal preference memory. When present it drives
  /// moment-aware suppression + resurfacing (and records each reaction with its
  /// moment); when null the controller keeps the legacy permanent-decided
  /// behaviour, so offline tests are unchanged.
  final PreferenceMemory? _memory;

  /// S19A: the moment (day-of-week + hour) this reco round belongs to.
  final MomentContext _moment;

  MoodBucket get _mood => MoodBucket.of(profile);

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Fetch live events/films, fold them into the catalog and re-rank. Time-
  /// sensitive items are held in memory only (never persisted).
  Future<void> _loadLive() async {
    final svc = liveService;
    if (svc == null) return;
    try {
      final items = await svc.fetchAvailableNow(LiveQuery(
        lat: _location.lat,
        lng: _location.lng,
        when: DateTime.now(),
        contexts: profile.contexts,
        limit: 8,
      ));
      ActivityRepository.setLiveNow(items);
      engine = RecommendationEngine(
        catalog: liveActivityCatalog(),
        content: engine.content,
      );
      _rank();
      if (!_disposed) notifyListeners();
    } catch (_) {/* keep the static + fallback ranking already shown */}
  }

  /// Fetch the current weather for the active location, fold the signal into the
  /// context and re-rank so feasibility reflects the real sky. Never throws; a
  /// null signal (offline) leaves the weather filter skipped.
  Future<void> _loadWeather() async {
    final svc = weatherService;
    if (svc == null) return;
    try {
      final signal = await svc.currentSignal(_location.lat, _location.lng);
      if (signal == context.weather) return; // no change → no churn
      context = context.withWeather(signal);
      _rank();
      if (!_disposed) notifyListeners();
    } catch (_) {/* keep the ranking already shown */}
  }

  GeoResult _location;

  /// The location currently driving distances (a real fix, or Montréal centre).
  GeoResult get location => _location;

  /// Update the guest's location once geolocation resolves, then re-rank so the
  /// nearer real places move up. Persists the status for next launch.
  void setLocation(GeoResult result) {
    _location = result;
    context = context.withUser(result.lat, result.lng);
    store?.saveGeo(result);
    _rank();
    notifyListeners();
    // S12B: a new (real) location warrants a fresh weather read.
    if (weatherService != null) _loadWeather();
  }

  final Set<String> _decided = {}; // liked or disliked → never re-shown
  final Set<ActivityCategory> _likedCategories = {};
  final List<Activity> _liked = [];

  /// Restore the revealed-preference history from storage so a relaunch doesn't
  /// re-surface already-decided picks and the learned categories carry over.
  void _hydrate() {
    final memory = _memory;
    if (memory != null) {
      // S19B: cross-session suppression is now MOMENT-AWARE — a disliked pick is
      // hidden only in the same slot+mood, a liked one only the same day, and a
      // planned one always. So a liked-but-unlived pick can resurface on another
      // day (see [_rank]'s resurface set), unlike the legacy blanket "decided".
      _decided.addAll(memory.suppressedFor(
        slot: _moment.slot,
        mood: _mood,
        today: _moment.todayKey,
      ));
    }
    final store = this.store;
    if (store == null) return;
    // Legacy permanent-decided suppression only when there's no moment memory.
    if (memory == null) _decided.addAll(store.readDecidedIds());
    for (final id in store.readLikedIds()) {
      final a = _activityById(id);
      if (a != null) {
        _liked.add(a);
        _likedCategories.add(a.category);
      }
    }
  }

  Activity? _activityById(String id) {
    for (final a in liveActivityCatalog()) {
      if (a.id == id) return a;
    }
    return null;
  }

  void _persist() {
    store
      ?..saveLearned(
        likedIds: _liked.map((a) => a.id),
        decidedIds: _decided,
      )
      ..saveProfile(profile);
  }

  List<Recommendation> _ranked = const [];

  // S15C: the fresh Claude-voiced "pourquoi" for the current pick, and the
  // activity id it belongs to. Until it arrives (or if the proxy is down) the
  // screen shows the deterministic [Recommendation.why] via [currentWhy].
  String? _generatedWhy;
  String? _whyForId;

  /// The best pick to show right now, or null when the guest has run out.
  Recommendation? get current => _ranked.isEmpty ? null : _ranked.first;

  /// The "pourquoi" to display for the current pick: the fresh Claude wording
  /// once it has arrived for this exact activity, else the deterministic line.
  String? get currentWhy {
    final rec = current;
    if (rec == null) return null;
    if (_whyForId == rec.activity.id && _generatedWhy != null) {
      return _generatedWhy;
    }
    return rec.why;
  }

  /// Up to a handful of upcoming picks (best first), for any "queue" affordance.
  List<Recommendation> get ranked => List.unmodifiable(_ranked);

  List<Activity> get liked => List.unmodifiable(_liked);
  bool get isExhausted => _ranked.isEmpty;

  void _rank() {
    final resurfaced = _memory?.resurfacedFor(
          slot: _moment.slot,
          mood: _mood,
          today: _moment.todayKey,
        ) ??
        const <String>{};
    _ranked = engine.recommend(
      profile,
      context: context,
      excludedIds: _decided,
      likedCategories: _likedCategories,
      resurfacedIds: resurfaced,
    );
    _maybeGenerateWhy();
  }

  /// Kick off a fresh Claude "pourquoi" for the current pick in the background
  /// (only when the LLM provider is active and we don't already have/await one
  /// for this activity). Never blocks ranking; on arrival it swaps the line in.
  void _maybeGenerateWhy() {
    final rec = current;
    final content = engine.content;
    if (rec == null || content is! LlmContentProvider || !content.active) return;
    if (_whyForId == rec.activity.id) return; // already have it / fetching it
    _whyForId = rec.activity.id;
    _generatedWhy = null;
    final targetId = rec.activity.id;
    content.generateWhy(rec, profile, context: context).then((text) {
      if (_disposed) return;
      if (_whyForId == targetId) {
        _generatedWhy = text;
        notifyListeners();
      }
    });
  }

  /// Re-rank against the current profile and notify. Used by the adaptive loop
  /// (S9B) after a question batch has sharpened the profile *between* reco
  /// rounds, so the next round already reflects the newly learned taste.
  void refresh() {
    _rank();
    notifyListeners();
  }

  /// Intéressant (S9A): pull the profile toward this activity and re-rank. A
  /// revealed-preference reaction, not a selection — the loop continues.
  void markInteresting() {
    final rec = current;
    if (rec == null) return;
    _applyAxes(rec.activity, toward: true);
    _decided.add(rec.activity.id);
    _likedCategories.add(rec.activity.category);
    _liked.add(rec.activity);
    _remember(rec.activity, liked: true);
    _rank();
    _persist();
    notifyListeners();
  }

  /// Pas intéressant (S9A): push the profile away from this activity, anti-repeat,
  /// re-rank. A reaction, not a rejection of the whole loop.
  void markNotInteresting() {
    final rec = current;
    if (rec == null) return;
    _applyAxes(rec.activity, toward: false);
    _decided.add(rec.activity.id);
    _remember(rec.activity, liked: false);
    _rank();
    _persist();
    notifyListeners();
  }

  /// S19B: stamp a reaction into the temporal memory WITH its moment, and
  /// persist it so the learning carries across sessions. No-op when the memory
  /// isn't wired (offline tests).
  void _remember(Activity a, {required bool liked}) {
    final memory = _memory;
    if (memory == null) return;
    memory.recordReaction(
      activityId: a.id,
      liked: liked,
      moment: _moment,
      mood: _mood,
    );
    store?.saveMemory(memory);
  }

  /// S19D: the guest turned [activityId] into a plan — mark it lived in the
  /// memory so it stops resurfacing as "a preference you haven't lived yet".
  void markPlanned(String activityId) {
    final memory = _memory;
    if (memory == null) return;
    memory.markPlanned(activityId);
    store?.saveMemory(memory);
  }

  /// Nudge every axis toward the activity (like) or its mirror (dislike).
  void _applyAxes(Activity a, {required bool toward}) {
    for (final d in kActivityAxes) {
      final target = toward ? a.tag(d) : (1 - a.tag(d));
      profile.nudge(d, target, weight: toward ? 0.22 : 0.16);
    }
  }
}
