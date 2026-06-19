import '../../../core/theme/app_colors.dart' show OrbDirection;
import '../model/dimension.dart';
import '../model/question.dart';
import 'assets.dart';

/// The curated adaptive question bank — one question per probe dimension.
///
/// Each option carries the value for its question's target dimension PLUS
/// correlated [nudges] on neighbouring dimensions. Those nudges raise partial
/// confidence elsewhere, so the [AdaptiveEngine] usually reaches a confident
/// profile in 3–4 swipes instead of all eight.
const List<Question> kQuestionBank = [
  Question(
    id: 'energy',
    target: Dimension.energy,
    prompt: 'Quel rythme te tente ?',
    options: [
      QOption(
        direction: OrbDirection.left,
        label: 'Tout en douceur',
        image: Img.calm,
        value: 0.15,
        nudges: {Dimension.vibe: 0.25, Dimension.timing: 0.35},
      ),
      QOption(
        direction: OrbDirection.right,
        label: 'Plein d’élan',
        image: Img.energetic,
        value: 0.9,
        nudges: {Dimension.vibe: 0.8, Dimension.social: 0.7},
      ),
    ],
  ),
  Question(
    id: 'social',
    target: Dimension.social,
    prompt: 'Plutôt en solo ou entouré ?',
    options: [
      QOption(
        direction: OrbDirection.left,
        label: 'Rien qu’à moi',
        image: Img.walkNight,
        value: 0.1,
        nudges: {Dimension.vibe: 0.3},
      ),
      QOption(
        direction: OrbDirection.right,
        label: 'Avec du monde',
        image: Img.social,
        value: 0.9,
        nudges: {Dimension.energy: 0.7, Dimension.vibe: 0.8},
      ),
    ],
  ),
  Question(
    id: 'novelty',
    target: Dimension.novelty,
    prompt: 'Surprise ou valeur sûre ?',
    options: [
      QOption(
        direction: OrbDirection.left,
        label: 'Une valeur sûre',
        image: Img.cafe,
        value: 0.15,
        nudges: {Dimension.budget: 0.4, Dimension.distance: 0.3},
      ),
      QOption(
        direction: OrbDirection.right,
        label: 'Surprends-moi',
        image: Img.curious,
        value: 0.9,
        nudges: {Dimension.distance: 0.7},
      ),
    ],
  ),
  Question(
    id: 'distance',
    target: Dimension.distance,
    prompt: 'Tout près ou prêt à bouger ?',
    options: [
      QOption(
        direction: OrbDirection.left,
        label: 'À deux pas',
        image: Img.cafe,
        value: 0.1,
        nudges: {Dimension.energy: 0.35},
      ),
      QOption(
        direction: OrbDirection.right,
        label: 'Prêt à bouger',
        image: Img.rooftop,
        value: 0.9,
        nudges: {Dimension.energy: 0.7, Dimension.indoor: 0.2},
      ),
    ],
  ),
  Question(
    id: 'indoor',
    target: Dimension.indoor,
    prompt: 'Dedans ou dehors ?',
    options: [
      QOption(
        direction: OrbDirection.left,
        label: 'Au grand air',
        image: Img.rooftop,
        value: 0.1,
        nudges: {Dimension.distance: 0.6},
      ),
      QOption(
        direction: OrbDirection.right,
        label: 'Bien au chaud',
        image: Img.cinema,
        value: 0.9,
        nudges: {Dimension.distance: 0.3},
      ),
    ],
  ),
  Question(
    id: 'timing',
    target: Dimension.timing,
    prompt: 'En journée ou pour ce soir ?',
    options: [
      QOption(
        direction: OrbDirection.left,
        label: 'En pleine journée',
        image: Img.curious,
        value: 0.1,
      ),
      QOption(
        direction: OrbDirection.right,
        label: 'Pour ce soir',
        image: Img.walkNight,
        value: 0.9,
        nudges: {Dimension.vibe: 0.7},
      ),
    ],
  ),
  Question(
    id: 'budget',
    target: Dimension.budget,
    prompt: 'Plutôt malin ou sans compter ?',
    options: [
      QOption(
        direction: OrbDirection.left,
        label: 'En mode malin',
        image: Img.cafe,
        value: 0.1,
      ),
      QOption(
        direction: OrbDirection.right,
        label: 'Sans compter',
        image: Img.rooftop,
        value: 0.9,
        nudges: {Dimension.distance: 0.4},
      ),
    ],
  ),
  Question(
    id: 'vibe',
    target: Dimension.vibe,
    prompt: 'Quelle ambiance, là tout de suite ?',
    options: [
      QOption(
        direction: OrbDirection.left,
        label: 'Intime et feutré',
        image: Img.calm,
        value: 0.1,
        nudges: {Dimension.social: 0.25},
      ),
      QOption(
        direction: OrbDirection.right,
        label: 'Effervescent',
        image: Img.energetic,
        value: 0.9,
        nudges: {Dimension.social: 0.8, Dimension.energy: 0.8},
      ),
    ],
  ),
];
