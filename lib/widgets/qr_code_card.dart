import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/antique_theme.dart';

/// Carte affichant un QR Code stylisé avec le thème antique
class QrCodeCard extends StatelessWidget {
  final String url;
  final String title;
  final String subtitle;

  const QrCodeCard({
    super.key,
    required this.url,
    this.title = 'Visitez mon site',
    this.subtitle = 'Scannez pour découvrir mes autres œuvres',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AntiqueTheme.parchment,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AntiqueTheme.brass, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Titre
            Text(
              title,
              style: GoogleFonts.cinzel(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AntiqueTheme.inkSepia,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            // Sous-titre
            Text(
              subtitle,
              style: GoogleFonts.cormorant(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: AntiqueTheme.inkSepia.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // QR Code avec bordure décorative (style par défaut, couleurs personnalisées)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AntiqueTheme.brass, width: 1.5),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AntiqueTheme.inkSepia,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AntiqueTheme.inkSepia,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // URL affichée
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AntiqueTheme.brass.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AntiqueTheme.brass.withOpacity(0.3)),
              ),
              child: Text(
                url.replaceFirst('https://', '').replaceFirst('http://', ''),
                style: GoogleFonts.crimsonText(
                  fontSize: 13,
                  color: AntiqueTheme.inkSepia,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}