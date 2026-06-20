import 'dimension.dart';
import 'life_context.dart';

/// The guest's evolving taste profile — pure data, no Flutter.
///
/// Each [Dimension] carries a [value] (0..1) and a [confidence] (0..1, how sure
/// we are of that value). The adaptive engine reads [confidence] to decide what
/// to ask next and when to stop. A direct answer sets a dimension with full
/// weight; a correlated *nudge* shifts a related dimension a little and raises
/// its confidence partially — that cross-information is what lets the flow stop
/// early without asking all eight questions.
class GuestProfile {
  final Map<Dimension, double> _value = {};
  final Map<Dimension, double> _confidence = {};

  /// Active life-contexts (S9D) — durable real-world situations that act as
  /// feasibility filters. Captured implicitly at the orb, persisted with the
  /// profile.
  final Set<LifeContext> _contexts = {};

  double valueOf(Dimension d) => _value[d] ?? 0.5;
  double confidenceOf(Dimension d) => _confidence[d] ?? 0.0;

  bool get isEmpty => _value.isEmpty;

  /// The currently active life-contexts (unmodifiable).
  Set<LifeContext> get contexts => Set.unmodifiable(_contexts);

  bool hasContext(LifeContext c) => _contexts.contains(c);

  /// Turn a life-context on or off.
  void setContext(LifeContext c, bool active) {
    if (active) {
      _contexts.add(c);
    } else {
      _contexts.remove(c);
    }
  }

  /// Resets to a blank profile (used on /dev landings and replays).
  void clear() {
    _value.clear();
    _confidence.clear();
    _contexts.clear();
  }

  /// Dimensions we treat as "known" (confident enough to stop probing them).
  static const double confidenceThreshold = 0.6;

  bool isConfident(Dimension d) => confidenceOf(d) >= confidenceThreshold;

  int get confidentCount =>
      Dimension.values.where(isConfident).length;

  /// A direct answer: blends toward [value] and locks in high confidence.
  void answer(Dimension d, double value) {
    final prior = _value[d];
    _value[d] = prior == null ? value : (prior * 0.35 + value * 0.65);
    _confidence[d] = (confidenceOf(d) + 0.7).clamp(0.0, 1.0);
  }

  /// A correlated nudge: gentle pull toward [value] with partial confidence.
  void nudge(Dimension d, double value, {double weight = 0.3}) {
    final prior = _value[d] ?? 0.5;
    _value[d] = prior * (1 - weight) + value * weight;
    _confidence[d] = (confidenceOf(d) + weight * 0.6).clamp(0.0, 1.0);
  }

  /// A deliberate manual adjustment from the Profil screen: shift a dimension by
  /// [delta] (clamped 0..1) and treat it as a known, owned preference (high
  /// confidence) since the guest set it on purpose.
  void adjust(Dimension d, double delta) {
    _value[d] = (valueOf(d) + delta).clamp(0.0, 1.0);
    _confidence[d] = (confidenceOf(d) + 0.25).clamp(0.0, 1.0);
  }

  /// JSON snapshot of the full profile (declared dimensions + everything the
  /// engine and revealed-preference loop inferred). Keyed by [Dimension.name].
  Map<String, dynamic> toJson() => {
        'values': {for (final e in _value.entries) e.key.name: e.value},
        'confidence': {for (final e in _confidence.entries) e.key.name: e.value},
        'contexts': [for (final c in _contexts) c.name],
      };

  /// Restore a profile previously written by [toJson]. Tolerant of missing or
  /// unknown keys so a schema change never crashes startup.
  void restore(Map<String, dynamic> json) {
    clear();
    final values = (json['values'] as Map?) ?? const {};
    final confidence = (json['confidence'] as Map?) ?? const {};
    for (final d in Dimension.values) {
      final v = values[d.name];
      final c = confidence[d.name];
      if (v is num) _value[d] = v.toDouble();
      if (c is num) _confidence[d] = c.toDouble();
    }
    final contexts = (json['contexts'] as List?) ?? const [];
    for (final name in contexts) {
      final c = name is String ? LifeContext.byName(name) : null;
      if (c != null) _contexts.add(c);
    }
  }

  /// Human-readable recap lines (French) for the confident dimensions.
  List<({Dimension dim, String reading})> readout() {
    final out = <({Dimension dim, String reading})>[];
    for (final d in Dimension.values) {
      if (confidenceOf(d) <= 0.05) continue;
      out.add((dim: d, reading: _reading(d, valueOf(d))));
    }
    return out;
  }

  /// Human-readable current leaning for a single dimension (used by the Profil
  /// "Ajuster" scene to show the live effect of each orb nudge).
  String readingFor(Dimension d) => _reading(d, valueOf(d));

  String _reading(Dimension d, double v) {
    switch (d) {
      case Dimension.mood:
        return v > 0.66
            ? 'plein d’élan'
            : v > 0.33
                ? 'curieux'
                : 'envie de calme';
      case Dimension.energy:
        return v > 0.6 ? 'tonique' : v < 0.4 ? 'doux' : 'équilibré';
      case Dimension.social:
        return v > 0.6 ? 'entouré' : v < 0.4 ? 'en solo' : 'au choix';
      case Dimension.novelty:
        return v > 0.6 ? 'envie de neuf' : v < 0.4 ? 'valeurs sûres' : 'ouvert';
      case Dimension.distance:
        return v > 0.6 ? 'prêt à bouger' : 'tout près';
      case Dimension.indoor:
        return v > 0.6 ? 'à l’intérieur' : v < 0.4 ? 'au grand air' : 'peu importe';
      case Dimension.timing:
        return v > 0.6 ? 'plutôt le soir' : 'plutôt en journée';
      case Dimension.budget:
        return v > 0.6 ? 'sans compter' : v < 0.4 ? 'malin' : 'raisonnable';
      case Dimension.vibe:
        return v > 0.6 ? 'effervescent' : v < 0.4 ? 'intime' : 'feutré';
    }
  }
}
