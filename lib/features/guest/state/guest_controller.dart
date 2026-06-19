import 'package:flutter/widgets.dart';

import '../data/question_bank.dart';
import '../engine/adaptive_engine.dart';
import '../model/dimension.dart';
import '../model/guest_profile.dart';
import '../model/question.dart';

/// What the guest wants to do once their taste is captured.
enum Intention { now, plan }

/// Holds the whole guest-loop state (mood + profile + adaptive engine + chosen
/// intention) and notifies listeners as it advances. Created once and shared
/// across the guest screens via [GuestScope] — the "simple provider" the brief
/// asks for (real persistence arrives in S5).
class GuestController extends ChangeNotifier {
  final GuestProfile profile = GuestProfile();
  final AdaptiveEngine engine = AdaptiveEngine(bank: kQuestionBank);

  Intention? intention;

  /// Captures the Welcome mood answer (0..1) and seeds correlated priors.
  void setMood(double value, {Map<Dimension, double> nudges = const {}}) {
    profile.answer(Dimension.mood, value);
    nudges.forEach((d, v) => profile.nudge(d, v));
    notifyListeners();
  }

  /// The current adaptive question, or null when the engine is done.
  Question? get currentQuestion =>
      engine.isDone(profile) ? null : engine.next(profile);

  bool get isDiscoveryDone => engine.isDone(profile);

  void answerCurrent(QOption option) {
    final q = currentQuestion;
    if (q == null) return;
    engine.apply(profile, q, option);
    notifyListeners();
  }

  void setIntention(Intention i) {
    intention = i;
    notifyListeners();
  }

  /// Wipes the session so /dev landings and replays start clean.
  void restart() {
    engine.reset();
    profile.clear();
    intention = null;
    notifyListeners();
  }
}

/// Inherited access to the shared [GuestController].
class GuestScope extends InheritedNotifier<GuestController> {
  const GuestScope({
    super.key,
    required GuestController controller,
    required super.child,
  }) : super(notifier: controller);

  static GuestController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<GuestScope>();
    assert(scope?.notifier != null, 'No GuestScope found in context');
    return scope!.notifier!;
  }
}
