import 'package:flutter/material.dart';
import 'theme/antique_theme.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const DanoeStudioApp());
}

class DanoeStudioApp extends StatelessWidget {
  const DanoeStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Danoë Studio',
      debugShowCheckedModeBanner: false,
      theme: AntiqueTheme.theme,
      home: const HomeScreen(),
    );
  }
}
