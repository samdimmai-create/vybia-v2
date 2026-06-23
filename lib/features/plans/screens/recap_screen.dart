import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/edge_action.dart';
import '../../../shared/glass.dart';
import '../../guest/widgets/scene_scaffold.dart';
import '../../reco/model/activity.dart';
import '../model/plan.dart';
import '../state/plan_controller.dart';

/// Route arguments for the [RecapScreen]: the activity to commit plus the
/// planning details gathered so far (and the plan id when re-planning).
class RecapArgs {
  const RecapArgs({
    required this.activity,
    required this.moment,
    required this.companions,
    this.pickedDate,
    this.editPlanId,
  });

  final Activity activity;
  final PlanMoment moment;
  final PlanCompanions companions;
  final DateTime? pickedDate;
  final String? editPlanId;
}

/// S19D — THE RECAP / CONFIRM screen, shown over the activity image BEFORE a
/// (re)plan is saved.
///
/// It gathers the whole plan into one calm review — image + title + summary +
/// the planning details (Quand / Avec qui), with room left for future
/// "compléter" actions (réservations, billets…). The orb owns the four actions
/// the cahier specifies:
///   HAUT  = détails de la planification (a review panel)
///   BAS   = confirmer / enregistrer
///   GAUCHE = partager / inviter
///   DROITE = annuler / supprimer
class RecapScreen extends StatefulWidget {
  const RecapScreen({
    super.key,
    required this.activity,
    required this.moment,
    required this.companions,
    this.pickedDate,
    this.editPlanId,
  });

  factory RecapScreen.fromRoute(RouteSettings settings) {
    final args = settings.arguments;
    if (args is RecapArgs) {
      return RecapScreen(
        activity: args.activity,
        moment: args.moment,
        companions: args.companions,
        pickedDate: args.pickedDate,
        editPlanId: args.editPlanId,
      );
    }
    throw ArgumentError('RecapScreen requires RecapArgs');
  }

  final Activity activity;
  final PlanMoment moment;
  final PlanCompanions companions;
  final DateTime? pickedDate;
  final String? editPlanId;

  bool get isEdit => editPlanId != null;

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  bool _showDetails = false;

  String get _summary =>
      '${widget.moment.labelFr} · ${widget.companions.labelFr}';

  void _onDirection(OrbDirection d) {
    switch (d) {
      case OrbDirection.up:
        setState(() => _showDetails = true);
      case OrbDirection.down:
        _confirm();
      case OrbDirection.left:
        _share();
      case OrbDirection.right:
        _cancelOrDelete();
    }
  }

  void _confirm() {
    final plans = PlanScope.of(context);
    final id = widget.editPlanId;
    if (id != null) {
      plans.update(id,
          moment: widget.moment,
          companions: widget.companions,
          pickedDate: widget.pickedDate);
    } else {
      plans.create(
        activity: widget.activity,
        moment: widget.moment,
        companions: widget.companions,
        pickedDate: widget.pickedDate,
      );
    }
    // Land on Mes Plans; clear the orb flow so back can't re-enter it.
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.mesPlans,
      (route) => route.isFirst,
    );
  }

  Future<void> _share() async {
    final text = 'Ça te dit ? « ${widget.activity.titleFr} » — $_summary. '
        'On le fait ensemble ?';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text('Invitation copiée — partage-la à qui tu veux.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1800),
      ));
  }

  void _cancelOrDelete() {
    final id = widget.editPlanId;
    if (id != null) {
      // Re-planning → DROITE deletes the existing plan, then back to Mes Plans.
      PlanScope.of(context).remove(id);
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.mesPlans,
        (route) => route.isFirst,
      );
    } else {
      // Fresh plan → DROITE just abandons the recap (back one step).
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    return Stack(
      fit: StackFit.expand,
      children: [
        SceneScaffold(
          key: const ValueKey('plan_recap'),
          image: a.image,
          badge: widget.isEdit ? 'On revoit ton plan' : 'Ton plan, prêt',
          journeyStep: JourneyStep.plan.index,
          headline: a.titleFr,
          prompt: widget.isEdit
              ? 'Vérifie, puis enregistre tes changements.'
              : 'Voilà ton plan. Confirme-le, ou ajuste avant.',
          bottomBubble: true,
          infoLine: '$_summary · ${a.category.labelFr}',
          tags: const ['récap'],
          // Double-tap leaves the recap without saving (back one step).
          onDoubleTap: () => Navigator.of(context).maybePop(),
          up: 'Détails',
          down: widget.isEdit ? 'Enregistrer' : 'Confirmer',
          left: 'Partager',
          right: widget.isEdit ? 'Supprimer' : 'Annuler',
          upAction: EdgeAction.curious,
          downAction: EdgeAction.go, // commit → green
          leftAction: EdgeAction.joy,
          rightAction: EdgeAction.reject,
          onDirection: _onDirection,
        ),
        if (_showDetails)
          Positioned.fill(
            child: _DetailsPanel(
              activity: a,
              summary: _summary,
              onDismiss: () => setState(() => _showDetails = false),
            ),
          ),
      ],
    );
  }
}

/// HAUT → a calm review of the planning details over a dimmed image, with room
/// reserved for future "compléter" actions (réservations, billets, itinéraire).
class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.activity,
    required this.summary,
    required this.onDismiss,
  });

  final Activity activity;
  final String summary;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onDismiss,
      child: ColoredBox(
        color: AppColors.bg.withValues(alpha: 0.82),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Détails de la planification',
                    style: t.titleLarge?.copyWith(
                        color: AppColors.pearl, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(label: 'Activité', value: activity.titleFr),
                _DetailRow(label: 'Quand · Avec qui', value: summary),
                _DetailRow(label: 'Lieu', value: activity.category.labelFr),
                const SizedBox(height: AppSpacing.lg),
                Text('À compléter bientôt',
                    style: t.labelLarge?.copyWith(
                        color: AppColors.accent, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final f in const ['Réservation', 'Billets', 'Itinéraire'])
                      GlassCapsule(
                        tint: AppColors.accent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: 5),
                        child: Text('• $f',
                            style: t.labelSmall
                                ?.copyWith(color: AppColors.pearl)),
                      ),
                  ],
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.center,
                  child: Text('Touche pour revenir',
                      style: t.labelMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: t.labelSmall?.copyWith(
                  color: AppColors.textMuted, letterSpacing: 0.6)),
          const SizedBox(height: 2),
          Text(value,
              style: t.bodyLarge?.copyWith(color: AppColors.pearl)),
        ],
      ),
    );
  }
}
