import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root application widget. Wires the theme and router; holds no logic.
class VybiaApp extends StatelessWidget {
  const VybiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vybia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: AppRouter.demo,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
