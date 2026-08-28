import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/antique_theme.dart';

/// Séparateur ornemental « ─── ❦ ─── ».
class GothicDivider extends StatelessWidget {
  final String ornament;
  const GothicDivider({super.key, this.ornament = '❦'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AntiqueTheme.brass.withValues(alpha: 0.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            ornament,
            style: TextStyle(fontSize: 14, color: AntiqueTheme.brass),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AntiqueTheme.brass.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

/// Titre de section : Cinzel + séparateur gothique.
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.cinzel(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AntiqueTheme.inkSepia,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        const GothicDivider(),
        const SizedBox(height: 16),
      ],
    );
  }
}
