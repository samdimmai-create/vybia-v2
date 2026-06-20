import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/geo/geo.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../guest/engine/loop_controller.dart';
import '../guest/model/dimension.dart';
import '../guest/model/life_context.dart';
import '../guest/model/question.dart';
import '../guest/screens/engine_loop_screen.dart';
import '../guest/screens/welcome_screen.dart';
import '../guest/state/guest_controller.dart';
import '../reco/engine/life_context_rules.dart';
import '../reco/engine/reco_context.dart';
import '../reco/model/activity.dart';
import '../reco/state/reco_controller.dart' show liveActivityCatalog;

/// Debug-only VISIBLE-IN-CHROME proof tour for Sprint S9.1
/// (`--dart-define=VYBIA_PROOF91=true`).
///
/// Drives the REAL adaptive engine — a real [LoopController] over the real
/// recommendation engine, real OSM-backed places and the same on-screen
/// [EngineLoopScreen] rendering — end to end, programmatically (no pointer), so
/// the founder can watch the loop in a normal Chrome window. It pauses on each
/// phase and prints `VYBIA_PROOF <name>` to the console; tool/cdp_capture.mjs
/// listens for those markers and grabs each frame via DevTools.
///
/// The whole point is to show the engine CHANGING across rounds: the same
/// driven loop produces reco round 1, then — after a sharpening question batch
/// and revealed-preference reactions — a re-ranked round 2 (a different pick).
/// The context-filter stop runs the real feasibility rules to show a
/// life-context dropping an activity.
class S91EngineProofTour extends StatefulWidget {
  const S91EngineProofTour({super.key});

  @override
  State<S91EngineProofTour> createState() => _S91EngineProofTourState();
}

enum _Stage { mood, engine, contextFilter }

class _S91EngineProofTourState extends State<S91EngineProofTour> {
  // Montréal centre — a fixed fix so distances ("à X km") render deterministically.
  static const double _lat = 45.5230;
  static const double _lng = -73.5810;

  // Hold each captured frame well past the capture client's settle window
  // (~1.5s) so the screenshot lands on a stable, decoded frame.
  static const Duration _holdDur = Duration(milliseconds: 3500);
  static const Duration _pumpDur = Duration(milliseconds: 160);

  _Stage _stage = _Stage.mood;
  LoopController? _loop;
  bool _started = false;

  // Recorded for the report: the round-1 vs round-2 leader (must differ).
  String reco1 = '?';
  String reco2 = '?';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
    }
  }

  @override
  void dispose() {
    _loop?.dispose();
    super.dispose();
  }

  void _mark(String name) => debugPrint('VYBIA_PROOF $name');
  Future<void> _hold() => Future<void>.delayed(_holdDur);
  Future<void> _pump() => Future<void>.delayed(_pumpDur);
  Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> _drive() async {
    // Capture the shared guest BEFORE any await (no BuildContext across gaps).
    final guest = GuestScope.of(context);
    try {
      // --- 1. Mood capture (the welcome step that seeds the engine) ----------
      await _wait(3000); // app + first image decode
      _mark('s9_mood');
      await _hold();

      // Hand the mood to a real loop. Sociable + lively priors.
      guest.profile.clear();
      guest.setMood(0.7, nudges: {
        Dimension.social: 0.85,
        Dimension.vibe: 0.7,
      });
      _loop = LoopController(
        profile: guest.profile,
        context: const RecoContext(
            hourOfDay: 21, month: 6, userLat: _lat, userLng: _lng),
        location: const GeoResult(_lat, _lng, GeoStatus.granted),
        // Tight 1-question ↔ 1-reco alternation so the proof shows a real second
        // batch: the adaptive engine's minAsked (3) guarantees it keeps probing
        // after the first question, and the single reaction between rounds is
        // enough to visibly re-rank round 2 (anti-repeat + sharpened profile).
        questionsPerBatch: 1,
        recosPerRound: 1,
      );
      setState(() => _stage = _Stage.engine);
      await _pump();

      // --- 2. First question batch ------------------------------------------
      _mark('s9_q1');
      await _hold();
      await _answerBatch();

      // --- 3. Reflection bridge ---------------------------------------------
      if (_loop!.phase == LoopPhase.reflection) {
        _mark('s9_reflect1');
        await _hold();
        _loop!.reflectionDone();
        await _pump();
      }

      // --- 4. Reco round 1 ---------------------------------------------------
      reco1 = _loop!.currentReco?.activity.titleFr ?? '?';
      _mark('s9_reco1');
      await _hold();
      await _reactRound(); // spends the round → triggers a sharpening batch

      // --- 5. Second (sharpening) question batch ----------------------------
      if (_loop!.phase == LoopPhase.questions) {
        _mark('s9_q2');
        await _hold();
        await _answerBatch();
      }
      if (_loop!.phase == LoopPhase.reflection) {
        _loop!.reflectionDone();
        await _pump();
      }

      // --- 6. Reco round 2 (re-ranked) --------------------------------------
      reco2 = _loop!.currentReco?.activity.titleFr ?? '?';
      _mark('s9_reco2');
      debugPrint('VYBIA_RERANK reco1="$reco1" reco2="$reco2"');
      await _hold();

      // --- 7. Life-context feasibility filter -------------------------------
      setState(() => _stage = _Stage.contextFilter);
      await _pump();
      _mark('s9_context_filter');
      await _hold();

      // --- 8. Planifier (the decisive moment that ends the loop → plan) -----
      setState(() => _stage = _Stage.engine);
      await _pump();
      _mark('s9_select');
      await _hold();

      _mark('DONE');
    } catch (e, st) {
      debugPrint('VYBIA_PROOF_ERROR $e\n$st');
    }
  }

  /// Answer the current batch until the loop leaves the questions phase. Picks
  /// the LEFT option each time for a deterministic, coherent sharpening.
  Future<void> _answerBatch() async {
    var guard = 0;
    while (_loop!.phase == LoopPhase.questions && guard++ < 8) {
      final q = _loop!.currentQuestion;
      if (q == null) break;
      final QOption opt = q.optionFor(OrbDirection.left) ?? q.options.first;
      _loop!.answer(opt);
      await _pump();
    }
  }

  /// React Intéressant through the current reco round until it hands back to a
  /// question batch (or exhausts) — the revealed-preference signal that re-ranks.
  Future<void> _reactRound() async {
    var guard = 0;
    while (_loop!.phase == LoopPhase.recos && guard++ < 6) {
      _loop!.reactInteresting();
      await _pump();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.mood:
        return const WelcomeScreen(proofFull: true);
      case _Stage.engine:
        final loop = _loop;
        if (loop == null) return const WelcomeScreen(proofFull: true);
        return EngineLoopScreen(controller: loop, proof: true);
      case _Stage.contextFilter:
        return const _ContextFilterProof();
    }
  }
}

/// A single, self-explanatory frame proving the life-context feasibility filter
/// (S9D) with the REAL [LifeContextRules]: with "Avec des enfants" active, the
/// engine drops the nightlife/bar option while the family-friendly picks stay.
class _ContextFilterProof extends StatelessWidget {
  const _ContextFilterProof();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const active = {LifeContext.avecEnfants};

    // One representative real activity per family, incl. a bar — the rule is run
    // for real, not narrated.
    final catalog = liveActivityCatalog();
    Activity? firstOf(ActivityCategory c) {
      for (final a in catalog) {
        if (a.category == c) return a;
      }
      return null;
    }

    final rows = <Activity>[
      for (final c in const [
        ActivityCategory.nightlife,
        ActivityCategory.cafe,
        ActivityCategory.nature,
        ActivityCategory.food,
        ActivityCategory.culture,
      ])
        if (firstOf(c) != null) firstOf(c)!,
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text('Contexte de vie',
                  style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.xs),
              // Active life-context pill.
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text('👶  Avec des enfants',
                    style: t.titleMedium?.copyWith(
                        color: AppColors.bg, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Vybia écarte ce qui ne colle pas — le reste tient.',
                style: t.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final a in rows) ...[
                _FeasRow(
                  activity: a,
                  feasible: LifeContextRules.feasible(active, a),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const Spacer(),
              Text(
                'Règle réelle (LifeContextRules) : « avec enfants » → pas de soirée, '
                'rien de strictement tardif.',
                style: t.labelSmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeasRow extends StatelessWidget {
  const _FeasRow({required this.activity, required this.feasible});

  final Activity activity;
  final bool feasible;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const dropped = Color(0xFFE08A7A);
    final color = feasible ? AppColors.surfaceRaised : AppColors.surface;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: (feasible ? AppColors.edgeDown : dropped)
              .withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          Icon(feasible ? Icons.check_circle : Icons.cancel,
              color: feasible ? AppColors.edgeDown : dropped, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.titleFr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(
                    color: feasible ? AppColors.pearl : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    decoration:
                        feasible ? null : TextDecoration.lineThrough,
                    decorationColor: dropped,
                  ),
                ),
                Text(activity.category.labelFr,
                    style: t.labelSmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            feasible ? 'gardé' : 'écarté',
            style: t.labelMedium?.copyWith(
              color: feasible ? AppColors.edgeDown : dropped,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
