import 'package:flutter/foundation.dart';

import '../../guest/model/activity_axes.dart';
import '../../guest/model/guest_profile.dart';
import '../data/activity_catalog.dart';
import '../engine/recommendation_engine.dart';
import '../engine/reco_context.dart';
import '../model/activity.dart';
import '../model/recommendation.dart';

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
  })  : engine = engine ?? const RecommendationEngine(catalog: kActivityCatalog),
        context = context ?? RecoContext.now() {
    _rank();
  }

  final GuestProfile profile;
  final RecommendationEngine engine;
  final RecoContext context;

  final Set<String> _decided = {}; // liked or disliked → never re-shown
  final Set<ActivityCategory> _likedCategories = {};
  final List<Activity> _liked = [];

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
    notifyListeners();
  }

  /// Pas pour moi: push the profile away from this activity, anti-repeat, re-rank.
  void dislike() {
    final rec = current;
    if (rec == null) return;
    _applyAxes(rec.activity, toward: false);
    _decided.add(rec.activity.id);
    _rank();
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
