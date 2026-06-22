import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart' show OrbDirection;
import '../../../shared/edge_action.dart';
import '../../guest/widgets/reflection_transition.dart';
import '../../guest/widgets/scene_scaffold.dart';
import '../../reco/data/activity_catalog.dart';
import '../../reco/model/activity.dart';
import '../model/plan.dart';
import '../state/plan_controller.dart';

/// Route arguments for [PlanifierScreen]: the activity to plan, plus the id of
/// an existing plan when we're *modifying* rather than creating.
class PlanifierArgs {
  const PlanifierArgs({required this.activity, this.editPlanId});

  final Activity activity;
  final String? editPlanId;
}

/// Low-friction, all-orb planning flow reached by swiping *down* (Planifier) on
/// a reco — or from Mes Plans' "Modifier". Three quick swipes:
///   1. Quand ?   left=Maintenant · right=Ce soir · up=Ce week-end · down=Choisir
///   2. Avec qui ? left=Solo · right=En couple · up=Amis · down=Famille
///   3. Confirm    down=Confirmer · up=Revenir
/// On confirm it saves into [PlanController] and lands on Mes Plans, the new
/// plan sitting at the top of Futurs.
class PlanifierScreen extends StatefulWidget {
  const PlanifierScreen({super.key, required this.activity, this.editPlanId});

  final Activity activity;
  final String? editPlanId;

  static PlanifierScreen fromRoute(RouteSettings settings) {
    final args = settings.arguments;
    if (args is PlanifierArgs) {
      return PlanifierScreen(
          activity: args.activity, editPlanId: args.editPlanId);
    }
    // Bare deep link → plan the first catalog activity so the route still renders.
    return PlanifierScreen(activity: kActivityCatalog.first);
  }

  @override
  State<PlanifierScreen> createState() => _PlanifierScreenState();
}

enum _Step { moment, companions, reflecting, confirm }

class _PlanifierScreenState extends State<PlanifierScreen> {
  _Step _step = _Step.moment;
  PlanMoment? _moment;
  PlanCompanions? _companions;
  DateTime? _pickedDate;

  bool get _isEdit => widget.editPlanId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = widget.editPlanId;
    if (id != null && _moment == null) {
      final existing = PlanScope.of(context).byId(id);
      if (existing != null) {
        _moment = existing.moment;
        _companions = existing.companions;
      }
    }
  }

  Future<void> _onMoment(OrbDirection d) async {
    final moment = switch (d) {
      OrbDirection.left => PlanMoment.now,
      OrbDirection.right => PlanMoment.tonight,
      OrbDirection.up => PlanMoment.weekend,
      OrbDirection.down => PlanMoment.pickDate,
    };
    if (moment == PlanMoment.pickDate) {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 7)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        helpText: 'Choisir une date',
      );
      if (picked == null) return; // cancelled — stay on the moment step
      _pickedDate = DateTime(picked.year, picked.month, picked.day, 19);
    }
    setState(() {
      _moment = moment;
      _step = _Step.companions;
    });
  }

  void _onCompanions(OrbDirection d) {
    final companions = switch (d) {
      OrbDirection.left => PlanCompanions.solo,
      OrbDirection.right => PlanCompanions.couple,
      OrbDirection.up => PlanCompanions.friends,
      OrbDirection.down => PlanCompanions.family,
    };
    setState(() {
      _companions = companions;
      // S8.1E: a brief reflection bridges the choices into the confirm step.
      _step = _Step.reflecting;
    });
  }

  /// Plan reflection slides: the activity plus the chosen moment + companions,
  /// so the guest sees their plan being composed before confirming.
  List<ReflectionSlide> _planSlides() {
    final a = widget.activity;
    return [
      ReflectionSlide(image: a.image, label: 'Pour « ${a.titleFr} »'),
      if (_moment != null) ReflectionSlide(image: a.image, label: _moment!.labelFr),
      if (_companions != null)
        ReflectionSlide(image: a.image, label: _companions!.labelFr),
    ];
  }

  void _onConfirm(OrbDirection d) {
    if (d == OrbDirection.up) {
      setState(() => _step = _Step.companions); // step back to adjust
      return;
    }
    if (d != OrbDirection.down) return;
    final plans = PlanScope.of(context);
    final id = widget.editPlanId;
    if (id != null) {
      plans.update(id,
          moment: _moment, companions: _companions, pickedDate: _pickedDate);
    } else {
      plans.create(
        activity: widget.activity,
        moment: _moment!,
        companions: _companions!,
        pickedDate: _pickedDate,
      );
    }
    // Land on Mes Plans; the new/updated plan heads Futurs. Clear the stack so
    // the orb flow can't be re-entered with the back gesture.
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouter.mesPlans,
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    switch (_step) {
      case _Step.moment:
        return SceneScaffold(
          key: const ValueKey('plan_moment'),
          image: a.image,
          badge: _isEdit ? 'On ajuste ton plan' : 'On planifie',
          // S16C: the wayfinder follows through to the planning step, so the
          // journey reads coherently end to end.
          journeyStep: JourneyStep.plan.index,
          headline: 'Quand ?',
          prompt: 'Glisse vers le moment qui te va pour « ${a.titleFr} ».',
          left: 'Maintenant',
          right: 'Ce soir',
          up: 'Ce week-end',
          down: 'Choisir une date',
          onDirection: _onMoment,
        );
      case _Step.companions:
        return SceneScaffold(
          key: const ValueKey('plan_companions'),
          image: a.image,
          badge: _moment!.labelFr,
          journeyStep: JourneyStep.plan.index,
          headline: 'Avec qui ?',
          prompt: 'Glisse vers celles et ceux qui seront du voyage.',
          left: 'Solo',
          right: 'En couple',
          up: 'Entre amis',
          down: 'En famille',
          onDirection: _onCompanions,
        );
      case _Step.reflecting:
        return ReflectionTransition(
          key: const ValueKey('plan_reflecting'),
          title: 'Vybia prépare ton plan',
          slides: _planSlides(),
          onDone: () {
            if (mounted) setState(() => _step = _Step.confirm);
          },
        );
      case _Step.confirm:
        return SceneScaffold(
          key: const ValueKey('plan_confirm'),
          image: a.image,
          badge: '${_moment!.labelFr} · ${_companions!.labelFr}',
          journeyStep: JourneyStep.plan.index,
          headline: a.titleFr,
          prompt: _isEdit
              ? 'Glisse vers le bas pour enregistrer tes changements.'
              : 'Tout est prêt. Glisse vers le bas pour confirmer ton plan.',
          up: 'Revenir',
          down: _isEdit ? 'Enregistrer' : 'Confirmer',
          downAction: EdgeAction.go, // commit → green
          onDirection: _onConfirm,
        );
    }
  }
}
