import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart' show OrbDirection;
import '../../guest/data/assets.dart';
import '../../guest/model/dimension.dart';
import '../../guest/state/guest_controller.dart';
import '../../guest/widgets/reflection_transition.dart';
import '../../guest/widgets/scene_scaffold.dart';
import '../../reco/model/activity.dart';
import '../model/plan.dart';
import '../state/plan_controller.dart';
import 'recap_screen.dart';

/// Route arguments for [PlanifierScreen].
///
/// [activity] null = PLAN FROM ZERO (S19D): the guest opened Planifier from the
/// Accueil with no activity in mind, so we gather Quand / Avec qui / mood and
/// then drop them into the engine LOOP to find the activity. When an activity is
/// supplied we're planning a chosen reco (or, with [editPlanId], re-planning).
class PlanifierArgs {
  const PlanifierArgs({this.activity, this.editPlanId});

  final Activity? activity;
  final String? editPlanId;
}

/// S19D — the carried-forward planning draft handed to the engine loop on a
/// plan-from-zero, so the loop's eventual selection lands straight on the recap
/// with the Quand / Avec qui already chosen (no re-asking).
class PlanDraft {
  const PlanDraft({
    required this.moment,
    required this.companions,
    this.pickedDate,
  });

  final PlanMoment moment;
  final PlanCompanions companions;
  final DateTime? pickedDate;
}

/// Low-friction, all-orb planning flow. Two entries:
///   * from a reco (activity known): Quand ? → Avec qui ? → recap/confirm.
///   * from the Accueil (PLAN FROM ZERO, activity null, S19D): Quand ? →
///     Avec qui ? → mood → the engine LOOP (which ends on the recap).
class PlanifierScreen extends StatefulWidget {
  const PlanifierScreen({super.key, this.activity, this.editPlanId});

  final Activity? activity;
  final String? editPlanId;

  static PlanifierScreen fromRoute(RouteSettings settings) {
    final args = settings.arguments;
    if (args is PlanifierArgs) {
      return PlanifierScreen(
          activity: args.activity, editPlanId: args.editPlanId);
    }
    // Bare deep link / Accueil → Planifier with no args = plan from zero.
    return const PlanifierScreen();
  }

  /// True when there's no chosen activity yet — we plan from zero into the loop.
  bool get fromZero => activity == null && editPlanId == null;

  @override
  State<PlanifierScreen> createState() => _PlanifierScreenState();
}

enum _Step { moment, companions, mood, reflecting }

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

  /// The image to wear on the gathering steps — the chosen activity's, or a
  /// neutral, inviting one when planning from zero.
  String get _image => widget.activity?.image ?? Img.viewpoint;

  String get _activityLine => widget.activity == null
      ? 'On trouvera l’activité ensemble, juste après.'
      : '« ${widget.activity!.titleFr} » · ${widget.activity!.category.labelFr}';

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
      // Plan-from-zero: capture a mood next, then enter the loop. With a chosen
      // activity: a brief reflection bridges into the recap.
      _step = widget.fromZero ? _Step.mood : _Step.reflecting;
    });
  }

  /// Plan-from-zero mood capture — the same four moods as Welcome, seeding the
  /// engine before the loop begins.
  void _onMood(OrbDirection d) {
    final guest = GuestScope.of(context);
    switch (d) {
      case OrbDirection.left: // posé
        guest.setMood(0.15, nudges: {
          Dimension.energy: 0.2,
          Dimension.vibe: 0.2,
          Dimension.social: 0.3,
        });
      case OrbDirection.up: // curieux
        guest.setMood(0.5, nudges: {Dimension.novelty: 0.8, Dimension.energy: 0.55});
      case OrbDirection.right: // sociable
        guest.setMood(0.7, nudges: {Dimension.social: 0.85, Dimension.vibe: 0.7});
      case OrbDirection.down: // plein d'énergie
        guest.setMood(0.95, nudges: {Dimension.energy: 0.9, Dimension.vibe: 0.8});
    }
    // Into the LOOP, carrying the plan draft so its selection lands on the recap.
    Navigator.of(context).pushReplacementNamed(
      AppRouter.engine,
      arguments: PlanDraft(
        moment: _moment!,
        companions: _companions!,
        pickedDate: _pickedDate,
      ),
    );
  }

  /// Plan reflection slides: the activity plus the chosen moment + companions.
  List<ReflectionSlide> _planSlides() {
    final a = widget.activity!;
    return [
      ReflectionSlide(image: a.image, label: 'Pour « ${a.titleFr} »'),
      if (_moment != null) ReflectionSlide(image: a.image, label: _moment!.labelFr),
      if (_companions != null)
        ReflectionSlide(image: a.image, label: _companions!.labelFr),
    ];
  }

  void _toRecap() {
    Navigator.of(context).pushReplacementNamed(
      AppRouter.recap,
      arguments: RecapArgs(
        activity: widget.activity!,
        moment: _moment!,
        companions: _companions!,
        pickedDate: _pickedDate,
        editPlanId: widget.editPlanId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.moment:
        return SceneScaffold(
          key: const ValueKey('plan_moment'),
          image: _image,
          badge: _isEdit
              ? 'On ajuste ton plan'
              : widget.fromZero
                  ? 'On planifie ensemble'
                  : 'On planifie',
          journeyStep: JourneyStep.plan.index,
          headline: 'Quand ?',
          prompt: widget.fromZero
              ? 'Dis-moi d’abord quand — on cherchera l’activité juste après.'
              : 'Glisse vers le moment qui te va pour « ${widget.activity!.titleFr} ».',
          bottomBubble: true,
          infoLine: _activityLine,
          // S18D: double-tap = back ONE step → leave the planner here.
          onDoubleTap: () => Navigator.of(context).maybePop(),
          left: 'Maintenant',
          right: 'Ce soir',
          up: 'Ce week-end',
          down: 'Choisir une date',
          onDirection: _onMoment,
        );
      case _Step.companions:
        return SceneScaffold(
          key: const ValueKey('plan_companions'),
          image: _image,
          badge: _moment!.labelFr,
          journeyStep: JourneyStep.plan.index,
          headline: 'Avec qui ?',
          prompt: 'Glisse vers celles et ceux qui seront du voyage.',
          bottomBubble: true,
          infoLine: _activityLine,
          onDoubleTap: () => setState(() => _step = _Step.moment),
          left: 'Solo',
          right: 'En couple',
          up: 'Entre amis',
          down: 'En famille',
          onDirection: _onCompanions,
        );
      case _Step.mood:
        return SceneScaffold(
          key: const ValueKey('plan_mood'),
          image: Img.calm,
          badge: '${_moment!.labelFr} · ${_companions!.labelFr}',
          journeyStep: JourneyStep.plan.index,
          headline: 'Dans quel état d’esprit ?',
          prompt: 'Choisis l’ambiance — Vybia trouvera l’activité qui colle.',
          bottomBubble: true,
          onDoubleTap: () => setState(() => _step = _Step.companions),
          left: 'Posé',
          up: 'Curieux',
          right: 'Sociable',
          down: 'Plein d’énergie',
          onDirection: _onMood,
        );
      case _Step.reflecting:
        return ReflectionTransition(
          key: const ValueKey('plan_reflecting'),
          title: 'Vybia prépare ton plan',
          slides: _planSlides(),
          onDone: () {
            if (mounted) _toRecap();
          },
        );
    }
  }
}
