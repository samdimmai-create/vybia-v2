import 'package:flutter/material.dart';

import 'app.dart';
import 'core/persistence/app_store.dart';

Future<void> main() async {
  // Hydrate the local store BEFORE first paint so the guest's persisted profile,
  // mood and plans are present on the very first frame (no flash of defaults).
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.open();
  runApp(VybiaApp(store: store));
}
