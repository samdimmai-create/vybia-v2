import 'package:flutter/foundation.dart';

import '../../../core/geo/geo.dart';
import '../../../core/persistence/app_store.dart';
import '../../guest/model/activity_axes.dart';
import '../../guest/model/guest_profile.dart';
import '../data/activity_catalog.dart';
import '../data/osm_place_repository.dart';
import '../db/activity_repository.dart';
import '../engine/recommendation_engine.dart';
import '../engine/reco_context.dart';
import '../live/live_availability_service.dart';
import '../live/live_source.dart';
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
  })  : engine =
            engine ?? RecommendationEngine(catalog: liveActivityCatalog()),
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
  }

  final GuestProfile profile;
  RecommendationEngine engine;
  RecoContext context;
  final AppStore? store;

  /// The LIVE availability layer (S10.1B). Null in tests / pure-offline mode →
  /// no runtime network, recommendations come from the static pool + fallback.
  final LiveAvailabilityService? liveService;

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
  }

  final Set<String> _decided = {}; // liked or disliked → never re-shown
  final Set<ActivityCategory> _likedCategories = {};
  final List<Activity> _liked = [];

  /// Restore the revealed-preference history from storage so a relaunch doesn't
  /// re-surface already-decided picks and the learned categories carry over.
  void _hydrate() {
    final store = this.store;
    if (store == null) return;
    _decided.addAll(store.readDecidedIds());
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

  /// The best pick to show right now, or null when the guest has run out.
  Recommendation? get current => _ranked.isEmpty ? null : _ranked.first;

  /// Up to a handful of upcoming picks (best first), for any "queue" affordance.
  List<Recommendation> get ranked => List.unmodifiable(_ranked);

  List<Activity> get liked => List.unmodifiable(_liked);
  bool get isExhausted => _ranked.isEmpty;

  void _rank() {
    _ranked = engine.recommend(
      profile,
      context: context,
      excludedIds: _decided,
      likedCategories: _likedCategories,
    );
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
    _rank();
    _persist();
    notifyListeners();
  }

  /// Nudge every axis toward the activity (like) or its mirror (dislike).
  void _applyAxes(Activity a, {required bool toward}) {
    for (final d in kActivityAxes) {
      final target = toward ? a.tag(d) : (1 - a.tag(d));
      profile.nudge(d, target, weight: toward ? 0.22 : 0.16);
    }
  }
}
