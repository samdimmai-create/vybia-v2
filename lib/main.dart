import 'package:flutter/material.dart';

import 'app.dart';
import 'core/persistence/app_store.dart';
import 'features/reco/data/osm_place_repository.dart';

Future<void> main() async {
  // Hydrate the local store BEFORE first paint so the guest's persisted profile,
  // mood and plans are present on the very first frame (no flash of defaults).
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.open();
  // Load the bundled OSM Montréal snapshot so recommendations are backed by real
  // places from the first frame. Tolerant: if the asset is missing the reco loop
  // falls back to the hand-authored seed catalog.
  try {
    await OsmPlaceRepository.load();
  } catch (_) {
    // Non-fatal — keep the seed catalog as the fallback.
  }
  runApp(VybiaApp(store: store));
}
