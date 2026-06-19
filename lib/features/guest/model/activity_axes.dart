import 'dimension.dart';

/// The eight activity-fit axes — every [Dimension] except [Dimension.mood],
/// which is captured on Welcome and folded into the engine's motive weights
/// rather than matched directly. Shared so the engine, the catalog and the
/// revealed-preference nudges all reason over exactly the same axes.
const List<Dimension> kActivityAxes = [
  Dimension.energy,
  Dimension.social,
  Dimension.novelty,
  Dimension.distance,
  Dimension.indoor,
  Dimension.timing,
  Dimension.budget,
  Dimension.vibe,
];
