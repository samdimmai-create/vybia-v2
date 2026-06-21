import 'package:flutter_test/flutter_test.dart';

import 'package:vybia_v2/core/config/api_config.dart';
import 'package:vybia_v2/features/reco/live/live_streaming_provider.dart';

/// S12A — secrets-safe config plumbing: keys come ONLY from --dart-define, and a
/// provider with no key degrades gracefully (no crash, reported "needs key").
void main() {
  group('ApiConfig', () {
    test('with no --dart-define every key is absent (graceful default)', () {
      // This suite runs WITHOUT any --dart-define, so every key resolves empty.
      expect(ApiConfig.geoapifyKey, isEmpty);
      expect(ApiConfig.foursquareKey, isEmpty);
      expect(ApiConfig.tmdbKey, isEmpty);
      expect(ApiConfig.ticketmasterKey, isEmpty);
      expect(ApiConfig.hasGeoapify, isFalse);
      expect(ApiConfig.hasFoursquare, isFalse);
      expect(ApiConfig.hasTmdb, isFalse);
      expect(ApiConfig.hasTicketmaster, isFalse);
    });

    test('exposes a per-source status for all four sources', () {
      final statuses = ApiConfig.statuses;
      expect(statuses, hasLength(4));
      expect(statuses.map((s) => s.source).toSet(), KeyedSource.values.toSet());
      // Status text never leaks a key value and reads clearly.
      for (final s in statuses) {
        expect(s.present, isFalse);
        expect(s.summary, contains('repli gracieux'));
      }
      // Build-stage vs live-stage classification is correct.
      expect(KeyedSource.geoapify.stage, KeyStage.build);
      expect(KeyedSource.foursquare.stage, KeyStage.build);
      expect(KeyedSource.tmdb.stage, KeyStage.live);
      expect(KeyedSource.ticketmaster.stage, KeyStage.live);
    });
  });

  test('TMDB provider reads its key from ApiConfig and is disabled when absent',
      () {
    // No define in this suite → provider is unconfigured but never throws.
    final p = LiveStreamingProvider();
    expect(p.isConfigured, ApiConfig.hasTmdb);
    expect(p.isConfigured, isFalse);
    expect(p.needsKeyNote, isNotNull);
  });
}
