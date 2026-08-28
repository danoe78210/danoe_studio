import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/antique_theme.dart';

/// Bouton « laiton / fer forgé » du thème bibliothèque.
/// [onParchment] = encre sépia sur fond clair ; sinon or sur cuir sombre.
class AntiqueButton extends StatefulWidget {
  final String label;
  final String? emoji;
  final VoidCallback onTap;
  final bool primary;
  final bool onParchment;

  const AntiqueButton({
    super.key,
    required this.label,
    this.emoji,
    required this.onTap,
    this.primary = false,
    this.onParchment = false,
  });

  @override
  State<AntiqueButton> createState() => _AntiqueButtonState();
}

class _AntiqueButtonState extends State<AntiqueButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final fg = widget.onParchment
        ? AntiqueTheme.inkSepia
        : AntiqueTheme.agedGold;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.onParchment
                ? (_hover ? const Color(0x14B8860B) : const Color(0x0F000000))
                : (_hover
                      ? AntiqueTheme.leatherDeep
                      : AntiqueTheme.leatherDark),
            gradient: widget.primary ? AntiqueTheme.leatherGradient : null,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AntiqueTheme.brass, width: 1.2),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: AntiqueTheme.candleGlow.withValues(alpha: 0.25),
                      blurRadius: 10,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              if (widget.emoji != null) ...[
                Text(widget.emoji!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.cinzel(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: fg,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
