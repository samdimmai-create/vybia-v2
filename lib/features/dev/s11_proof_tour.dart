import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/edge_action.dart';
import '../guest/model/dimension.dart';
import '../guest/model/guest_profile.dart';
import '../guest/model/life_context.dart';
import '../guest/widgets/scene_scaffold.dart';
import '../reco/data/activity_catalog.dart';
import '../reco/db/activity_repository.dart';
import '../reco/engine/recommendation_engine.dart';
import '../reco/engine/reco_context.dart';
import '../reco/engine/wellbeing_tagger.dart';
import '../reco/model/activity.dart';
import '../reco/model/recommendation.dart';

/// Debug-only VISIBLE-IN-CHROME proof tour for Sprint S11
/// (`--dart-define=VYBIA_PROOF11=true`): the research-grounded deterministic
/// scorer making genuinely different, explainable choices on its own.
///
/// Four frames over the SAME catalog:
///   * `s11_tired_escape`   — a tired/escape mood → a hedonic, low-effort, near
///     pick (the affect + happiness terms steer it).
///   * `s11_curious_growth` — a curious/growth mood → a eudaimonic / novel /
///     cultural pick. Same catalog, DIFFERENT top pick, driven by mood/motive.
///   * `s11_context_filter` — a context hard-filter in action (rain + avec des
///     enfants drops the open-air / late venues).
///   * `s11_explain`        — the per-term factor breakdown behind a "pourquoi".
///
/// Each phase prints `VYBIA_PROOF <name>`; tool/cdp_capture.mjs grabs each frame.
class S11ProofTour extends StatefulWidget {
  const S11ProofTour({super.key});

  @override
  State<S11ProofTour> createState() => _S11ProofTourState();
}

enum _Phase { boot, tired, curious, contextFilter, explain }

class _S11ProofTourState extends State<S11ProofTour> {
  // Montréal centre — a fixed fix so distances/proximity render deterministically.
  static const double _lat = 45.5019;
  static const double _lng = -73.5674;

  static const Duration _holdDur = Duration(milliseconds: 3600);
  static const Duration _pumpDur = Duration(milliseconds: 200);

  static const RecoContext _ctx =
      RecoContext(hourOfDay: 20, month: 6, userLat: _lat, userLng: _lng);
  // The context-filter frame adds a wet-weather signal + life-context.
  static const RecoContext _wetCtx = RecoContext(
      hourOfDay: 20,
      month: 6,
      userLat: _lat,
      userLng: _lng,
      weather: WeatherSignal.rain);

  _Phase _phase = _Phase.boot;
  bool _started = false;

  Recommendation? _tired;
  Recommendation? _curious;

  // Context-filter proof.
  int _ctxBefore = 0;
  int _ctxAfter = 0;
  List<Recommendation> _ctxKept = const [];

  List<Activity> get _catalog =>
      ActivityRepository.isLoaded ? ActivityRepository.activities : kActivityCatalog;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
    }
  }

  void _mark(String name) => debugPrint('VYBIA_PROOF $name');
  Future<void> _hold() => Future<void>.delayed(_holdDur);
  Future<void> _pump() => Future<void>.delayed(_pumpDur);
  Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  GuestProfile _tiredEscape() {
    final p = GuestProfile();
    p.answer(Dimension.mood, 0.1); // drained / calm
    p.answer(Dimension.energy, 0.12);
    p.answer(Dimension.social, 0.25);
    p.answer(Dimension.novelty, 0.18);
    return p;
  }

  GuestProfile _curiousGrowth() {
    final p = GuestProfile();
    p.answer(Dimension.mood, 0.5); // mid = exploratory
    p.answer(Dimension.novelty, 0.95);
    p.answer(Dimension.energy, 0.5);
    p.answer(Dimension.social, 0.45);
    return p;
  }

  Future<void> _drive() async {
    try {
      await _wait(2800); // app + asset load + first decode
      final engine = RecommendationEngine(catalog: _catalog);

      _tired = engine.recommend(_tiredEscape(), context: _ctx).first;
      _curious = engine.recommend(_curiousGrowth(), context: _ctx).first;

      // Context hard-filter: rain + avec des enfants over the same catalog.
      final unfiltered = engine.recommend(_curiousGrowth(), context: _ctx);
      final filtered = engine.recommend(
        _curiousGrowth()..setContext(LifeContext.avecEnfants, true),
        context: _wetCtx,
      );
      _ctxBefore = unfiltered.length;
      _ctxAfter = filtered.length;
      _ctxKept = filtered;

      await _show(_Phase.tired, 's11_tired_escape');
      await _show(_Phase.curious, 's11_curious_growth');
      await _show(_Phase.contextFilter, 's11_context_filter');
      await _show(_Phase.explain, 's11_explain');
      _mark('DONE');
    } catch (e, st) {
      debugPrint('VYBIA_PROOF_ERROR $e\n$st');
    }
  }

  Future<void> _show(_Phase phase, String marker) async {
    if (!mounted) return;
    setState(() => _phase = phase);
    await _pump();
    _mark(marker);
    await _hold();
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.boot:
        return const _Boot();
      case _Phase.tired:
        return _MoodReco(
          rec: _tired,
          moodBadge: 'Humeur : fatigué·e → évasion',
        );
      case _Phase.curious:
        return _MoodReco(
          rec: _curious,
          moodBadge: 'Humeur : curieux·se → découverte',
        );
      case _Phase.contextFilter:
        return _ContextFilterProof(
          before: _ctxBefore,
          after: _ctxAfter,
          kept: _ctxKept,
        );
      case _Phase.explain:
        return _ExplainProof(rec: _curious);
    }
  }
}

class _Boot extends StatelessWidget {
  const _Boot();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: AppColors.bg,
        child: Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}

/// A live-looking reco scene, captioned with the MOOD that produced it, so the
/// tired vs curious frames read as the same catalog answering two people.
class _MoodReco extends StatelessWidget {
  const _MoodReco({required this.rec, required this.moodBadge});

  final Recommendation? rec;
  final String moodBadge;

  @override
  Widget build(BuildContext context) {
    final r = rec;
    if (r == null) {
      return const ColoredBox(
        color: AppColors.bg,
        child: Center(
            child: Text('aucune recommandation',
                style: TextStyle(color: AppColors.textMuted))),
      );
    }
    final wb = WellbeingTagger.of(r.activity);
    final axis = wb.hedoniaEudaimonia < 0.45
        ? 'hédonique'
        : (wb.hedoniaEudaimonia > 0.55 ? 'eudémonique' : 'équilibré');
    return SceneScaffold(
      key: ValueKey('s11_${r.activity.id}'),
      image: r.image,
      badge: moodBadge,
      headline: r.activity.titleFr,
      prompt: r.why,
      bottomBubble: true,
      infoLine: 'Axe bien-être : $axis · ${r.factors.join(' · ')}',
      tags: r.factors,
      left: 'Intéressant',
      right: 'Pas intéressant',
      up: 'Plus d’infos',
      down: 'Planifier',
      leftAction: EdgeAction.joy,
      rightAction: EdgeAction.reject,
      upAction: EdgeAction.curious,
      downAction: EdgeAction.go,
      debugProofFull: true,
      enableHoldHome: false,
      onDirection: (_) {},
    );
  }
}

/// One frame proving a context hard-filter (rain + avec des enfants) reshaping
/// the same catalog's answer.
class _ContextFilterProof extends StatelessWidget {
  const _ContextFilterProof({
    required this.before,
    required this.after,
    required this.kept,
  });

  final int before;
  final int after;
  final List<Recommendation> kept;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text('Filtre de faisabilité contextuel',
                  style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: const [
                  _Pill('🌧  Pluie'),
                  _Pill('👶  Avec des enfants'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'La météo et le contexte de vie retirent en dur le plein air et '
                'les sorties tardives — il reste les options vraiment faisables.',
                style: t.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final r in kept.take(4)) ...[
                _KeptRow(rec: r),
                const SizedBox(height: AppSpacing.sm),
              ],
              const Spacer(),
              Text(
                'Hard-filter météo (S11C) + contextes de vie (S9D), '
                'avec garde anti-pénurie pour ne jamais vider la scène.',
                style: t.labelSmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeptRow extends StatelessWidget {
  const _KeptRow({required this.rec});
  final Recommendation rec;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.edgeDown.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 18, color: AppColors.edgeDown),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec.activity.titleFr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(color: AppColors.pearl)),
                Text(
                    '${rec.activity.category.labelFr} · '
                    '${rec.activity.indoor ? 'intérieur' : 'plein air'}',
                    style: t.labelSmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One frame exposing the per-term factor breakdown behind a "pourquoi".
class _ExplainProof extends StatelessWidget {
  const _ExplainProof({required this.rec});
  final Recommendation? rec;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = rec;
    if (r == null || r.breakdown == null) {
      return const ColoredBox(color: AppColors.bg);
    }
    final b = r.breakdown!;
    final terms = <({String label, double value})>[
      (label: 'Goûts (révélés)', value: b.pref),
      (label: 'Motif (LMS)', value: b.motive),
      (label: 'Hédonique↔eudémonique', value: b.affect),
      (label: 'Contexte', value: b.context),
      (label: 'Social', value: b.social),
      (label: 'Nouveauté', value: b.novelty),
      (label: 'Bien-être', value: b.happiness),
      (label: 'Proximité', value: b.proximity),
    ]..sort((x, y) => y.value.compareTo(x.value));
    final maxV =
        terms.map((e) => e.value).fold<double>(0.001, (a, c) => c > a ? c : a);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text('Pourquoi — le détail honnête',
                  style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.xs),
              Text(r.activity.titleFr,
                  style: t.displaySmall?.copyWith(color: AppColors.pearl)),
              const SizedBox(height: AppSpacing.sm),
              Text(r.why,
                  style: t.titleMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final f in r.factors) _Pill(f),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final term in terms) ...[
                _TermBar(label: term.label, value: term.value, maxV: maxV),
                const SizedBox(height: AppSpacing.sm),
              ],
              const Spacer(),
              Text(
                'Chaque barre = la contribution pondérée réelle d’un terme du '
                'score. Les chips reprennent les termes dominants — rien d’inventé.',
                style: t.labelSmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermBar extends StatelessWidget {
  const _TermBar(
      {required this.label, required this.value, required this.maxV});
  final String label;
  final double value;
  final double maxV;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final frac = (value / maxV).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.labelMedium?.copyWith(color: AppColors.textSecondary)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 10,
              backgroundColor: AppColors.surface,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 44,
          child: Text(value.toStringAsFixed(3),
              textAlign: TextAlign.right,
              style: t.labelSmall?.copyWith(color: AppColors.textMuted)),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Text(label,
          style: t.labelMedium?.copyWith(color: AppColors.pearl)),
    );
  }
}
