import 'package:flutter/material.dart';

import 'app.dart';
import 'core/geo/geo.dart';
import 'core/persistence/app_store.dart';
import 'features/guest/model/dimension.dart';
import 'features/guest/model/guest_profile.dart';
import 'features/plans/model/plan.dart';
import 'features/reco/data/osm_place_repository.dart';
import 'features/reco/db/activity_repository.dart';
import 'features/reco/db/preference_taxonomy.dart';
import 'shared/edge_palette.dart';

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
  // S10: load OUR multi-source database (all kinds) + the preference taxonomy.
  // The engine prefers this catalog over the thin OSM snapshot; both fall back
  // to the seed catalog, so a missing asset is never fatal.
  try {
    await ActivityRepository.load();
  } catch (_) {/* keep the OSM/seed fallback */}
  try {
    await PreferenceTaxonomy.load();
  } catch (_) {/* labels fall back to ids */}
  // S10E: layer the persisted write-back overlay (enriched/upserted records) over
  // the bundled catalog, and wire the persist hook so future enrichments survive
  // a relaunch.
  ActivityRepository.hydrateOverlay(store.readOverlay());
  ActivityRepository.persist = store.saveOverlay;
  // S15.0: Palette A is the permanent default; hydrate the persisted selection
  // (kept across full page reloads, not just the session) and save every flip.
  final savedPalette = store.readPaletteIndex();
  if (savedPalette != null) {
    activeEdgePaletteIndex.value = savedPalette % kEdgePalettes.length;
  }
  activeEdgePaletteIndex.addListener(
    () => store.savePaletteIndex(activeEdgePaletteIndex.value),
  );
  // Debug-only persistence proof: with `--dart-define=VYBIA_SEED_DEMO=true` we
  // write an adjusted taste + a future plan + a granted location THROUGH the
  // real store, then a normal relaunch reads them back (s7_09_after_relaunch).
  if (const bool.fromEnvironment('VYBIA_SEED_DEMO')) {
    await _seedDemoData(store);
  }
  runApp(VybiaApp(store: store));
}

Future<void> _seedDemoData(AppStore store) async {
  // Adjust a taste.
  final profile = GuestProfile();
  if (store.readProfileJson() case final saved?) profile.restore(saved);
  profile.answer(Dimension.mood, 0.7);
  profile.answer(Dimension.social, 0.8);
  await store.saveProfile(profile);

  // Grant a location.
  await store.saveGeo(const GeoResult(45.5230, -73.5810, GeoStatus.granted));

  // Create a future plan backed by a real place (falls back to none if empty).
  if (OsmPlaceRepository.activities.isNotEmpty) {
    final activity = OsmPlaceRepository.activities.first;
    final when = DateTime.now().add(const Duration(days: 2, hours: 3));
    final plan = Plan(
      id: 'plan_0',
      activity: activity,
      moment: PlanMoment.weekend,
      companions: PlanCompanions.friends,
      when: when,
    );
    final existing = store.readPlans();
    await store.savePlans([...existing, plan]);
  }
}
