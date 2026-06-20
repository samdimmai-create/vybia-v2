import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/guest/model/life_context.dart';
import 'package:vybia_v2/features/reco/content/content_provider.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/engine/leisure_motivation.dart';
import 'package:vybia_v2/features/reco/engine/recommendation_engine.dart';
import 'package:vybia_v2/features/reco/engine/reco_context.dart';
import 'package:vybia_v2/features/reco/model/activity.dart';

const _content = TemplatedContentProvider();
const _engine = RecommendationEngine(catalog: kActivityCatalog);
const _ctx = RecoContext(hourOfDay: 14, month: 6);

GuestProfile _profile() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.5);
  p.answer(Dimension.social, 0.6);
  p.answer(Dimension.energy, 0.5);
  return p;
}

Activity _culture() =>
    kActivityCatalog.firstWhere((a) => a.category == ActivityCategory.culture);

void main() {
  group('S9F — tailored "pourquoi"', () {
    test('every why is non-empty and ends as a sentence', () {
      final p = _profile();
      final lms = LeisureMotivation.weightsFor(p);
      for (final a in kActivityCatalog) {
        final why = _content.why(a, p, lms: lms, topDims: const [], context: _ctx);
        expect(why.trim(), isNotEmpty, reason: a.id);
        expect(why.endsWith('.'), isTrue, reason: a.id);
      }
    });

    test('the batch reads varied — whys do not all repeat verbatim', () {
      final recs = _engine.recommend(_profile(), context: _ctx);
      final whys = recs.map((r) => r.why).toSet();
      expect(whys.length, greaterThan(1),
          reason: 'a batch should not be the same sentence over and over');
    });

    test('an active life-context colours the why with its tone', () {
      final p = _profile()..setContext(LifeContext.budgetSerre, true);
      final lms = LeisureMotivation.weightsFor(p);
      final why = _content.why(kActivityCatalog.first, p,
          lms: lms, topDims: const [Dimension.energy], context: _ctx);
      expect(why, contains('léger pour le portefeuille'));
    });

    test('deterministic: identical input → identical why', () {
      final p = _profile();
      final lms = LeisureMotivation.weightsFor(p);
      final a = kActivityCatalog.first;
      final w1 = _content.why(a, p, lms: lms, topDims: const [Dimension.vibe]);
      final w2 = _content.why(a, p, lms: lms, topDims: const [Dimension.vibe]);
      expect(w1, w2);
    });
  });

  group('S9F — smart image pick', () {
    test('always returns a bundled asset path', () {
      final p = _profile();
      for (final a in kActivityCatalog) {
        final img = _content.imageFor(a, p);
        expect(img, startsWith('assets/images/'));
      }
    });

    test('the same culture venue gets a calmer image for a calm guest and a '
        'livelier one for a lively guest', () {
      final culture = _culture();
      final calm = GuestProfile()..answer(Dimension.vibe, 0.0);
      final lively = GuestProfile()..answer(Dimension.vibe, 1.0);
      final calmImg = _content.imageFor(culture, calm);
      final livelyImg = _content.imageFor(culture, lively);
      // Culture has several candidates ordered calm→lively, so the picks differ.
      expect(calmImg, isNot(livelyImg));
    });

    test('engine stamps the smart image onto each recommendation', () {
      final recs = _engine.recommend(_profile(), context: _ctx);
      for (final r in recs) {
        expect(r.image, startsWith('assets/images/'));
      }
    });
  });

  group('S9F — ContentProvider is an LLM-swappable seam', () {
    test('a custom provider overrides the engine copy + image', () {
      const engine = RecommendationEngine(
        catalog: kActivityCatalog,
        content: _FakeProvider(),
      );
      final recs = engine.recommend(_profile(), context: _ctx);
      expect(recs.first.why, 'FAKE');
      expect(recs.first.image, 'assets/images/places/cafe.jpg');
    });
  });
}

/// A stand-in for a future LLM provider — proves the engine takes any
/// [ContentProvider] without change.
class _FakeProvider implements ContentProvider {
  const _FakeProvider();

  @override
  String why(Activity a, GuestProfile profile,
          {required lms, required topDims, context}) =>
      'FAKE';

  @override
  String imageFor(Activity a, GuestProfile profile) =>
      'assets/images/places/cafe.jpg';
}
