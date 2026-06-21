import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/engine/wellbeing_tagger.dart';
import 'package:vybia_v2/features/reco/model/activity.dart';
import 'package:vybia_v2/features/reco/model/wellbeing.dart';

Activity _byCategory(ActivityCategory c) =>
    kActivityCatalog.firstWhere((a) => a.category == c);

void main() {
  group('S11A — WellbeingTagger derivation', () {
    test('every catalog activity yields in-range wellbeing tags', () {
      for (final a in kActivityCatalog) {
        final w = WellbeingTagger.of(a);
        for (final v in [
          w.hedoniaEudaimonia,
          w.socialSupport,
          w.intrinsicAppeal,
          w.flexibility,
          w.happinessTrait,
        ]) {
          expect(v, inInclusiveRange(0.0, 1.0), reason: a.id);
        }
      }
    });

    test('cultural leisure reads more eudaimonic than nightlife', () {
      final culture = WellbeingTagger.of(_byCategory(ActivityCategory.culture));
      final nightlife =
          WellbeingTagger.of(_byCategory(ActivityCategory.nightlife));
      expect(culture.hedoniaEudaimonia,
          greaterThan(nightlife.hedoniaEudaimonia));
    });

    test('nightlife reads higher social-support than a quiet café', () {
      final nightlife =
          WellbeingTagger.of(_byCategory(ActivityCategory.nightlife));
      final cafe = WellbeingTagger.of(_byCategory(ActivityCategory.cafe));
      expect(nightlife.socialSupport, greaterThan(cafe.socialSupport));
    });

    test('a persisted override is preferred over derivation', () {
      const override = WellbeingTags(
        hedoniaEudaimonia: 0.91,
        socialSupport: 0.1,
        intrinsicAppeal: 0.2,
        flexibility: 0.3,
      );
      final base = _byCategory(ActivityCategory.nightlife);
      final tagged = Activity(
        id: base.id,
        titleFr: base.titleFr,
        category: base.category,
        tags: base.tags,
        motives: base.motives,
        budget: base.budget,
        indoor: base.indoor,
        descFr: base.descFr,
        lat: base.lat,
        lng: base.lng,
        image: base.image,
        wellbeing: override,
      );
      final w = WellbeingTagger.of(tagged);
      expect(w.hedoniaEudaimonia, 0.91);
      expect(w.socialSupport, 0.1);
    });

    test('wellbeing tags round-trip through JSON', () {
      const w = WellbeingTags(
        hedoniaEudaimonia: 0.42,
        socialSupport: 0.61,
        intrinsicAppeal: 0.73,
        flexibility: 0.28,
      );
      final back = WellbeingTags.tryFromJson(w.toJson())!;
      expect(back.hedoniaEudaimonia, closeTo(0.42, 1e-9));
      expect(back.socialSupport, closeTo(0.61, 1e-9));
      expect(back.intrinsicAppeal, closeTo(0.73, 1e-9));
      expect(back.flexibility, closeTo(0.28, 1e-9));
    });

    test('tryFromJson returns null without the essential axis', () {
      expect(WellbeingTags.tryFromJson(null), isNull);
      expect(WellbeingTags.tryFromJson({'socialSupport': 0.5}), isNull);
    });
  });
}
