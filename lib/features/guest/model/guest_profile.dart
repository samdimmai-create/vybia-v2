import 'dimension.dart';

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

  double valueOf(Dimension d) => _value[d] ?? 0.5;
  double confidenceOf(Dimension d) => _confidence[d] ?? 0.0;

  bool get isEmpty => _value.isEmpty;

  /// Resets to a blank profile (used on /dev landings and replays).
  void clear() {
    _value.clear();
    _confidence.clear();
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

  /// Human-readable recap lines (French) for the confident dimensions.
  List<({Dimension dim, String reading})> readout() {
    final out = <({Dimension dim, String reading})>[];
    for (final d in Dimension.values) {
      if (confidenceOf(d) <= 0.05) continue;
      out.add((dim: d, reading: _reading(d, valueOf(d))));
    }
    return out;
  }

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
