import 'package:flutter/material.dart';

import 'core/theme/theme.dart';
import 'features/main/main_screen.dart';

class ProtzyApp extends StatelessWidget {
  const ProtzyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Protzy',
      theme: AppTheme.dark,
      home: const MainScreen(),
    );
  }
}