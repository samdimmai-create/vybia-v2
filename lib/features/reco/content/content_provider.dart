import '../../guest/data/assets.dart';
import '../../guest/model/dimension.dart';
import '../../guest/model/guest_profile.dart';
import '../engine/leisure_motivation.dart';
import '../engine/reco_context.dart';
import '../model/activity.dart';
import '../model/lms_motive.dart';

/// The content surface of the engine (S9F) — the "pourquoi", the reaction copy
/// and the image choice. Behind an interface so a real LLM brain can slot in
/// later (truly generative why/copy/imagery) WITHOUT touching the engine: swap
/// the [TemplatedContentProvider] for an `LlmContentProvider` and nothing else
/// changes.
abstract class ContentProvider {
  /// A tailored one-line French "pourquoi ça te va" for [a], keyed to the
  /// guest's dominant motive, the matched axes and any active life-context.
  String why(
    Activity a,
    GuestProfile profile, {
    required LmsWeights lms,
    required List<Dimension> topDims,
    RecoContext? context,
  });

  /// The bundled image that best fits [a]'s category AND the current vibe.
  String imageFor(Activity a, GuestProfile profile);
}

/// Deterministic, on-device, explainable content from RICH templates (no LLM).
///
/// The "pourquoi" folds the guest's dominant Beard & Ragheb motive, up to two
/// matched taste axes and any active life-context tone into one of several
/// sentence shapes (chosen by the activity id), so across a single batch the
/// lines read tailored and don't repeat verbatim. Image selection narrows to the
/// activity's category then picks the candidate that best matches the blended
/// vibe. True per-activity generative copy/imagery is a later LLM upgrade.
class TemplatedContentProvider implements ContentProvider {
  const TemplatedContentProvider();

  @override
  String why(
    Activity a,
    GuestProfile profile, {
    required LmsWeights lms,
    required List<Dimension> topDims,
    RecoContext? context,
  }) {
    // Distance is shown explicitly on the card, so keep it out of the prose.
    final dims = topDims.where((d) => d != Dimension.distance).toList();
    final frags = dims.take(2).map((d) => _fragment(d, a.tag(d))).toList();
    final base = frags.isEmpty ? 'dans l’esprit de ton moment' : frags.join(', ');
    final motive = _motiveFrag(LeisureMotivation.dominant(lms));

    final shape = a.id.hashCode.abs() % 4;
    var s = switch (shape) {
      0 => '${_cap(base)} — $motive.',
      1 => 'Idéal $motive : $base.',
      2 => '${_cap(base)}, $motive.',
      _ => '${_cap(motive)}, $base.',
    };

    // Fold in the strongest active life-context's tone so the reason reads
    // context-aware (e.g. "… · léger pour le portefeuille").
    if (profile.contexts.isNotEmpty) {
      final tone = profile.contexts.first.toneFr;
      s = '${s.substring(0, s.length - 1)} · $tone.';
    }
    return s;
  }

  @override
  String imageFor(Activity a, GuestProfile profile) {
    final candidates = _candidates(a.category);
    if (candidates.isEmpty) return a.image;
    // Blend the activity's own character with the guest's current vibe so the
    // picture matches the mood, not just the category.
    final vibe = (0.5 * a.tag(Dimension.vibe) + 0.5 * profile.valueOf(Dimension.vibe))
        .clamp(0.0, 1.0)
        .toDouble();
    final idx =
        (vibe * candidates.length).floor().clamp(0, candidates.length - 1);
    return candidates[idx];
  }

  /// Per-category candidate images, ordered calm → lively (S9F).
  List<String> _candidates(ActivityCategory c) {
    switch (c) {
      case ActivityCategory.cafe:
        return const [Img.cafe];
      case ActivityCategory.food:
        return const [Img.restaurant, Img.market];
      case ActivityCategory.nature:
        return const [Img.garden, Img.park, Img.viewpoint];
      case ActivityCategory.culture:
        return const [Img.museum, Img.gallery, Img.theatre, Img.cinema];
      case ActivityCategory.nightlife:
        return const [Img.bar];
      case ActivityCategory.active:
        return const [Img.park, Img.sports];
      case ActivityCategory.wellness:
        return const [Img.garden, Img.park];
      case ActivityCategory.creative:
        return const [Img.gallery, Img.theatre];
    }
  }

  String _motiveFrag(LmsMotive m) {
    switch (m) {
      case LmsMotive.intellectual:
        return 'pour découvrir';
      case LmsMotive.social:
        return 'pour partager';
      case LmsMotive.competence:
        return 'pour te dépasser';
      case LmsMotive.stimulusAvoidance:
        return 'pour décompresser';
    }
  }

  String _fragment(Dimension d, double v) {
    switch (d) {
      case Dimension.energy:
        return v > 0.6 ? 'ça bouge, à ton rythme' : 'tout en douceur';
      case Dimension.social:
        return v > 0.6 ? 'avec du monde autour' : 'au calme, juste pour toi';
      case Dimension.novelty:
        return v > 0.6 ? 'une vraie découverte' : 'une valeur sûre';
      case Dimension.distance:
        return v > 0.6 ? 'ça vaut le petit trajet' : 'à deux pas';
      case Dimension.indoor:
        return v > 0.6 ? 'bien à l’abri' : 'au grand air';
      case Dimension.timing:
        return v > 0.6 ? 'taillé pour la soirée' : 'parfait en journée';
      case Dimension.budget:
        return v < 0.4 ? 'sans te ruiner' : 'tu te fais plaisir';
      case Dimension.vibe:
        return v > 0.6 ? 'une ambiance vivante' : 'une atmosphère intime';
      case Dimension.mood:
        return 'dans ton humeur du moment';
    }
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
