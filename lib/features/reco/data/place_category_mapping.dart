import '../../guest/data/assets.dart';
import '../../guest/model/dimension.dart';
import '../model/activity.dart';
import '../model/motive.dart';
import '../model/place.dart';

/// The documented mapping table from a real OSM [PlaceCategory] to the engine's
/// eight taste axes (+ motives, budget, indoor, season, illustrative image and
/// the broad [ActivityCategory] used for diversification).
///
/// Axis polarity matches the guest profile, so a match is `1 - |profile − tag|`:
///   energy   0 calm     → 1 lively
///   social   0 solo     → 1 group
///   novelty  0 sure-bet → 1 new
///   distance 0 nearby   → 1 far   (a neutral 0.5 here; the real haversine
///                                  distance is folded in at runtime — S7C)
///   indoor   0 outdoor  → 1 indoor
///   timing   0 daytime  → 1 evening
///   budget   0 cheap    → 1 splurge
///   vibe     0 intimate → 1 effervescent
class CategoryProfile {
  const CategoryProfile({
    required this.tags,
    required this.motives,
    required this.budget,
    required this.indoor,
    required this.image,
    required this.activityCategory,
    this.winterFriendly = true,
  });

  final Map<Dimension, double> tags;
  final MotiveAffinity motives;
  final int budget; // 0 free … 3 splurge
  final bool indoor;
  final bool winterFriendly;
  final String image;
  final ActivityCategory activityCategory;
}

/// The mapping table. One curated profile per OSM category.
const Map<PlaceCategory, CategoryProfile> kPlaceCategoryProfiles = {
  PlaceCategory.cafe: CategoryProfile(
    tags: {
      Dimension.energy: 0.25,
      Dimension.social: 0.45,
      Dimension.novelty: 0.3,
      Dimension.distance: 0.5,
      Dimension.indoor: 0.85,
      Dimension.timing: 0.3,
      Dimension.budget: 0.25,
      Dimension.vibe: 0.35,
    },
    motives: (hedonic: 0.45, relaxation: 0.8, eudaimonic: 0.25),
    budget: 1,
    indoor: true,
    image: Img.cafe,
    activityCategory: ActivityCategory.cafe,
  ),
  PlaceCategory.restaurant: CategoryProfile(
    tags: {
      Dimension.energy: 0.4,
      Dimension.social: 0.7,
      Dimension.novelty: 0.5,
      Dimension.distance: 0.5,
      Dimension.indoor: 0.9,
      Dimension.timing: 0.8,
      Dimension.budget: 0.6,
      Dimension.vibe: 0.55,
    },
    motives: (hedonic: 0.8, relaxation: 0.4, eudaimonic: 0.4),
    budget: 2,
    indoor: true,
    image: Img.social,
    activityCategory: ActivityCategory.food,
  ),
  PlaceCategory.bar: CategoryProfile(
    tags: {
      Dimension.energy: 0.6,
      Dimension.social: 0.85,
      Dimension.novelty: 0.4,
      Dimension.distance: 0.5,
      Dimension.indoor: 0.8,
      Dimension.timing: 0.85,
      Dimension.budget: 0.45,
      Dimension.vibe: 0.8,
    },
    motives: (hedonic: 0.85, relaxation: 0.4, eudaimonic: 0.2),
    budget: 2,
    indoor: true,
    image: Img.rooftop,
    activityCategory: ActivityCategory.nightlife,
  ),
  PlaceCategory.cinema: CategoryProfile(
    tags: {
      Dimension.energy: 0.3,
      Dimension.social: 0.4,
      Dimension.novelty: 0.5,
      Dimension.distance: 0.5,
      Dimension.indoor: 0.95,
      Dimension.timing: 0.8,
      Dimension.budget: 0.35,
      Dimension.vibe: 0.3,
    },
    motives: (hedonic: 0.55, relaxation: 0.55, eudaimonic: 0.6),
    budget: 1,
    indoor: true,
    image: Img.cinema,
    activityCategory: ActivityCategory.culture,
  ),
  PlaceCategory.theatre: CategoryProfile(
    tags: {
      Dimension.energy: 0.4,
      Dimension.social: 0.55,
      Dimension.novelty: 0.6,
      Dimension.distance: 0.5,
      Dimension.indoor: 0.9,
      Dimension.timing: 0.85,
      Dimension.budget: 0.55,
      Dimension.vibe: 0.5,
    },
    motives: (hedonic: 0.6, relaxation: 0.45, eudaimonic: 0.65),
    budget: 2,
    indoor: true,
    image: Img.cinema,
    activityCategory: ActivityCategory.culture,
  ),
  PlaceCategory.museum: CategoryProfile(
    tags: {
      Dimension.energy: 0.3,
      Dimension.social: 0.45,
      Dimension.novelty: 0.6,
      Dimension.distance: 0.5,
      Dimension.indoor: 0.95,
      Dimension.timing: 0.35,
      Dimension.budget: 0.4,
      Dimension.vibe: 0.35,
    },
    motives: (hedonic: 0.4, relaxation: 0.5, eudaimonic: 0.9),
    budget: 2,
    indoor: true,
    image: Img.curious,
    activityCategory: ActivityCategory.culture,
  ),
  PlaceCategory.gallery: CategoryProfile(
    tags: {
      Dimension.energy: 0.3,
      Dimension.social: 0.4,
      Dimension.novelty: 0.7,
      Dimension.distance: 0.5,
      Dimension.indoor: 0.9,
      Dimension.timing: 0.4,
      Dimension.budget: 0.25,
      Dimension.vibe: 0.35,
    },
    motives: (hedonic: 0.45, relaxation: 0.5, eudaimonic: 0.85),
    budget: 1,
    indoor: true,
    image: Img.curious,
    activityCategory: ActivityCategory.creative,
  ),
  PlaceCategory.viewpoint: CategoryProfile(
    tags: {
      Dimension.energy: 0.3,
      Dimension.social: 0.35,
      Dimension.novelty: 0.45,
      Dimension.distance: 0.5,
      Dimension.indoor: 0.0,
      Dimension.timing: 0.7,
      Dimension.budget: 0.0,
      Dimension.vibe: 0.3,
    },
    motives: (hedonic: 0.4, relaxation: 0.8, eudaimonic: 0.5),
    budget: 0,
    indoor: false,
    image: Img.walkNight,
    activityCategory: ActivityCategory.nature,
  ),
  PlaceCategory.park: CategoryProfile(
    tags: {
      Dimension.energy: 0.45,
      Dimension.social: 0.4,
      Dimension.novelty: 0.35,
      Dimension.distance: 0.5,
      Dimension.indoor: 0.05,
      Dimension.timing: 0.35,
      Dimension.budget: 0.0,
      Dimension.vibe: 0.4,
    },
    motives: (hedonic: 0.45, relaxation: 0.75, eudaimonic: 0.45),
    budget: 0,
    indoor: false,
    winterFriendly: false,
    image: Img.energetic,
    activityCategory: ActivityCategory.nature,
  ),
  PlaceCategory.garden: CategoryProfile(
    tags: {
      Dimension.energy: 0.35,
      Dimension.social: 0.4,
      Dimension.novelty: 0.55,
      Dimension.distance: 0.5,
      Dimension.indoor: 0.25,
      Dimension.timing: 0.25,
      Dimension.budget: 0.3,
      Dimension.vibe: 0.3,
    },
    motives: (hedonic: 0.45, relaxation: 0.85, eudaimonic: 0.6),
    budget: 1,
    indoor: false,
    winterFriendly: false,
    image: Img.rooftop,
    activityCategory: ActivityCategory.nature,
  ),
  PlaceCategory.market: CategoryProfile(
    tags: {
      Dimension.energy: 0.5,
      Dimension.social: 0.6,
      Dimension.novelty: 0.55,
      Dimension.distance: 0.5,
      Dimension.indoor: 0.3,
      Dimension.timing: 0.2,
      Dimension.budget: 0.3,
      Dimension.vibe: 0.6,
    },
    motives: (hedonic: 0.6, relaxation: 0.45, eudaimonic: 0.5),
    budget: 1,
    indoor: false,
    winterFriendly: false,
    image: Img.curious,
    activityCategory: ActivityCategory.food,
  ),
  PlaceCategory.sports: CategoryProfile(
    tags: {
      Dimension.energy: 0.85,
      Dimension.social: 0.55,
      Dimension.novelty: 0.5,
      Dimension.distance: 0.5,
      Dimension.indoor: 0.7,
      Dimension.timing: 0.5,
      Dimension.budget: 0.4,
      Dimension.vibe: 0.6,
    },
    motives: (hedonic: 0.7, relaxation: 0.3, eudaimonic: 0.65),
    budget: 2,
    indoor: true,
    image: Img.energetic,
    activityCategory: ActivityCategory.active,
  ),
};

/// French label for a category, used in the "pourquoi" and detail copy.
String placeCategoryLabelFr(PlaceCategory c) {
  switch (c) {
    case PlaceCategory.cafe:
      return 'Café';
    case PlaceCategory.restaurant:
      return 'Restaurant';
    case PlaceCategory.bar:
      return 'Bar';
    case PlaceCategory.cinema:
      return 'Cinéma';
    case PlaceCategory.theatre:
      return 'Théâtre';
    case PlaceCategory.museum:
      return 'Musée';
    case PlaceCategory.gallery:
      return 'Galerie';
    case PlaceCategory.viewpoint:
      return 'Belvédère';
    case PlaceCategory.park:
      return 'Parc';
    case PlaceCategory.garden:
      return 'Jardin';
    case PlaceCategory.market:
      return 'Marché';
    case PlaceCategory.sports:
      return 'Sport & loisir';
  }
}

/// One-line French description template per category, woven with the real place
/// name + neighbourhood so every recommendation reads like a curated proposal.
String describePlace(Place p) {
  final hood = p.neighbourhood != null ? ' — ${p.neighbourhood}' : '';
  switch (p.category) {
    case PlaceCategory.cafe:
      return 'Café à découvrir$hood. Une pause douce, un café soigné, le temps qui ralentit.';
    case PlaceCategory.restaurant:
      return 'Une table où s’attabler$hood. De bons plats et une soirée qui s’étire.';
    case PlaceCategory.bar:
      return 'Un bar pour la soirée$hood. Un verre, l’ambiance, la ville qui s’allume.';
    case PlaceCategory.cinema:
      return 'Une séance de cinéma$hood. La lumière baisse, on se laisse emporter.';
    case PlaceCategory.theatre:
      return 'Une scène vivante$hood. Le genre de soirée qui sort de l’ordinaire.';
    case PlaceCategory.museum:
      return 'Un musée à explorer$hood. Des œuvres qui arrêtent le temps.';
    case PlaceCategory.gallery:
      return 'Une galerie d’art$hood. À hauteur d’œil, le regard qui s’ouvre.';
    case PlaceCategory.viewpoint:
      return 'Un belvédère$hood. La ville en contrebas, le ciel grand ouvert.';
    case PlaceCategory.park:
      return 'Un parc à arpenter$hood. De l’air, du vert, le pas qui se relâche.';
    case PlaceCategory.garden:
      return 'Un jardin tranquille$hood. Des allées calmes au cœur de la ville.';
    case PlaceCategory.market:
      return 'Un marché à flâner$hood. On goûte, on découvre, on repart les bras pleins.';
    case PlaceCategory.sports:
      return 'Du mouvement$hood. Le corps qui bouge, la tête qui se vide.';
  }
}

/// Build an engine [Activity] backed by a real [Place] using the mapping table.
Activity activityFromPlace(Place p) {
  final profile = kPlaceCategoryProfiles[p.category]!;
  return Activity(
    id: p.id,
    titleFr: p.name,
    category: profile.activityCategory,
    tags: profile.tags,
    motives: profile.motives,
    budget: profile.budget,
    indoor: profile.indoor,
    winterFriendly: profile.winterFriendly,
    descFr: describePlace(p),
    lat: p.lat,
    lng: p.lng,
    image: profile.image,
  );
}
