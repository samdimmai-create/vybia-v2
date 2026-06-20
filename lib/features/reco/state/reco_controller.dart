import 'package:flutter/foundation.dart';

import '../../../core/geo/geo.dart';
import '../../../core/persistence/app_store.dart';
import '../../guest/model/activity_axes.dart';
import '../../guest/model/guest_profile.dart';
import '../data/activity_catalog.dart';
import '../data/osm_place_repository.dart';
import '../engine/recommendation_engine.dart';
import '../engine/reco_context.dart';
import '../model/activity.dart';
import '../model/recommendation.dart';

/// The live recommendation catalog: real OSM-backed Montréal activities when the
/// snapshot loaded, otherwise the hand-authored seed catalog as a safe fallback.
List<Activity> liveActivityCatalog() =>
    OsmPlaceRepository.isLoaded ? OsmPlaceRepository.activities : kActivityCatalog;

/// Drives the immersive reco loop with live revealed-preference learning.
///
/// Wraps the shared [GuestProfile]: it shows the current best recommendation,
/// and each J'aime / Pas pour moi nudges the profile toward (or away from) that
/// activity's axes, records an anti-repeat decision, and re-ranks immediately —
/// so the next scene already reflects what was just learned.
class RecoController extends ChangeNotifier {
  RecoController({
    required this.profile,
    RecommendationEngine? engine,
    RecoContext? context,
    GeoResult? location,
    this.store,
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
  }

  final GuestProfile profile;
  final RecommendationEngine engine;
  RecoContext context;
  final AppStore? store;

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

  /// J'aime: pull the profile toward this activity and re-rank.
  void like() {
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

  /// Pas pour moi: push the profile away from this activity, anti-repeat, re-rank.
  void dislike() {
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
