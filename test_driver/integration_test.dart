import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for the visible simulator walk. Saves every screenshot the test
/// requests under ./screenshots/ so the founder can review the S4 flow.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final dir = Directory('screenshots')..createSync(recursive: true);
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
      return true;
    },
  );
}
