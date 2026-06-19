import '../../../core/theme/app_colors.dart' show OrbDirection;
import 'dimension.dart';

/// One answer choice on a question scene, bound to an orb direction.
///
/// Choosing it sets the question's [target] dimension to [value] and applies
/// any correlated [nudges] (other dimensions → value) so the engine learns more
/// than one axis per swipe.
class QOption {
  const QOption({
    required this.direction,
    required this.label,
    required this.image,
    required this.value,
    this.nudges = const {},
  });

  final OrbDirection direction;
  final String label;
  final String image; // full-bleed situational asset
  final double value; // value applied to the question's target dimension
  final Map<Dimension, double> nudges;
}

/// A single situational question: a prompt plus 2–4 directional options.
class Question {
  const Question({
    required this.id,
    required this.target,
    required this.prompt,
    required this.options,
  });

  final String id;
  final Dimension target;
  final String prompt;
  final List<QOption> options;

  QOption? optionFor(OrbDirection d) {
    for (final o in options) {
      if (o.direction == d) return o;
    }
    return null;
  }
}
