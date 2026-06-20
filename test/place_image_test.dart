import 'package:flutter_test/flutter_test.dart';
import 'package:vybia_v2/features/guest/data/assets.dart';
import 'package:vybia_v2/features/reco/data/place_category_mapping.dart';
import 'package:vybia_v2/features/reco/model/place.dart';

/// S8C: every real place must show a CATEGORY-ACCURATE image — a café shows a
/// café, a theatre shows a theatre — never a generic/mismatched reuse.
void main() {
  Place place(PlaceCategory c) => Place(
        id: 'x',
        name: 'Test',
        lat: 45.5,
        lng: -73.6,
        category: c,
      );

  const expected = {
    PlaceCategory.cafe: Img.cafe,
    PlaceCategory.restaurant: Img.restaurant,
    PlaceCategory.bar: Img.bar,
    PlaceCategory.cinema: Img.cinema,
    PlaceCategory.theatre: Img.theatre,
    PlaceCategory.museum: Img.museum,
    PlaceCategory.gallery: Img.gallery,
    PlaceCategory.viewpoint: Img.viewpoint,
    PlaceCategory.park: Img.park,
    PlaceCategory.garden: Img.garden,
    PlaceCategory.market: Img.market,
    PlaceCategory.sports: Img.sports,
  };

  test('each place category maps to its own accurate image', () {
    for (final entry in expected.entries) {
      final activity = activityFromPlace(place(entry.key));
      expect(activity.image, entry.value,
          reason: '${entry.key.name} should use ${entry.value}');
    }
  });

  test('every place category has a distinct image (no reuse across the 12)', () {
    final images = expected.values.toSet();
    expect(images.length, expected.length);
  });

  test('every category profile points at a places/ asset', () {
    for (final c in PlaceCategory.values) {
      final img = activityFromPlace(place(c)).image;
      expect(img.startsWith('assets/images/places/'), isTrue,
          reason: '${c.name} image should be a category asset');
    }
  });
}
