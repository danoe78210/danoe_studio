import 'package:flutter/material.dart';
import 'theme/antique_theme.dart';
import 'ui/home_screen.dart';

void main(List<String> arguments) {
  final pageArgument = arguments
      .where((argument) => argument.startsWith('--demo-page='))
      .map((argument) => argument.substring('--demo-page='.length))
      .map(int.tryParse)
      .whereType<int>()
      .firstOrNull;

  runApp(DanoeStudioApp(
    captureMode: pageArgument != null,
    initialPage: pageArgument ?? 0,
  ));
}

class DanoeStudioApp extends StatelessWidget {
  const DanoeStudioApp(
      {super.key, this.captureMode = false, this.initialPage = 0});

  final bool captureMode;
  final int initialPage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Danoë Studio',
      debugShowCheckedModeBanner: false,
      theme: AntiqueTheme.theme,
      home: HomeScreen(captureMode: captureMode, initialPage: initialPage),
    );
  }
}
