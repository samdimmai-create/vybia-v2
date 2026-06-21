import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vybia_v2/features/reco/db/activity_repository.dart';

/// S10.1C — the static catalog must carry real per-activity images, and every
/// `assets/images/catalog/…` reference must point at a file that actually exists
/// (so a bundled image never 404s at runtime).
void main() {
  setUpAll(() {
    final raw = File('assets/data/vybia_catalog.json').readAsStringSync();
    ActivityRepository.clearOverlay();
    ActivityRepository.ingest(raw);
  });

  test('a meaningful share of static entries carry a real per-activity image',
      () {
    final staticEntries = ActivityRepository.staticEntries;
    final withReal = staticEntries
        .where((e) => e.imageRef.startsWith('assets/images/catalog/'))
        .length;
    // S10.1C lifted this well past the S10 baseline (11) via geo-verified
    // Commons reconciliation; keep a floor so a future regression is caught.
    expect(withReal, greaterThanOrEqualTo(25),
        reason: 'only $withReal/${staticEntries.length} static entries '
            'have a real per-activity image');
  });

  test('every per-activity image reference exists on disk', () {
    final missing = <String>[];
    for (final e in ActivityRepository.entries) {
      if (e.imageRef.startsWith('assets/images/catalog/')) {
        if (!File(e.imageRef).existsSync()) missing.add('${e.id}: ${e.imageRef}');
      }
    }
    expect(missing, isEmpty, reason: 'missing image files: $missing');
  });
}
