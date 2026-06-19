/// Why a person reaches for an activity — the three leisure-motivation families
/// the engine reasons over (a compact, well-established taxonomy):
///
///  * [hedonic]     — pleasure, stimulation, fun in the moment.
///  * [relaxation]  — recovery, calm, decompression.
///  * [eudaimonic]  — growth, meaning, learning, mastery.
///
/// Each [Activity] carries an affinity (0..1) per motive; the engine derives the
/// guest's motive *weights* from their live profile (mood + energy + novelty +
/// social) and matches the two.
enum Motive { hedonic, relaxation, eudaimonic }

/// A guest's normalized pull toward each motive (the three sum to ~1).
typedef MotiveWeights = ({double hedonic, double relaxation, double eudaimonic});

/// An activity's affinity to each motive (independent 0..1 values).
typedef MotiveAffinity = ({double hedonic, double relaxation, double eudaimonic});
