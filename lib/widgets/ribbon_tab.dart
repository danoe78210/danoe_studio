import 'package:flutter/material.dart';
import '../theme/antique_theme.dart';

/// Ruban marque-page (menu gauche) avec hover + accessibilité.
class RibbonTab extends StatefulWidget {
  final String label;
  final String? emoji;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  final double width;
  final double height;

  const RibbonTab({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.emoji,
    this.active = false,
    this.width = 170.0,
    this.height = 34.0,
  });

  @override
  State<RibbonTab> createState() => _RibbonTabState();
}

class _RibbonTabState extends State<RibbonTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Onglet ${widget.label}',
      selected: widget.active,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: widget.width,
            height: widget.height,
            transform: Matrix4.identity()
              ..translateByDouble(_hover ? 3.0 : 0.0, 0, 0, 1),
            child: CustomPaint(
              painter: _RibbonPainter(
                  color: widget.color, active: widget.active, hovered: _hover),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.emoji != null && widget.emoji!.isNotEmpty) ...[
                      Text(widget.emoji!, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                    ],
                    Text(widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: AntiqueTheme.labelRuban),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  final Color color;
  final bool active;
  final bool hovered;
  _RibbonPainter(
      {required this.color, required this.active, required this.hovered});

  @override
  void paint(Canvas c, Size s) {
    final n = s.height * 0.45;
    final path = Path()
      ..moveTo(s.width, 0)
      ..lineTo(0, 0)
      ..lineTo(n, s.height / 2)
      ..lineTo(0, s.height)
      ..lineTo(s.width, s.height)
      ..close();

    // Halo (lueur au survol) ou ombre
    c.drawPath(
        path,
        Paint()
          ..color = hovered
              ? AntiqueTheme.candleGlow.withValues(alpha: 0.40)
              : const Color(0x88000000)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, hovered ? 7 : 3));

    // Corps du ruban
    final g = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: active ? 1.0 : (hovered ? 0.95 : 0.82)),
          color.withValues(alpha: active ? 0.90 : (hovered ? 0.80 : 0.62)),
        ]);
    c.drawPath(
        path,
        Paint()
          ..shader = g.createShader(Rect.fromLTWH(0, 0, s.width, s.height)));

    // Liseré or
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = (active || hovered)
              ? AntiqueTheme.agedGold
              : const Color(0x66D9B44A));
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter old) =>
      old.color != color || old.active != active || old.hovered != hovered;
}
