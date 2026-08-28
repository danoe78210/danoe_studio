import 'package:flutter/material.dart';
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101322),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3D6BFF),
          secondary: Color(0xFFE0B458),
          surface: Color(0xFF171B2E),
          error: Color(0xFFFF6B6B),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}