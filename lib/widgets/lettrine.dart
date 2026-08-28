import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/antique_theme.dart';

/// Initiale enluminée (lettrine) pour débuts de texte.
class Lettrine extends StatelessWidget {
  final String letter;
  final String paragraph;
  const Lettrine({super.key, required this.letter, required this.paragraph});

  @override
  Widget build(BuildContext context) {
    return RichText(text: TextSpan(children: [
      WidgetSpan(alignment: PlaceholderAlignment.top,
        child: Container(
          width: 44, height: 52, margin: const EdgeInsets.only(right: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AntiqueTheme.goldGradient,
            border: Border.all(color: AntiqueTheme.leatherWarm),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(letter, style: GoogleFonts.cinzel(fontSize: 32,
              fontWeight: FontWeight.w800, color: AntiqueTheme.inkBlack)),
        )),
      TextSpan(text: paragraph, style: AntiqueTheme.bodyText),
    ]));
  }
}