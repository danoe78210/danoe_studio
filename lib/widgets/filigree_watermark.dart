import 'package:flutter/material.dart';
import '../theme/antique_theme.dart';

/// Filigrane discret en arrière-plan de page.
class FiligreeWatermark extends StatelessWidget {
  final String glyph;
  final double size;
  final double opacity;
  const FiligreeWatermark(
      {super.key, this.glyph = '❦', this.size = 180, this.opacity = 0.06});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Text(glyph,
            style: TextStyle(
                fontSize: size,
                color: AntiqueTheme.inkSepia.withValues(alpha: opacity))),
      ),
    );
  }
}
