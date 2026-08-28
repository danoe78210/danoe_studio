import 'package:flutter/material.dart';
import '../theme/antique_theme.dart';

/// Coins de page ouvragés (enluminures) dessinés en CustomPaint.
class OrnatePageCorners extends StatelessWidget {
  final Widget child;
  final Color color;
  const OrnatePageCorners({super.key, required this.child, this.color = AntiqueTheme.brass});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _CornersPainter(color), child: child);
  }
}

class _CornersPainter extends CustomPainter {
  final Color color;
  _CornersPainter(this.color);

  @override
  void paint(Canvas c, Size s) {
    final line = Paint()..color = color..strokeWidth = 1.6..style = PaintingStyle.stroke;
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    const inset = 10.0;

    _corner(c, Offset(inset, inset), 1, 1, line, fill);
    _corner(c, Offset(s.width - inset, inset), -1, 1, line, fill);
    _corner(c, Offset(inset, s.height - inset), 1, -1, line, fill);
    _corner(c, Offset(s.width - inset, s.height - inset), -1, -1, line, fill);
  }

  void _corner(Canvas c, Offset o, double dx, double dy, Paint line, Paint fill) {
    const L = 28.0;
    // L extérieur
    c.drawLine(o + Offset(dx * L, 0), o, line);
    c.drawLine(o, o + Offset(0, dy * L), line);
    // L intérieur
    final inner = o + Offset(dx * 6, dy * 6);
    c.drawLine(inner + Offset(dx * (L - 12), 0), inner, line);
    c.drawLine(inner, inner + Offset(0, dy * (L - 12)), line);
    // losange au coin
    final d = o + Offset(dx * 3, dy * 3);
    final diamond = Path()
      ..moveTo(d.dx, d.dy - 3)
      ..lineTo(d.dx + 3, d.dy)
      ..lineTo(d.dx, d.dy + 3)
      ..lineTo(d.dx - 3, d.dy)
      ..close();
    c.drawPath(diamond, fill);
  }

  @override
  bool shouldRepaint(covariant _CornersPainter old) => old.color != color;
}