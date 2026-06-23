import 'package:flutter/foundation.dart';

import '../../../core/geo/geo.dart';
import '../../../core/persistence/app_store.dart';
import '../../reco/content/llm_client.dart';
import '../../reco/content/llm_content_provider.dart';
import '../../reco/engine/recommendation_engine.dart';
import '../../reco/engine/reco_context.dart';
import '../../reco/live/live_availability_service.dart';
import '../../reco/live/weather_service.dart';
import '../../reco/memory/preference_memory.dart';
import '../../reco/model/recommendation.dart';
import '../../reco/state/reco_controller.dart';
import '../data/question_bank.dart';
import '../model/guest_profile.dart';
import '../model/moment.dart';
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
    PreferenceMemory? memory,
    MomentContext? moment,
    this.questionsPerBatch = 3,
    this.firstBatchSize = 2,
    this.recosPerRound = 4,
    this.maxRounds = 4,
  }) : questionEngine = questionEngine ?? AdaptiveEngine(bank: kQuestionBank) {
    _recoEngine = recoEngine;
    _context = context;
    _location = location;
    _moment = moment ?? MomentContext.now();
    // S19B: use the injected memory, else load it from the store, so the loop
    // remembers reactions/answers across sessions. Null only in pure-offline
    // tests that pass neither.
    _memory = memory ?? store?.readMemory();
    // S19B/C: don't re-ask questions already firmly answered FOR THIS MOMENT —
    // Vybia should feel like it remembers you. Seed those ids as already-asked.
    final mem = _memory;
    if (mem != null) {
      this.questionEngine.seedAnswered(mem.answeredQuestionIdsFor(
        slot: _moment.slot,
        mood: MoodBucket.of(profile),
      ));
    }
    _beginQuestionBatch(first: true);
  }

  final GuestProfile profile;
  final AdaptiveEngine questionEngine;
  RecommendationEngine? _recoEngine;
  RecoContext? _context;
  GeoResult? _location;
  final AppStore? store;

  /// S19A: the moment (day-of-week + hour) this whole loop session belongs to —
  /// every answer and reaction is stamped with it for the temporal memory.
  late final MomentContext _moment;

  /// S19B: the cross-session preference memory (loaded from the store unless
  /// injected). Null only in pure-offline tests.
  PreferenceMemory? _memory;

  /// The moment this loop is running in (exposed for the UI / proof).
  MomentContext get moment => _moment;

  /// The LIVE availability layer (S10.1B), threaded into the [RecoController] so
  /// the reco round blends fresh events/films with the static pool. Null in
  /// tests → fully offline.
  final LiveAvailabilityService? liveService;

  /// The keyless live weather source (S12B), threaded into the [RecoController]
  /// so reco rounds reflect the real sky. Null in tests → no weather signal.
  final WeatherService? weatherService;

  /// How many questions a single batch may ask before yielding to a reco round.
  final int questionsPerBatch;

  /// S16B: how many questions the FIRST batch asks before the first reco round.
  /// Kept smaller than [questionsPerBatch] so a brand-new guest reaches a real
  /// recommendation in the fewest steps (fast-to-value); later batches use the
  /// full [questionsPerBatch] to keep sharpening once value is on screen.
  final int firstBatchSize;

  /// The question cap for the batch currently in flight (the first batch uses
  /// [firstBatchSize], every later batch uses [questionsPerBatch]).
  int _batchLimit = 0;

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

  // S18D (founder fix — "double-tap au 2e question saute à la page de l'activité
  // au lieu de la question précédente"): a real step-back stack. Each answered
  // question pushes the question shown PLUS a snapshot of the profile taken right
  // BEFORE its answer was applied, so [stepBack] can re-show that question and
  // revert exactly the learning that one answer added — back = one step, not a
  // route pop out of the whole loop.
  final List<({Question question, Map<String, dynamic> snapshot})> _qHistory = [];

  // S15C: the LLM content layer for fresh question wording (the reco phase gets
  // its variety through the [RecoController] it already owns). Null / inactive →
  // the deterministic question prompt shows with zero latency.
  final LlmContentProvider? _content =
      isLlmConfigured ? LlmContentProvider() : null;
  String? _generatedQ;
  String? _qForId;

  /// The current question, or null when not in the [LoopPhase.questions] phase.
  Question? get currentQuestion =>
      _phase == LoopPhase.questions ? _question : null;

  /// The wording to display for the current question: the fresh Claude phrasing
  /// once it has arrived for this question, else the deterministic prompt.
  String? get currentQuestionPrompt {
    final q = currentQuestion;
    if (q == null) return null;
    if (_qForId == q.id && _generatedQ != null) return _generatedQ;
    return q.prompt;
  }

  /// The current recommendation, or null when not in [LoopPhase.recos].
  Recommendation? get currentReco =>
      _phase == LoopPhase.recos ? _reco?.current : null;

  /// The "pourquoi" to display for the current reco — the Claude-voiced line via
  /// the owned [RecoController] once it arrives, else the deterministic one.
  String? get currentRecoWhy =>
      _phase == LoopPhase.recos ? _reco?.currentWhy : null;

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
    _batchLimit = first ? firstBatchSize : questionsPerBatch;
    final q = _pickQuestion(first: first);
    if (q == null) {
      // Nothing informative left to ask — go straight to recommendations.
      _beginReflection();
      return;
    }
    _question = q;
    _phase = LoopPhase.questions;
    _maybeGenerateQuestion();
    notifyListeners();
  }

  /// Kick off fresh Claude wording for the current question in the background
  /// (only when configured and not already fetching for this question). Never
  /// blocks; on arrival it swaps the phrasing in. Same sense, new words.
  void _maybeGenerateQuestion() {
    final q = currentQuestion;
    final c = _content;
    if (q == null || c == null || !c.active) return;
    if (_qForId == q.id) return;
    _qForId = q.id;
    _generatedQ = null;
    final id = q.id;
    c
        .generateQuestionPrompt(q.prompt, dimensionLabel: q.target.name)
        .then((text) {
      if (_disposed) return;
      if (_qForId == id) {
        _generatedQ = text;
        notifyListeners();
      }
    });
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
    // S18D: snapshot BEFORE applying so a step-back can revert exactly this answer.
    _qHistory.add((question: q, snapshot: profile.toJson()));
    questionEngine.apply(profile, q, option);
    _persistProfile();
    _rememberAnswer(q);
    _batchAsked++;

    final next = questionEngine.next(profile);
    final batchFull = _batchAsked >= _batchLimit;
    final converged = questionEngine.isDone(profile);
    if (next == null || batchFull || converged) {
      _beginReflection();
    } else {
      _question = next;
      notifyListeners();
    }
  }

  /// S18D: is there a previous question to step back to right now?
  bool get canStepBack => _phase == LoopPhase.questions && _qHistory.isNotEmpty;

  /// S18D: go back EXACTLY one step in the question chain — restore the profile to
  /// the state before the last answer and re-show that question. Returns false
  /// when there is nothing to step back to, so the caller can fall back to a
  /// normal route-back. This is the "double-tap = previous question" contract.
  bool stepBack() {
    if (!canStepBack) return false;
    final prev = _qHistory.removeLast();
    profile.restore(prev.snapshot);
    _persistProfile();
    _question = prev.question;
    _phase = LoopPhase.questions;
    if (_batchAsked > 0) _batchAsked--;
    _generatedQ = null;
    _qForId = null;
    _maybeGenerateQuestion();
    notifyListeners();
    return true;
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
      memory: _memory,
      moment: _moment,
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
    // S19D: the guest is planning this pick → mark it lived in the memory so it
    // stops resurfacing as "a preference you haven't lived yet".
    _reco?.markPlanned(rec.activity.id);
    _phase = LoopPhase.selected;
    notifyListeners();
    return rec;
  }

  void _persistProfile() => store?.saveProfile(profile);

  /// S19A/B: stamp the just-answered question into the temporal memory with this
  /// moment, and persist it — so Vybia won't re-ask it in the same context next
  /// session. No-op when the memory isn't wired (offline tests).
  void _rememberAnswer(Question q) {
    final mem = _memory;
    if (mem == null) return;
    mem.recordAnswer(
      questionId: q.id,
      moment: _moment,
      mood: MoodBucket.of(profile),
    );
    store?.saveMemory(mem);
  }

  /// S15C: a short, Claude-voiced acknowledgement line for a just-made reaction
  /// (Intéressant / Pas intéressant). Falls back to a deterministic line when the
  /// proxy is absent or down — so the surface reads templated, never broken.
  Future<String> reactionLine({
    required bool liked,
    required String activityTitle,
  }) {
    final c = _content;
    if (c == null) {
      return Future.value(liked ? 'Noté — on creuse ça.' : 'Compris, on passe.');
    }
    return c.generateReaction(liked: liked, activityTitle: activityTitle);
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _reco?.dispose();
    _content?.dispose();
    super.dispose();
  }
}
