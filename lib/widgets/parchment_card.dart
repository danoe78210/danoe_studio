import 'package:flutter/material.dart';

import '../theme/antique_theme.dart';

/// Carte « parchemin » réutilisable (pages, panneaux).
class ParchmentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const ParchmentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AntiqueTheme.parchmentGradient,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AntiqueTheme.leatherWarm, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
          const BoxShadow(
            color: Color(0x22000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
