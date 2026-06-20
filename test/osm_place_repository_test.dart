import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/reco/data/osm_place_repository.dart';
import 'package:vybia_v2/features/reco/data/place_category_mapping.dart';
import 'package:vybia_v2/features/reco/model/place.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ingest parses places, skips malformed rows, builds activities', () {
    const json = '''
    {"count":3,"places":[
      {"id":"osm_1","name":"Café Test","lat":45.52,"lng":-73.6,"category":"cafe","neighbourhood":"Mile End"},
      {"id":"osm_2","name":"Parc Test","lat":45.5,"lng":-73.57,"category":"park"},
      {"id":"bad","name":"No coords","category":"bar"}
    ]}''';
    OsmPlaceRepository.ingest(json);

    expect(OsmPlaceRepository.isLoaded, isTrue);
    expect(OsmPlaceRepository.places.length, 2); // malformed row dropped
    expect(OsmPlaceRepository.activities.length, 2);

    final cafe = OsmPlaceRepository.activityById('osm_1')!;
    expect(cafe.titleFr, 'Café Test');
    // cafe → indoor high, evening-ish low, low budget (mapping table).
    expect(cafe.tag(Dimension.indoor), greaterThan(0.7));
    expect(cafe.indoor, isTrue);
    expect(cafe.descFr, contains('Mile End'));

    final park = OsmPlaceRepository.activityById('osm_2')!;
    expect(park.indoor, isFalse);
    expect(park.tag(Dimension.indoor), lessThan(0.2)); // outdoor
  });

  test('every PlaceCategory has a mapping profile', () {
    for (final c in PlaceCategory.values) {
      expect(kPlaceCategoryProfiles[c], isNotNull, reason: '$c missing profile');
    }
  });

  testWidgets('bundled montreal_places.json asset loads and maps cleanly',
      (tester) async {
    await OsmPlaceRepository.load(bundle: rootBundle);
    expect(OsmPlaceRepository.isLoaded, isTrue);
    // The curated snapshot is a few hundred real places.
    expect(OsmPlaceRepository.places.length, greaterThan(100));
    // Every activity carries real coordinates and a non-empty title + image.
    for (final a in OsmPlaceRepository.activities) {
      expect(a.titleFr.isNotEmpty, isTrue);
      expect(a.image.isNotEmpty, isTrue);
      expect(a.lat, inInclusiveRange(45.3, 45.8));
      expect(a.lng, inInclusiveRange(-74.1, -73.3));
    }
  });
}
