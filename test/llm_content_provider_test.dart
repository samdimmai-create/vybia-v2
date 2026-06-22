import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:vybia_v2/features/guest/model/dimension.dart';
import 'package:vybia_v2/features/guest/model/guest_profile.dart';
import 'package:vybia_v2/features/reco/content/content_provider.dart';
import 'package:vybia_v2/features/reco/content/llm_client.dart';
import 'package:vybia_v2/features/reco/content/llm_content_provider.dart';
import 'package:vybia_v2/features/reco/data/activity_catalog.dart';
import 'package:vybia_v2/features/reco/engine/leisure_motivation.dart';
import 'package:vybia_v2/features/reco/engine/recommendation_engine.dart';
import 'package:vybia_v2/features/reco/engine/reco_context.dart';
import 'package:vybia_v2/features/reco/model/recommendation.dart';

const _engine = RecommendationEngine(catalog: kActivityCatalog);
const _ctx = RecoContext(hourOfDay: 14, month: 6);

GuestProfile _profile() {
  final p = GuestProfile();
  p.answer(Dimension.mood, 0.5);
  p.answer(Dimension.social, 0.6);
  p.answer(Dimension.energy, 0.5);
  return p;
}

Recommendation _rec() => _engine.recommend(_profile(), context: _ctx).first;

void main() {
  group('S15B — LlmClient configuration by PROXY_URL', () {
    test('an empty proxy URL is "not configured" and never calls out', () async {
      final c = LlmClient(proxyUrl: '');
      expect(c.configured, isFalse);
      expect(await c.generate(system: 's', task: 't'), isNull);
    });

    test('a non-empty proxy URL is configured', () {
      expect(LlmClient(proxyUrl: 'https://proxy.example').configured, isTrue);
    });
  });

  group('S15C — provider selection', () {
    test('appContentProvider() is the templated provider when no PROXY_URL is '
        'baked in (the test build)', () {
      // No --dart-define=PROXY_URL in the test env → deterministic provider.
      expect(isLlmConfigured, isFalse);
      expect(appContentProvider(), isA<TemplatedContentProvider>());
    });
  });

  group('S15B — LlmContentProvider falls back to templated', () {
    test('no proxy configured → exact deterministic copy on every surface',
        () async {
      final prov = LlmContentProvider(client: LlmClient(proxyUrl: ''));
      expect(prov.active, isFalse);

      final rec = _rec();
      expect(
          await prov.generateWhy(rec, _profile(), context: _ctx), rec.why);
      expect(await prov.generateQuestionPrompt('Quel rythme te tente ?'),
          'Quel rythme te tente ?');
      expect(await prov.generateReaction(liked: true, activityTitle: 'X'),
          'Noté — on creuse ça.');
      expect(await prov.generateReaction(liked: false, activityTitle: 'X'),
          'Compris, on passe.');
    });

    test('proxy returns a non-200 → falls back to the deterministic why',
        () async {
      final mock = MockClient((req) async => http.Response('nope', 500));
      final prov =
          LlmContentProvider(client: LlmClient(proxyUrl: 'https://x', httpClient: mock));
      expect(prov.active, isTrue);
      final rec = _rec();
      expect(await prov.generateWhy(rec, _profile(), context: _ctx), rec.why);
    });

    test('proxy throws (timeout/network) → falls back to the question prompt',
        () async {
      final mock = MockClient((req) async => throw Exception('boom'));
      final prov =
          LlmContentProvider(client: LlmClient(proxyUrl: 'https://x', httpClient: mock));
      expect(await prov.generateQuestionPrompt('Solo ou entouré ?'),
          'Solo ou entouré ?');
    });

    test('proxy returns empty text → falls back deterministically', () async {
      final mock = MockClient((req) async =>
          http.Response(jsonEncode({'text': '   '}), 200));
      final prov =
          LlmContentProvider(client: LlmClient(proxyUrl: 'https://x', httpClient: mock));
      expect(await prov.generateReaction(liked: false, activityTitle: 'X'),
          'Compris, on passe.');
    });
  });

  group('S15B — LlmContentProvider voices the engine when the proxy answers', () {
    test('a 200 text reply is used for the why, with quotes stripped', () async {
      final mock = MockClient((req) async =>
          http.Response(jsonEncode({'text': '« Une vraie échappée pour ce soir. »'}), 200));
      final prov =
          LlmContentProvider(client: LlmClient(proxyUrl: 'https://x', httpClient: mock));
      final why = await prov.generateWhy(_rec(), _profile(), context: _ctx);
      expect(why, 'Une vraie échappée pour ce soir.');
    });

    test('the synchronous ContentProvider surface stays deterministic', () {
      final prov = LlmContentProvider(client: LlmClient(proxyUrl: ''));
      final p = _profile();
      final lms = LeisureMotivation.weightsFor(p);
      final why = prov.why(kActivityCatalog.first, p,
          lms: lms, topDims: const [], context: _ctx);
      expect(why.trim(), isNotEmpty);
      expect(prov.imageFor(kActivityCatalog.first, p), startsWith('assets/images/'));
    });
  });
}
