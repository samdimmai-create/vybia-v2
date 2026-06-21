import '../../guest/model/dimension.dart';
import '../model/activity.dart';
import '../model/lms_motive.dart';
import '../model/wellbeing.dart';
import 'leisure_motivation.dart';
import 'score_breakdown.dart';

/// Turns a [ScoreBreakdown] into the honest, specific "pourquoi" factor list
/// shown on a recommendation (S11D) — e.g. `motif : évasion · tout près ·
/// nouveau pour toi`.
///
/// The factors are NOT a fixed template: they are the activity's actual
/// top-contributing scoring terms, each rendered as a short French chip, so the
/// deterministic explanation is already specific and truthful BEFORE any LLM.
/// (This same ordered, labelled breakdown is the seam a generative "pourquoi"
/// would consume later.)
class RecoFactors {
  const RecoFactors._();

  /// The top [max] contributing factors for this pick, strongest first.
  static List<String> top({
    required ScoreBreakdown breakdown,
    required Activity activity,
    required LmsWeights lms,
    required WellbeingTags wellbeing,
    double? farness,
    int max = 3,
  }) {
    final out = <String>[];
    for (final term in breakdown.rankedTerms) {
      if (out.length >= max) break;
      final label = _label(term.key, activity, lms, wellbeing, farness);
      if (label != null && !out.contains(label)) out.add(label);
    }
    // Always carry at least one honest reason, even for a thin breakdown.
    if (out.isEmpty) {
      out.add('dans l’esprit de ton moment');
    }
    return out;
  }

  static String? _label(
    String key,
    Activity a,
    LmsWeights lms,
    WellbeingTags wb,
    double? farness,
  ) {
    switch (key) {
      case 'motive':
        return 'motif : ${_motiveNoun(LeisureMotivation.dominant(lms))}';
      case 'affect':
        if (wb.hedoniaEudaimonia < 0.4) return 'pour souffler';
        if (wb.hedoniaEudaimonia > 0.6) return 'ça a du sens';
        return null;
      case 'context':
        return 'au bon moment';
      case 'social':
        final s = a.tag(Dimension.social);
        if (s > 0.6) return 'à partager';
        if (s < 0.4) return 'rien que pour toi';
        return null;
      case 'novelty':
        return a.tag(Dimension.novelty) >= 0.6 ? 'nouveau pour toi' : null;
      case 'happiness':
        return wb.happinessTrait > 0.55 ? 'ça fait du bien' : null;
      case 'proximity':
        if (farness != null && farness < 0.35) return 'tout près';
        return null;
      case 'pref':
        // Taste match is the backbone but too generic to read as a "reason";
        // it's already conveyed by the prose "pourquoi". Skip it as a chip.
        return null;
      default:
        return null;
    }
  }

  static String _motiveNoun(LmsMotive m) {
    switch (m) {
      case LmsMotive.intellectual:
        return 'découverte';
      case LmsMotive.social:
        return 'partage';
      case LmsMotive.competence:
        return 'dépassement';
      case LmsMotive.stimulusAvoidance:
        return 'évasion';
    }
  }
}
