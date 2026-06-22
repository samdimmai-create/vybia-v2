import '../../guest/model/dimension.dart';
import '../../guest/model/guest_profile.dart';
import '../engine/reco_context.dart';
import '../model/activity.dart';
import '../model/lms_motive.dart';
import '../model/recommendation.dart';
import 'content_provider.dart';
import 'llm_client.dart';

/// The content provider the app should use (S15C): the LLM-backed one when a
/// proxy URL is configured at build time, else the deterministic templated
/// provider. This is the single selection point — the engine, the reco loop and
/// the question loop all read their language through whatever this returns.
ContentProvider appContentProvider() =>
    isLlmConfigured ? LlmContentProvider() : const TemplatedContentProvider();

/// The LLM-backed content surface (S15B). Claude only **voices the language**;
/// the deterministic engine (scoring / selection / feasibility) stays the brain.
///
/// It `implements ContentProvider`, so it slots in wherever the templated
/// provider did. The **synchronous** interface methods ([why], [imageFor]) keep
/// returning the deterministic, grounded output — the engine path is never
/// blocked on a network call. The **generative variety** comes from the extra
/// async methods ([generateWhy], [generateQuestionPrompt], [generateReaction]),
/// which the UI awaits when it shows a card or a question, then falls back to the
/// exact deterministic text on ANY failure. So:
///
///   * the engine still decides WHAT to recommend / ask,
///   * Claude rewrites the WORDING fresh and non-verbatim each session,
///   * grounded in the engine's real factors (no hallucinated places), and
///   * if the proxy is down it silently reads exactly like the templated build.
class LlmContentProvider implements ContentProvider {
  LlmContentProvider({
    LlmClient? client,
    this.fallback = const TemplatedContentProvider(),
  }) : _client = client ?? LlmClient();

  final LlmClient _client;

  /// The deterministic provider used both for the synchronous interface and as
  /// the safety net behind every generative call.
  final TemplatedContentProvider fallback;

  /// True only when a proxy URL is configured — lets callers skip the async hop
  /// entirely (and the snappy templated copy shows with zero latency).
  bool get active => _client.configured;

  // ---- ContentProvider (synchronous, deterministic baseline) ---------------

  @override
  String why(
    Activity a,
    GuestProfile profile, {
    required LmsWeights lms,
    required List<Dimension> topDims,
    RecoContext? context,
  }) =>
      fallback.why(a, profile, lms: lms, topDims: topDims, context: context);

  @override
  String imageFor(Activity a, GuestProfile profile) =>
      fallback.imageFor(a, profile);

  // ---- Generative layer (Claude voices; engine already decided) ------------

  /// A fresh, non-verbatim "pourquoi ça te va" for the chosen real
  /// recommendation, grounded in the engine's real factors. Returns the
  /// deterministic [Recommendation.why] on any failure / when not configured.
  Future<String> generateWhy(
    Recommendation rec,
    GuestProfile profile, {
    RecoContext? context,
  }) async {
    if (!active) return rec.why;
    final gen = await _client.generate(
      maxTokens: 90,
      cacheKey: 'why:${rec.activity.id}',
      system:
          'Tu écris la phrase « pourquoi ça te va » d\'un concierge d\'activités '
          'à Montréal. UNE seule phrase en français, chaleureuse et concrète, '
          'maximum 20 mots. Tu ne réécris QUE l\'activité déjà choisie par le '
          'moteur : n\'invente jamais d\'autre lieu, d\'autre activité ni de '
          'détail. Pas de guillemets, pas d\'emoji, pas de « Voici ».',
      task: 'Reformule, fraîche et différente à chaque fois, la raison qui '
          'rend cette activité juste pour cette personne maintenant.',
      context: {
        'activite': rec.activity.titleFr,
        'categorie': rec.activity.category.labelFr,
        'facteurs': rec.factors,
        'pourquoi_deterministe': rec.why,
        'humeur': _moodWord(profile.valueOf(Dimension.mood)),
        'meteo': ?context?.weather?.toString(),
      },
    );
    return _clean(gen) ?? rec.why;
  }

  /// Fresh wording for an adaptive question. Returns [fallbackPrompt] verbatim on
  /// any failure — the same question, just a different phrasing.
  Future<String> generateQuestionPrompt(
    String fallbackPrompt, {
    String? dimensionLabel,
    GuestProfile? profile,
  }) async {
    if (!active) return fallbackPrompt;
    final gen = await _client.generate(
      maxTokens: 60,
      cacheKey: 'q:$fallbackPrompt',
      system:
          'Tu poses UNE question courte (max 12 mots) à une personne pour cerner '
          'son envie de sortie ce soir, en français, ton léger et complice. Garde '
          'EXACTEMENT le même sens que la question de référence — tu changes '
          'seulement la formulation. Pas de guillemets, pas d\'emoji.',
      task: 'Reformule cette question, fraîche et différente à chaque fois, sans '
          'en changer le sens.',
      context: {
        'question_reference': fallbackPrompt,
        'dimension': ?dimensionLabel,
      },
    );
    return _clean(gen) ?? fallbackPrompt;
  }

  /// A short reaction line after Intéressant / Pas intéressant. Returns a
  /// deterministic line on any failure.
  Future<String> generateReaction({
    required bool liked,
    required String activityTitle,
  }) async {
    final deterministic = liked ? 'Noté — on creuse ça.' : 'Compris, on passe.';
    if (!active) return deterministic;
    final gen = await _client.generate(
      maxTokens: 40,
      cacheKey: 'r:${liked ? 'y' : 'n'}:$activityTitle',
      system:
          'Tu réponds en une phrase très courte (max 8 mots), française, '
          'complice, à la réaction d\'une personne sur une suggestion de sortie. '
          'Pas de guillemets, pas d\'emoji.',
      task: liked
          ? 'La personne a aimé la suggestion : confirme avec entrain.'
          : 'La personne a écarté la suggestion : rassure, on enchaîne.',
      context: {'activite': activityTitle},
    );
    return _clean(gen) ?? deterministic;
  }

  void dispose() => _client.dispose();

  String _moodWord(double v) =>
      v > 0.6 ? 'posée' : (v < 0.4 ? 'pleine d\'élan' : 'au milieu');

  /// Strip wrapping quotes / stray whitespace from the model's reply. Returns
  /// null when nothing usable came back, so the caller falls back deterministically.
  String? _clean(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.length >= 2) {
      final f = s[0], l = s[s.length - 1];
      if ((f == '"' && l == '"') || (f == '«' && l == '»') || (f == '\'' && l == '\'')) {
        s = s.substring(1, s.length - 1).trim();
      }
    }
    return s.isEmpty ? null : s;
  }
}
