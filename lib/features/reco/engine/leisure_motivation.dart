import '../../guest/model/dimension.dart';
import '../../guest/model/guest_profile.dart';
import '../model/activity.dart';
import '../model/lms_motive.dart';

/// Deterministic mapping onto the **Beard & Ragheb Leisure Motivation Scale**
/// (the four [LmsMotive] components) — on-device, explainable, no LLM (S9C).
///
/// The four LMS motives are a READOUT of the latent profile, not independent
/// stored state, so they can never drift out of sync with the taste vector. The
/// guest's weights come from their profile + mood; each activity's affinity is
/// computed from its existing taste axes + its (hedonic/relaxation/eudaimonic)
/// affinities + its category. This adds the richer 4-motive model without
/// hand-authoring four new numbers on every catalog entry.
class LeisureMotivation {
  const LeisureMotivation._();

  /// The guest's normalized pull toward each LMS component, from their latent
  /// profile and mood (mood: 0 calm → 1 energetic).
  static LmsWeights weightsFor(GuestProfile p) {
    final mood = p.valueOf(Dimension.mood);
    final energy = p.valueOf(Dimension.energy);
    final social = p.valueOf(Dimension.social);
    final novelty = p.valueOf(Dimension.novelty);
    final vibe = p.valueOf(Dimension.vibe);

    // "Curiosity" peaks at a mid (exploratory) mood, low at either extreme.
    final curiosity = (1 - (mood - 0.5).abs() * 2).clamp(0.0, 1.0).toDouble();

    final intellectual = 0.6 * novelty + 0.4 * curiosity;
    final socialW = 0.6 * social + 0.4 * (0.5 * vibe + 0.5 * mood);
    final competence = 0.5 * energy + 0.3 * mood + 0.2 * novelty;
    final stimulusAvoidance =
        0.5 * (1 - energy) + 0.35 * (1 - mood) + 0.15 * (1 - social);

    final sum = intellectual + socialW + competence + stimulusAvoidance;
    if (sum <= 0) {
      return (
        intellectual: 0.25,
        social: 0.25,
        competence: 0.25,
        stimulusAvoidance: 0.25,
      );
    }
    return (
      intellectual: intellectual / sum,
      social: socialW / sum,
      competence: competence / sum,
      stimulusAvoidance: stimulusAvoidance / sum,
    );
  }

  /// An activity's affinity to each LMS component, from its axes + motive
  /// affinities + category. Independent 0..1 values (not normalized).
  static LmsAffinity affinityFor(Activity a) {
    final energy = a.tag(Dimension.energy);
    final social = a.tag(Dimension.social);
    final novelty = a.tag(Dimension.novelty);
    final vibe = a.tag(Dimension.vibe);
    final m = a.motives; // (hedonic, relaxation, eudaimonic)

    final isCerebral = a.category == ActivityCategory.culture ||
        a.category == ActivityCategory.creative;
    final isActive = a.category == ActivityCategory.active ||
        a.category == ActivityCategory.nature;

    double c(double v) => v.clamp(0.0, 1.0).toDouble();
    return (
      intellectual:
          c(0.5 * novelty + 0.3 * m.eudaimonic + (isCerebral ? 0.2 : 0.0)),
      social: c(0.55 * social + 0.25 * vibe + 0.2 * m.hedonic),
      competence:
          c(0.5 * energy + 0.3 * m.eudaimonic + (isActive ? 0.2 : 0.0)),
      stimulusAvoidance:
          c(0.45 * (1 - energy) + 0.35 * m.relaxation + 0.2 * (1 - social)),
    );
  }

  /// How well an activity's LMS affinity serves the guest's LMS weights, 0..1.
  static double match(LmsWeights w, LmsAffinity a) => (w.intellectual *
              a.intellectual +
          w.social * a.social +
          w.competence * a.competence +
          w.stimulusAvoidance * a.stimulusAvoidance)
      .clamp(0.0, 1.0)
      .toDouble();

  /// The guest's single strongest motive — used for explanation/tone (S9F).
  static LmsMotive dominant(LmsWeights w) {
    var best = LmsMotive.intellectual;
    var bestV = w.intellectual;
    if (w.social > bestV) {
      best = LmsMotive.social;
      bestV = w.social;
    }
    if (w.competence > bestV) {
      best = LmsMotive.competence;
      bestV = w.competence;
    }
    if (w.stimulusAvoidance > bestV) {
      best = LmsMotive.stimulusAvoidance;
      bestV = w.stimulusAvoidance;
    }
    return best;
  }
}
