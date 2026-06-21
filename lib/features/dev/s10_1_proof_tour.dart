import 'dart:async';

import 'package:flutter/material.dart';

import '../../components/bubble/bubble_image.dart';
import '../../core/media/image_ref.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../reco/db/activity_repository.dart';
import '../reco/db/catalog_entry.dart';
import '../reco/live/live_availability_service.dart';
import '../reco/live/live_source.dart';
import '../reco/model/activity_kind.dart';

/// Debug-only VISIBLE-IN-CHROME proof tour for Sprint S10.1
/// (`--dart-define=VYBIA_PROOF101=true`): the STATIC/LIVE split + real images.
///
/// Four captured frames, all backed by real data:
///   * `s10_1_images_gallery` — several STATIC catalog entries, each with its
///     own real open-licensed photo (Commons), not the generic category image.
///   * `s10_1_live_event` — events fetched LIVE from the City of Montréal open-
///     data calendar, each with a REAL date (kind=event, availability=live).
///   * `s10_1_streaming_seam` — the per-provider status: events OK, TMDB
///     streaming "needs key", cinema showtimes "needs key" — all keyless-safe.
///   * `s10_1_live_fallback` — the SAME layer with the network unreachable:
///     every source fails gracefully and the loop degrades to static suggestions.
///
/// It prints `VYBIA_PROOF <name>` on each phase; tool/cdp_capture.mjs grabs the
/// frame. The live fetch runs over the browser (CORS-enabled source); if it is
/// unreachable the live phase simply shows what the offline phase proves.
class S101ProofTour extends StatefulWidget {
  const S101ProofTour({super.key});

  @override
  State<S101ProofTour> createState() => _S101ProofTourState();
}

enum _Phase { boot, gallery, liveEvent, seam, fallback }

class _S101ProofTourState extends State<S101ProofTour> {
  static const double _lat = 45.5230;
  static const double _lng = -73.5810;
  static const Duration _holdDur = Duration(milliseconds: 3600);
  static const Duration _pumpDur = Duration(milliseconds: 200);

  _Phase _phase = _Phase.boot;
  bool _started = false;

  List<CatalogEntry> _gallery = const [];
  List<CatalogEntry> _liveEvents = const [];
  List<LiveProviderStatus> _liveStatuses = const [];
  List<LiveProviderStatus> _offlineStatuses = const [];
  List<CatalogEntry> _fallbackRows = const [];

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

  Future<void> _drive() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 2600));

      // ---- Gallery: static entries that now carry a real per-activity photo. -
      _gallery = ActivityRepository.entries
          .where((e) =>
              e.isStatic &&
              e.imageRef.startsWith('assets/images/catalog/'))
          .take(6)
          .toList();

      // ---- Live: the REAL availability layer over the open-data calendar. ----
      final live = LiveAvailabilityService.standard();
      final fetched = await live.fetchAvailableNow(LiveQuery(
        lat: _lat,
        lng: _lng,
        when: DateTime.now(),
        limit: 6,
      ));
      _liveEvents =
          fetched.where((e) => e.kind == ActivityKind.event).take(5).toList();
      _liveStatuses = live.statuses.values.toList();

      // ---- Fallback: the same layer with the network unreachable. ------------
      final offline = LiveAvailabilityService.standard(
        httpGet: (Uri _, {Duration timeout = Duration.zero}) async =>
            throw Exception('offline'),
      );
      await offline.fetchAvailableNow(LiveQuery(when: DateTime.now()));
      _offlineStatuses = offline.statuses.values.toList();
      _fallbackRows = ActivityRepository.liveEntries.take(4).toList();

      await _show(_Phase.gallery, 's10_1_images_gallery');
      await _show(_Phase.liveEvent, 's10_1_live_event');
      await _show(_Phase.seam, 's10_1_streaming_seam');
      await _show(_Phase.fallback, 's10_1_live_fallback');
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
      case _Phase.gallery:
        return _GalleryProof(rows: _gallery);
      case _Phase.liveEvent:
        return _LiveEventProof(events: _liveEvents);
      case _Phase.seam:
        return _SeamProof(statuses: _liveStatuses);
      case _Phase.fallback:
        return _FallbackProof(
          statuses: _offlineStatuses,
          fallbackRows: _fallbackRows,
        );
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

/// Several static recos, each with its OWN real open-licensed photo.
class _GalleryProof extends StatelessWidget {
  const _GalleryProof({required this.rows});
  final List<CatalogEntry> rows;

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
              const SizedBox(height: AppSpacing.sm),
              Text('Catalogue statique · vraies images',
                  style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.xs),
              Text('Chaque lieu a sa propre photo libre — fini le rendu générique.',
                  style:
                      t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: rows.isEmpty
                    ? const Center(
                        child: Text('aucune image per-activité',
                            style: TextStyle(color: AppColors.textMuted)))
                    : GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 0.74,
                        children: [
                          for (final e in rows)
                            BubbleImage(
                              image: imageProviderFor(e.imageRef),
                              label: e.name,
                              subtitle: e.category.labelFr,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Events fetched live from the open-data calendar, each with a real date.
class _LiveEventProof extends StatelessWidget {
  const _LiveEventProof({required this.events});
  final List<CatalogEntry> events;

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
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                const Icon(Icons.bolt, color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Text('EN DIRECT · Ville de Montréal (données ouvertes)',
                    style:
                        t.labelMedium?.copyWith(color: AppColors.textMuted)),
              ]),
              const SizedBox(height: AppSpacing.xs),
              Text('Disponible en ce moment — date réelle, pas un instantané figé.',
                  style:
                      t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: events.isEmpty
                    ? const Center(
                        child: Text('aucun événement renvoyé (réseau ?)',
                            style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: events.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) => _EventCard(e: events[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.e});
  final CatalogEntry e;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(e.startsAt ?? '—',
                style: t.labelMedium?.copyWith(
                    color: AppColors.bg, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(
                        color: AppColors.pearl, fontWeight: FontWeight.w600)),
                Text(
                  [
                    e.category.labelFr,
                    if (e.neighbourhood != null) e.neighbourhood!,
                    if (e.priceTier == 0) 'Gratuit',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      t.labelSmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The per-provider status: keyless event source OK, the keyed seams reported.
class _SeamProof extends StatelessWidget {
  const _SeamProof({required this.statuses});
  final List<LiveProviderStatus> statuses;

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
              const SizedBox(height: AppSpacing.sm),
              Text('Couche live · sources',
                  style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.xs),
              Text('Ce qui marche sans clé maintenant, et les amorces à clé.',
                  style:
                      t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              for (final s in statuses) ...[
                _StatusRow(status: s),
                const SizedBox(height: AppSpacing.sm),
              ],
              const Spacer(),
              Text(
                'LiveAvailabilityService — timeout court + repli, jamais bloquant.',
                style: t.labelSmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});
  final LiveProviderStatus status;

  ({IconData icon, Color color, String tag}) get _style {
    switch (status.state) {
      case LiveFetchState.ok:
        return (icon: Icons.check_circle, color: AppColors.edgeDown, tag: 'OK');
      case LiveFetchState.empty:
        return (icon: Icons.inbox, color: AppColors.textMuted, tag: 'VIDE');
      case LiveFetchState.needsKey:
        return (
          icon: Icons.key,
          color: const Color(0xFFE0B15A),
          tag: 'CLÉ REQUISE'
        );
      case LiveFetchState.failed:
        return (
          icon: Icons.cloud_off,
          color: const Color(0xFFE08A7A),
          tag: 'REPLI'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = _style;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: s.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(s.icon, color: s.color, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleSmall?.copyWith(
                        color: AppColors.pearl, fontWeight: FontWeight.w600)),
                if (status.note != null)
                  Text(status.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelSmall
                          ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            status.state == LiveFetchState.ok
                ? '${status.count} · ${s.tag}'
                : s.tag,
            style: t.labelMedium
                ?.copyWith(color: s.color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Network unreachable → every source fails gracefully → degrade to static.
class _FallbackProof extends StatelessWidget {
  const _FallbackProof({required this.statuses, required this.fallbackRows});
  final List<LiveProviderStatus> statuses;
  final List<CatalogEntry> fallbackRows;

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
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                const Icon(Icons.cloud_off,
                    color: Color(0xFFE08A7A), size: 18),
                const SizedBox(width: 6),
                Text('SOURCE LIVE INJOIGNABLE',
                    style:
                        t.labelMedium?.copyWith(color: AppColors.textMuted)),
              ]),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Aucun plantage, aucun blocage : on bascule sur les suggestions '
                'statiques et la boucle continue.',
                style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final s in statuses) ...[
                _StatusRow(status: s),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.md),
              Text('Repli statique servi à la place :',
                  style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.xs),
              for (final e in fallbackRows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${e.name}  (${e.kind.labelFr}, instantané)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(color: AppColors.pearl)),
                ),
              const Spacer(),
              Text('Le catalogue statique fonctionne 100 % hors-ligne.',
                  style: t.labelSmall?.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
