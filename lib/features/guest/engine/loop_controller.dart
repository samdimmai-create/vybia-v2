import 'package:flutter/foundation.dart';

import '../../../core/geo/geo.dart';
import '../../../core/persistence/app_store.dart';
import '../../reco/engine/recommendation_engine.dart';
import '../../reco/engine/reco_context.dart';
import '../../reco/live/live_availability_service.dart';
import '../../reco/live/weather_service.dart';
import '../../reco/model/recommendation.dart';
import '../../reco/state/reco_controller.dart';
import '../data/question_bank.dart';
import '../model/guest_profile.dart';
import '../model/question.dart';
import 'adaptive_engine.dart';

/// The phases of the adaptive engine loop (S9B).
enum LoopPhase {
  /// Presenting an engine-chosen question batch (sharpens the profile).
  questions,

  /// The calm "Vybia réfléchit" bridge between a batch and a reco round.
  reflection,

  /// Presenting a round of recommendations to react to.
  recos,

  /// The guest hit Planifier on a recommendation — the loop is over.
  selected,

  /// No more questions and no more recommendations to show.
  exhausted,
}

/// THE adaptive engine, as an explicit state machine (S9B).
///
/// The product is a LOOP, not a one-shot: a small question batch sharpens the
/// profile → a reflection bridge → a round of recommendations the guest reacts
/// to (Intéressant / Pas intéressant feed the profile and re-rank live) → if the
/// guest hasn't selected, a NEW question batch targeting whatever is still
/// UNCERTAIN → reflection → new recs → … The loop ends only when the guest hits
/// Planifier on an activity ([select]) — or when both questions and recs run out
/// ([LoopPhase.exhausted]).
///
/// It is deliberately MODULAR and pure-logic (no Flutter widgets): the
/// [EngineLoopScreen] just renders [phase]. It composes the existing
/// [AdaptiveEngine] (question selection by information gain / least confidence)
/// and a [RecoController] (revealed-preference reco state), so the proven pieces
/// are reused rather than reinvented.
///
/// Convergence: question batches are tiny ([questionsPerBatch]) and bounded
/// ([maxRounds] alternations); each batch raises [GuestProfile.confidentCount],
/// so every round visibly sharpens the profile and the recommendations tighten.
/// Once the adaptive engine is confident enough it simply stops inserting new
/// question batches and keeps serving recommendations until a selection.
class LoopController extends ChangeNotifier {
  LoopController({
    required this.profile,
    AdaptiveEngine? questionEngine,
    RecommendationEngine? recoEngine,
    RecoContext? context,
    GeoResult? location,
    this.store,
    this.liveService,
    this.weatherService,
    this.questionsPerBatch = 3,
    this.recosPerRound = 4,
    this.maxRounds = 4,
  }) : questionEngine = questionEngine ?? AdaptiveEngine(bank: kQuestionBank) {
    _recoEngine = recoEngine;
    _context = context;
    _location = location;
    _beginQuestionBatch(first: true);
  }

  final GuestProfile profile;
  final AdaptiveEngine questionEngine;
  RecommendationEngine? _recoEngine;
  RecoContext? _context;
  GeoResult? _location;
  final AppStore? store;

  /// The LIVE availability layer (S10.1B), threaded into the [RecoController] so
  /// the reco round blends fresh events/films with the static pool. Null in
  /// tests → fully offline.
  final LiveAvailabilityService? liveService;

  /// The keyless live weather source (S12B), threaded into the [RecoController]
  /// so reco rounds reflect the real sky. Null in tests → no weather signal.
  final WeatherService? weatherService;

  /// How many questions a single batch may ask before yielding to a reco round.
  final int questionsPerBatch;

  /// How many recommendations a single round serves before the loop inserts a
  /// new (sharpening) question batch.
  final int recosPerRound;

  /// Hard cap on question↔reco alternations, so the loop always converges and
  /// can't bounce forever.
  final int maxRounds;

  LoopPhase _phase = LoopPhase.questions;
  LoopPhase get phase => _phase;

  RecoController? _reco;

  /// The composed reco state, available once the first reco round has begun.
  RecoController? get reco => _reco;

  int _round = 0; // completed reco rounds (alternations)
  int get round => _round;
  int _batchAsked = 0; // questions answered in the *current* batch
  int _roundReacted = 0; // reactions made in the *current* reco round

  Question? _question;

  /// The current question, or null when not in the [LoopPhase.questions] phase.
  Question? get currentQuestion =>
      _phase == LoopPhase.questions ? _question : null;

  /// The current recommendation, or null when not in [LoopPhase.recos].
  Recommendation? get currentReco =>
      _phase == LoopPhase.recos ? _reco?.current : null;

  /// How many dimensions are confident right now — rises as the loop converges
  /// (used by the UI / proof to show the profile sharpening across rounds).
  int get confidentCount => profile.confidentCount;

  /// Update the guest's location once geolocation resolves; forwards to the reco
  /// state if it's already been built so distances re-rank.
  void setLocation(GeoResult result) {
    _location = result;
    _reco?.setLocation(result);
  }

  // ---- Question batch ------------------------------------------------------

  void _beginQuestionBatch({bool first = false}) {
    _batchAsked = 0;
    final q = _pickQuestion(first: first);
    if (q == null) {
      // Nothing informative left to ask — go straight to recommendations.
      _beginReflection();
      return;
    }
    _question = q;
    _phase = LoopPhase.questions;
    notifyListeners();
  }

  Question? _pickQuestion({bool first = false}) {
    // The first batch always asks at least one question; later batches probe
    // only while real uncertainty remains.
    if (!first && questionEngine.isDone(profile)) return null;
    return questionEngine.next(profile);
  }

  /// Answer the current question; advances within the batch or, once the batch
  /// budget is spent (or the engine is confident enough), bridges to a reco
  /// round via the reflection.
  void answer(QOption option) {
    if (_phase != LoopPhase.questions) return;
    final q = _question;
    if (q == null) return;
    questionEngine.apply(profile, q, option);
    _persistProfile();
    _batchAsked++;

    final next = questionEngine.next(profile);
    final batchFull = _batchAsked >= questionsPerBatch;
    final converged = questionEngine.isDone(profile);
    if (next == null || batchFull || converged) {
      _beginReflection();
    } else {
      _question = next;
      notifyListeners();
    }
  }

  // ---- Reflection ----------------------------------------------------------

  void _beginReflection() {
    _phase = LoopPhase.reflection;
    notifyListeners();
  }

  /// Called by the UI once the reflection bridge has finished or been skipped.
  void reflectionDone() {
    if (_phase != LoopPhase.reflection) return;
    _beginRecoRound();
  }

  // ---- Reco round ----------------------------------------------------------

  void _beginRecoRound() {
    final reco = _reco ??= RecoController(
      profile: profile,
      engine: _recoEngine,
      context: _context,
      location: _location,
      store: store,
      liveService: liveService,
      weatherService: weatherService,
    );
    // Re-rank against the freshly sharpened profile (no-op on the first round,
    // where the constructor already ranked).
    reco.refresh();
    _roundReacted = 0;
    _phase = reco.current == null ? LoopPhase.exhausted : LoopPhase.recos;
    notifyListeners();
  }

  /// Intéressant — a revealed-preference reaction; feeds the profile, re-ranks,
  /// and continues the loop.
  void reactInteresting() => _react(interesting: true);

  /// Pas intéressant — a reaction; pushes the profile away, anti-repeats.
  void reactNotInteresting() => _react(interesting: false);

  void _react({required bool interesting}) {
    if (_phase != LoopPhase.recos) return;
    final reco = _reco;
    if (reco == null || reco.current == null) return;

    if (interesting) {
      reco.markInteresting();
    } else {
      reco.markNotInteresting();
    }
    _roundReacted++;

    if (reco.current == null) {
      _phase = LoopPhase.exhausted;
      notifyListeners();
      return;
    }

    // Round budget spent → sharpen with a new question batch (convergence),
    // unless we've hit the alternation cap or the engine is already confident.
    if (_roundReacted >= recosPerRound) {
      _round++;
      if (_round < maxRounds && !questionEngine.isDone(profile)) {
        _beginQuestionBatch();
        return;
      }
    }
    notifyListeners();
  }

  /// Planifier on the current recommendation: SELECTS it and ends the loop.
  /// Returns the selected recommendation (or null if there isn't one).
  Recommendation? select() {
    if (_phase != LoopPhase.recos) return null;
    final rec = _reco?.current;
    if (rec == null) return null;
    _phase = LoopPhase.selected;
    notifyListeners();
    return rec;
  }

  void _persistProfile() => store?.saveProfile(profile);

  @override
  void dispose() {
    _reco?.dispose();
    super.dispose();
  }
}
