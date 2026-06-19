import 'package:flutter/widgets.dart';

import '../../../core/persistence/app_store.dart';
import '../data/question_bank.dart';
import '../engine/adaptive_engine.dart';
import '../model/dimension.dart';
import '../model/guest_profile.dart';
import '../model/question.dart';

/// What the guest wants to do once their taste is captured.
enum Intention { now, plan }

/// Holds the whole guest-loop state (mood + profile + adaptive engine + chosen
/// intention) and notifies listeners as it advances. Created once and shared
/// across the guest screens via [GuestScope] — the "simple provider".
///
/// When an [AppStore] is supplied (the live app), the profile is hydrated from
/// local storage on construction and written through on every change, so the
/// guest's taste, mood and intention persist across relaunches. Tests construct
/// it without a store for a clean in-memory session.
class GuestController extends ChangeNotifier {
  GuestController({AppStore? store}) : _store = store {
    final saved = store?.readProfileJson();
    if (saved != null) profile.restore(saved);
    intention = store?.readIntention();
  }

  final AppStore? _store;

  /// The persistence repository, exposed so screens that build their own
  /// controllers (e.g. the reco loop) can write through to the same store.
  AppStore? get store => _store;

  final GuestProfile profile = GuestProfile();
  final AdaptiveEngine engine = AdaptiveEngine(bank: kQuestionBank);

  Intention? intention;

  void _persistProfile() => _store?.saveProfile(profile);

  /// Captures the Welcome mood answer (0..1) and seeds correlated priors.
  void setMood(double value, {Map<Dimension, double> nudges = const {}}) {
    profile.answer(Dimension.mood, value);
    nudges.forEach((d, v) => profile.nudge(d, v));
    _persistProfile();
    notifyListeners();
  }

  /// Manually adjust one taste dimension from the Profil screen, persisting it.
  void adjustDimension(Dimension d, double delta) {
    profile.adjust(d, delta);
    _persistProfile();
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
    _persistProfile();
    notifyListeners();
  }

  void setIntention(Intention i) {
    intention = i;
    _store?.saveIntention(i);
    notifyListeners();
  }

  /// Wipes the in-memory session so /dev landings and replays start clean.
  /// Storage is left untouched — a fresh session simply overwrites it as the
  /// guest answers again; relaunches still rehydrate the persisted profile.
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
