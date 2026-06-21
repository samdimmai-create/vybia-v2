import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/edge_action.dart';
import '../guest/model/dimension.dart';
import '../guest/model/guest_profile.dart';
import '../guest/model/life_context.dart';
import '../guest/widgets/scene_scaffold.dart';
import '../reco/db/activity_repository.dart';
import '../reco/db/catalog_entry.dart';
import '../reco/db/enrichment_service.dart';
import '../reco/engine/reco_context.dart';
import '../reco/engine/recommendation_engine.dart';
import '../reco/model/activity.dart';
import '../reco/model/activity_kind.dart';
import '../reco/model/recommendation.dart';

/// Debug-only VISIBLE-IN-CHROME proof tour for Sprint S10
/// (`--dart-define=VYBIA_PROOF10=true`): OUR multi-source database, live.
///
/// Every frame is backed by the REAL [ActivityRepository] (loaded from
/// `assets/data/vybia_catalog.json` in `main`): three recommendations of
/// DIFFERENT KINDS produced by the real [RecommendationEngine] over the DB
/// (place / film / travel, each with real attributes + its own image + a
/// tailored "pourquoi"), a life-context filter driven by the DB's new flags,
/// and an entry AFTER stub enrichment persisted through the real write-back
/// path ([ActivityRepository.enrichWith] → `upsert` → store).
///
/// It pauses on each phase and prints `VYBIA_PROOF <name>`; tool/cdp_capture.mjs
/// listens for those markers and grabs each frame via DevTools.
class S10ProofTour extends StatefulWidget {
  const S10ProofTour({super.key});

  @override
  State<S10ProofTour> createState() => _S10ProofTourState();
}

enum _Phase { boot, placeReco, filmReco, travelReco, contextDb, enriched }

class _S10ProofTourState extends State<S10ProofTour> {
  // Montréal centre — a fixed fix so distances render deterministically.
  static const double _lat = 45.5230;
  static const double _lng = -73.5810;

  // Hold each captured frame well past the capture client's settle window so
  // the screenshot lands on a stable, decoded frame.
  static const Duration _holdDur = Duration(milliseconds: 3600);
  static const Duration _pumpDur = Duration(milliseconds: 200);

  _Phase _phase = _Phase.boot;
  bool _started = false;

  Recommendation? _place;
  Recommendation? _film;
  Recommendation? _travel;

  // Life-context proof (S10 DB flags).
  int _dbTotal = 0;
  int _dbFeasible = 0;
  List<CatalogEntry> _ctxRows = const [];

  // Enrichment proof.
  CatalogEntry? _before;
  CatalogEntry? _after;

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

  static const RecoContext _ctx =
      RecoContext(hourOfDay: 20, month: 6, userLat: _lat, userLng: _lng);

  /// Top recommendation of [kind] from OUR database, via the real engine.
  Recommendation? _recOf(ActivityKind kind) {
    final acts =
        ActivityRepository.activities.where((a) => a.kind == kind).toList();
    if (acts.isEmpty) return null;
    final recs = RecommendationEngine(catalog: acts)
        .recommend(GuestProfile(), context: _ctx, max: 6);
    return recs.isEmpty ? null : recs.first;
  }

  Future<void> _drive() async {
    try {
      await _wait(2800); // app + asset load + first decode

      // ---- Build the three different-kind recommendations from the DB. ------
      _place = _recOf(ActivityKind.place);
      _film = _recOf(ActivityKind.film);
      _travel = _recOf(ActivityKind.travel);

      // ---- Life-context filter using the DB's explicit flags (S10). ---------
      // "Avec des enfants" + "Sans alcool": feasibleFor runs the real DB-flag
      // rules over every kind. Show the counts + a few kept/dropped rows.
      _dbTotal = ActivityRepository.entries.length;
      final feasible = ActivityRepository.feasibleFor(
        {LifeContext.avecEnfants, LifeContext.sansAlcool},
        userLat: _lat,
        userLng: _lng,
      );
      _dbFeasible = feasible.length;
      _ctxRows = _pickCtxRows();

      // ---- Enrichment write-back (stub provider) ----------------------------
      // A freshly-ingested record with a gap (no French description) — exactly
      // what a future Claude call fills. Upsert it, then run the deterministic
      // stub through the REAL write-back path (upsert → persist), and show the
      // before/after. Swapping the stub for a Claude provider changes nothing.
      final seed = _gapSeed();
      _before = seed;
      await ActivityRepository.upsert(seed);
      _after = await ActivityRepository.enrichWith(
        const LocalRuleEnrichmentProvider(),
        seed.id,
      );

      // ---- Walk the phases, marking each for the capture client. ------------
      await _show(_Phase.placeReco, 's10_reco_place');
      await _show(_Phase.filmReco, 's10_reco_film');
      await _show(_Phase.travelReco, 's10_reco_travel');
      await _show(_Phase.contextDb, 's10_context_db');
      await _show(_Phase.enriched, 's10_enriched');

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

  /// A representative row per kind for the context proof — so a screenshot shows
  /// the filter keeping the family-friendly options and dropping the bar/alcohol
  /// ones, across more than one kind.
  List<CatalogEntry> _pickCtxRows() {
    final rows = <CatalogEntry>[];
    void add(bool Function(CatalogEntry) test) {
      final hit = ActivityRepository.entries.where(test);
      if (hit.isNotEmpty) rows.add(hit.first);
    }

    // A bar that serves alcohol → dropped.
    add((e) => e.servesAlcohol == true);
    // A café / family place → kept.
    add((e) => e.category == ActivityCategory.cafe && e.servesAlcohol != true);
    // A nature spot → kept.
    add((e) => e.category == ActivityCategory.nature);
    // A film (no alcohol, kid-friendly) → kept, proves the filter spans kinds.
    add((e) => e.kind == ActivityKind.film);
    // A culture pick → kept.
    add((e) => e.category == ActivityCategory.culture);
    return rows;
  }

  /// A genuine "just ingested, awaiting enrichment" record: real shape, real
  /// kind, but with the description gap a curation pass fills.
  CatalogEntry _gapSeed() {
    return CatalogEntry(
      id: 's10_demo_gap',
      name: 'Atelier céramique du Mile End',
      kind: ActivityKind.place,
      category: ActivityCategory.creative,
      descFr: '', // the gap the enrichment fills
      imageRef: 'assets/images/reco/creative_studio.webp',
      tags: const {Dimension.energy: 0.4, Dimension.vibe: 0.45},
      motives: const (hedonic: 0.5, relaxation: 0.5, eudaimonic: 0.6),
      tagList: const ['atelier', 'créatif'],
      kidFriendly: true,
      servesAlcohol: false,
      priceTier: 1,
      effortLevel: 0.3,
      indoor: true,
      timeOfDay: const ['apresMidi', 'soir'],
      seasons: const [],
      source: 'osm',
      sourceId: 'demo/0',
      confidence: 0.5,
      lat: 45.5230,
      lng: -73.5980,
      neighbourhood: 'Mile End',
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.boot:
        return const _Boot();
      case _Phase.placeReco:
        return _RecoProofScene(rec: _place);
      case _Phase.filmReco:
        return _RecoProofScene(rec: _film);
      case _Phase.travelReco:
        return _RecoProofScene(rec: _travel);
      case _Phase.contextDb:
        return _ContextDbProof(
          total: _dbTotal,
          feasible: _dbFeasible,
          rows: _ctxRows,
        );
      case _Phase.enriched:
        return _EnrichedProof(before: _before, after: _after);
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

/// A recommendation backed by OUR DB, rendered through the universal scene/
/// bubble exactly as the live reco loop does (orb pinned at centre, edges +
/// bottom bubble both shown via [SceneScaffold.debugProofFull]).
class _RecoProofScene extends StatelessWidget {
  const _RecoProofScene({required this.rec});

  final Recommendation? rec;

  @override
  Widget build(BuildContext context) {
    final r = rec;
    if (r == null) {
      return const ColoredBox(
        color: AppColors.bg,
        child: Center(
          child: Text('aucune entrée pour ce type',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    final entry = ActivityRepository.entryById(r.activity.id);
    return SceneScaffold(
      key: ValueKey('s10_${r.activity.id}'),
      image: r.image,
      badge: '${r.activity.kind.labelFr} · notre base',
      headline: r.activity.titleFr,
      prompt: r.why,
      bottomBubble: true,
      infoLine: _infoLine(r, entry),
      tags: _vibeTags(r.activity),
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

  /// A kind-specific one-line context from the DB record itself.
  String _infoLine(Recommendation r, CatalogEntry? e) {
    final a = r.activity;
    switch (a.kind) {
      case ActivityKind.film:
        return [
          a.category.labelFr,
          if (e?.year != null) '${e!.year}',
          if (e?.genre != null) e!.genre!,
          if (e?.whereToWatch != null) e!.whereToWatch!,
        ].join(' · ');
      case ActivityKind.travel:
        return [
          'Escapade',
          if (e?.destination != null) e!.destination!,
          if (e?.duration != null) e!.duration!,
        ].join(' · ');
      case ActivityKind.event:
        return [a.category.labelFr, if (e?.startsAt != null) 'daté'].join(' · ');
      case ActivityKind.online:
        return [
          'À la maison',
          if (e?.provider != null) e!.provider!,
        ].join(' · ');
      case ActivityKind.place:
        return [
          a.category.labelFr,
          if (e?.neighbourhood != null && e!.neighbourhood!.isNotEmpty)
            e.neighbourhood!,
        ].join(' · ');
    }
  }

  List<String> _vibeTags(Activity a) {
    final tags = <String>[];
    final vibe = a.tag(Dimension.vibe);
    tags.add(vibe <= 0.4 ? 'intime' : (vibe >= 0.65 ? 'animé' : 'posé'));
    final energy = a.tag(Dimension.energy);
    if (energy <= 0.35) tags.add('calme');
    if (energy >= 0.7) tags.add('énergique');
    return tags;
  }
}

/// One frame proving the life-context filter driven by the DB's NEW explicit
/// flags (kidFriendly / servesAlcohol …) via [ActivityRepository.feasibleFor].
class _ContextDbProof extends StatelessWidget {
  const _ContextDbProof({
    required this.total,
    required this.feasible,
    required this.rows,
  });

  final int total;
  final int feasible;
  final List<CatalogEntry> rows;

  bool _ok(CatalogEntry e) =>
      e.kidFriendly != false && e.servesAlcohol != true;

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
              Text('Notre base · contexte de vie',
                  style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                children: const [
                  _Pill('👶  Avec des enfants'),
                  _Pill('🚫  Sans alcool'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '$feasible entrées compatibles sur $total — '
                'le filtre s’appuie sur les indicateurs de la base '
                '(kidFriendly, servesAlcohol…), tous types confondus.',
                style: t.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final e in rows) ...[
                _CtxRow(entry: e, feasible: _ok(e)),
                const SizedBox(height: AppSpacing.sm),
              ],
              const Spacer(),
              Text(
                'ActivityRepository.feasibleFor({avecEnfants, sansAlcool}) — '
                'requête sur notre base multi-sources.',
                style: t.labelSmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label,
          style: t.titleSmall
              ?.copyWith(color: AppColors.bg, fontWeight: FontWeight.w700)),
    );
  }
}

class _CtxRow extends StatelessWidget {
  const _CtxRow({required this.entry, required this.feasible});

  final CatalogEntry entry;
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
          color:
              (feasible ? AppColors.edgeDown : dropped).withValues(alpha: 0.55),
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
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(
                    color: feasible ? AppColors.pearl : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    decoration: feasible ? null : TextDecoration.lineThrough,
                    decorationColor: dropped,
                  ),
                ),
                Text('${entry.kind.labelFr} · ${entry.category.labelFr}',
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

/// One frame proving the writable / enrichable seam: a record BEFORE (a gap) and
/// AFTER the stub enrichment was persisted through the real write-back path.
class _EnrichedProof extends StatelessWidget {
  const _EnrichedProof({required this.before, required this.after});

  final CatalogEntry? before;
  final CatalogEntry? after;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = after;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text('Notre base · enrichissement',
                  style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.xs),
              Text(a?.name ?? '—',
                  style: t.headlineSmall
                      ?.copyWith(color: AppColors.pearl, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.lg),
              _StateCard(
                label: 'AVANT — fraîchement ingéré',
                bodyLabel: 'description',
                body: (before?.descFr.trim().isEmpty ?? true)
                    ? '(vide — à compléter)'
                    : before!.descFr,
                meta: 'source : ${before?.source ?? '—'} · '
                    'enrichi : —',
                muted: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Icon(Icons.arrow_downward,
                  color: AppColors.primary.withValues(alpha: 0.9)),
              const SizedBox(height: AppSpacing.md),
              _StateCard(
                label: 'APRÈS — enrichi + sauvegardé',
                bodyLabel: 'description',
                body: a?.descFr ?? '—',
                meta: 'source : ${a?.source ?? '—'} · '
                    'enrichi : ${_short(a?.enrichedAt)}',
                muted: false,
              ),
              const Spacer(),
              Text(
                'enrichWith(LocalRuleEnrichmentProvider) → upsert → store. '
                'La même boucle marche avec un fournisseur Claude.',
                style: t.labelSmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _short(String? iso) {
    if (iso == null) return '—';
    final i = iso.indexOf('T');
    return i > 0 ? iso.substring(0, i) : iso;
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.label,
    required this.bodyLabel,
    required this.body,
    required this.meta,
    required this.muted,
  });

  final String label;
  final String bodyLabel;
  final String body;
  final String meta;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = muted ? AppColors.textMuted : AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: muted ? 0.4 : 0.8),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: t.labelMedium
                  ?.copyWith(color: accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text(body,
              style: t.bodyLarge?.copyWith(
                  color: muted ? AppColors.textMuted : AppColors.pearl)),
          const SizedBox(height: AppSpacing.xs),
          Text(meta,
              style: t.labelSmall?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
