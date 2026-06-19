import 'package:flutter/material.dart';

import '../../../components/bubble/bubble_image.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/edge_action.dart';
import '../../guest/widgets/scene_scaffold.dart';
import '../model/plan.dart';
import '../state/plan_controller.dart';
import 'planifier_screen.dart';

/// Mes Plans — the guest's saved outings, split into Futurs and Passés.
///
/// Each plan is a universal-bubble card over its activity image. Tapping a card
/// opens an immersive, all-orb selected-plan layer:
///   up = Détails · down = Modifier · left = Partager · right = Supprimer
class MesPlansScreen extends StatefulWidget {
  const MesPlansScreen({super.key});

  @override
  State<MesPlansScreen> createState() => _MesPlansScreenState();
}

class _MesPlansScreenState extends State<MesPlansScreen> {
  String? _selectedId; // open selected-plan layer
  bool _showDetails = false;

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceRaised,
        duration: const Duration(seconds: 2),
      ));
  }

  void _onSelectedDirection(Plan plan, OrbDirection d) {
    switch (d) {
      case OrbDirection.up:
        setState(() => _showDetails = true);
      case OrbDirection.down:
        Navigator.of(context).pushNamed(
          AppRouter.plan,
          arguments: PlanifierArgs(activity: plan.activity, editPlanId: plan.id),
        );
      case OrbDirection.left:
        _toast('Lien de partage copié — « ${plan.activity.titleFr} »');
      case OrbDirection.right:
        PlanScope.of(context).remove(plan.id);
        setState(() {
          _selectedId = null;
          _showDetails = false;
        });
        _toast('Plan supprimé');
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = PlanScope.of(context);
    return AnimatedBuilder(
      animation: plans,
      builder: (context, _) {
        final selected =
            _selectedId == null ? null : plans.byId(_selectedId!);
        return Stack(
          fit: StackFit.expand,
          children: [
            _PlansList(
              futurs: plans.futurs,
              passes: plans.passes,
              onTapPlan: (p) => setState(() {
                _selectedId = p.id;
                _showDetails = false;
              }),
            ),
            if (selected != null)
              Positioned.fill(
                child: _SelectedPlanLayer(
                  plan: selected,
                  showDetails: _showDetails,
                  onDirection: (d) => _onSelectedDirection(selected, d),
                  onDismissDetails: () => setState(() => _showDetails = false),
                  onClose: () => setState(() {
                    _selectedId = null;
                    _showDetails = false;
                  }),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The scrollable Futurs / Passés list.
class _PlansList extends StatelessWidget {
  const _PlansList({
    required this.futurs,
    required this.passes,
    required this.onTapPlan,
  });

  final List<Plan> futurs;
  final List<Plan> passes;
  final ValueChanged<Plan> onTapPlan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final empty = futurs.isEmpty && passes.isEmpty;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.bgWash),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.huge),
            children: [
              Text('Mes plans',
                  style: t.displayMedium?.copyWith(color: AppColors.pearl)),
              const SizedBox(height: AppSpacing.xxs),
              Text('Touche un plan pour le revoir, l’ajuster ou le partager.',
                  style: t.bodyLarge?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              if (empty) _emptyState(t),
              if (futurs.isNotEmpty) ...[
                _SectionHeader(label: 'Futurs', count: futurs.length),
                const SizedBox(height: AppSpacing.sm),
                for (final p in futurs)
                  _PlanCard(plan: p, onTap: () => onTapPlan(p)),
              ],
              if (passes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionHeader(label: 'Passés', count: passes.length),
                const SizedBox(height: AppSpacing.sm),
                for (final p in passes)
                  _PlanCard(plan: p, past: true, onTap: () => onTapPlan(p)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(TextTheme t) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxl),
        child: Column(
          children: [
            const Icon(Icons.event_note_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text('Aucun plan pour l’instant.',
                style: t.titleMedium?.copyWith(color: AppColors.pearl)),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Explore une idée, glisse vers le bas pour la planifier, '
              'et elle apparaîtra ici.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(label,
            style: t.titleLarge?.copyWith(
                color: AppColors.accent, fontWeight: FontWeight.w700)),
        const SizedBox(width: AppSpacing.xs),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text('$count',
              style: t.labelMedium?.copyWith(color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

/// One plan as a universal-bubble image card with its summary line.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onTap, this.past = false});

  final Plan plan;
  final VoidCallback onTap;
  final bool past;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: past ? 0.82 : 1.0,
          child: BubbleImage(
            image: AssetImage(plan.activity.image),
            shape: BubbleShape.card,
            aspectRatio: 1.5,
            label: plan.activity.titleFr,
            subtitle: plan.summaryFr,
            tint: past ? AppColors.accent : AppColors.primary,
            semanticLabel: '${plan.activity.titleFr}, ${plan.summaryFr}',
          ),
        ),
      ),
    );
  }
}

/// Immersive selected-plan layer: orb-driven actions over the activity image,
/// with an optional Détails panel laid on top.
class _SelectedPlanLayer extends StatelessWidget {
  const _SelectedPlanLayer({
    required this.plan,
    required this.showDetails,
    required this.onDirection,
    required this.onDismissDetails,
    required this.onClose,
  });

  final Plan plan;
  final bool showDetails;
  final ValueChanged<OrbDirection> onDirection;
  final VoidCallback onDismissDetails;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final past = plan.isPast();
    return Stack(
      fit: StackFit.expand,
      children: [
        SceneScaffold(
          key: ValueKey('selected_${plan.id}'),
          image: plan.activity.image,
          badge: plan.summaryFr,
          headline: plan.activity.titleFr,
          prompt: past
              ? 'Un souvenir. Replanifie-le, partage-le, ou retire-le.'
              : 'Ton plan est prêt. Choisis quoi en faire.',
          up: 'Détails',
          down: past ? 'Replanifier' : 'Modifier',
          left: 'Partager',
          right: 'Supprimer',
          upAction: EdgeAction.curious,
          downAction: EdgeAction.go,
          leftAction: EdgeAction.joy,
          rightAction: EdgeAction.reject,
          onDirection: onDirection,
        ),
        // A small close affordance so tapping out of the layer is discoverable.
        Positioned(
          top: AppSpacing.xl,
          right: AppSpacing.md,
          child: SafeArea(
            child: Material(
              color: AppColors.surface.withValues(alpha: 0.6),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: AppColors.pearl),
                onPressed: onClose,
                tooltip: 'Fermer',
              ),
            ),
          ),
        ),
        if (showDetails)
          Positioned.fill(
            child: _DetailsPanel(plan: plan, onDismiss: onDismissDetails, t: t),
          ),
      ],
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel(
      {required this.plan, required this.onDismiss, required this.t});

  final Plan plan;
  final VoidCallback onDismiss;
  final TextTheme t;

  @override
  Widget build(BuildContext context) {
    final a = plan.activity;
    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: AppColors.bg.withValues(alpha: 0.86),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ListView(
              children: [
                const SizedBox(height: AppSpacing.lg),
                Text(a.category.labelFr.toUpperCase(),
                    style: t.labelMedium?.copyWith(
                        color: AppColors.accent, letterSpacing: 1.2)),
                const SizedBox(height: AppSpacing.xs),
                Text(a.titleFr,
                    style: t.displaySmall?.copyWith(color: AppColors.pearl)),
                const SizedBox(height: AppSpacing.xs),
                _chipRow(plan),
                const SizedBox(height: AppSpacing.lg),
                Text(a.descFr,
                    style: t.bodyLarge
                        ?.copyWith(color: AppColors.textSecondary, height: 1.5)),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    const Icon(Icons.touch_app_outlined,
                        size: 18, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.xs),
                    Text('Touche pour revenir',
                        style: t.labelLarge
                            ?.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipRow(Plan plan) => Wrap(
        spacing: AppSpacing.xs,
        children: [
          _MetaChip(label: plan.moment.labelFr),
          _MetaChip(label: plan.companions.labelFr),
          _MetaChip(label: plan.isPast() ? 'Passé' : 'À venir'),
        ],
      );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: t.labelMedium?.copyWith(color: AppColors.pearl)),
    );
  }
}
