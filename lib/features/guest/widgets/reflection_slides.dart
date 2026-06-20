import '../data/assets.dart';
import '../model/dimension.dart';
import '../model/guest_profile.dart';
import 'reflection_transition.dart';

/// Build the exploration reflection slides from the just-captured [profile]:
/// the three dimensions we're most confident about, each shown as the closest
/// mood/atmosphere image with its human-readable French leaning. So the guest
/// literally SEES that their inputs were heard before the recommendations land.
List<ReflectionSlide> exploreReflectionSlides(GuestProfile profile) {
  final dims = Dimension.values
      .where((d) => profile.confidenceOf(d) > 0.05)
      .toList()
    ..sort((a, b) => profile.confidenceOf(b).compareTo(profile.confidenceOf(a)));

  final pick = dims.take(3).toList();
  // Cold start (no captured signal yet): a single neutral reassurance slide.
  if (pick.isEmpty) {
    return const [
      ReflectionSlide(image: Img.calm, label: 'On compose ton instant'),
    ];
  }
  return [
    for (final d in pick)
      ReflectionSlide(
        image: _imageFor(d, profile.valueOf(d)),
        label: '${d.labelFr} · ${profile.readingFor(d)}',
      ),
  ];
}

/// Map a dimension's leaning to the closest existing mood/atmosphere image.
String _imageFor(Dimension d, double v) {
  switch (d) {
    case Dimension.mood:
      return v > 0.66 ? Img.energetic : (v > 0.33 ? Img.curious : Img.calm);
    case Dimension.energy:
      return v > 0.6 ? Img.energetic : (v < 0.4 ? Img.calm : Img.curious);
    case Dimension.social:
      return v > 0.55 ? Img.social : Img.calm;
    case Dimension.novelty:
      return v > 0.55 ? Img.curious : Img.calm;
    case Dimension.vibe:
      return v > 0.6 ? Img.social : (v < 0.4 ? Img.calm : Img.curious);
    case Dimension.timing:
      return v > 0.6 ? Img.social : Img.curious;
    case Dimension.indoor:
      return v < 0.4 ? Img.curious : Img.calm;
    case Dimension.distance:
      return v > 0.6 ? Img.curious : Img.calm;
    case Dimension.budget:
      return Img.calm;
  }
}
