import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/antique_theme.dart';

/// Tourne une page de façon réaliste : pli courbé + verso + ombre portée.
class PageCurl extends StatelessWidget {
  final double t;          // progression 0..1
  final Widget front;      // contenu de la page qui tourne
  const PageCurl({super.key, required this.t, required this.front});

  @override
  Widget build(BuildContext context) {
    final p = t.clamp(0.0, 1.0);
    return LayoutBuilder(builder: (c, cons) {
      final W = cons.maxWidth, H = cons.maxHeight;
      final fx = W * (1 - p);                          // ligne de pli
      final k = math.sin(p * math.pi) * W * 0.18;      // bombement du pli
      final x0 = (2 * fx - W).clamp(0.0, W);           // bord libre du rabat
      return Stack(children: [
        // partie encore plate de la page qui tourne
        ClipPath(clipper: _PathClipper(_foldPath(fx, k, H)), child: front),
        // ombre portée + rabat (verso)
        CustomPaint(size: Size(W, H),
            painter: _CurlPainter(fx: fx, x0: x0, k: k, H: H)),
      ]);
    });
  }

  Path _foldPath(double fx, double k, double H) => Path()
    ..moveTo(0, 0)
    ..lineTo(fx, 0)
    ..quadraticBezierTo(fx + k, H / 2, fx, H)
    ..lineTo(0, H)
    ..close();
}

class _PathClipper extends CustomClipper<Path> {
  final Path path;
  _PathClipper(this.path);
  @override
  Path getClip(Size s) => path;
  @override
  bool shouldReclip(covariant _PathClipper old) => true;
}

class _CurlPainter extends CustomPainter {
  final double fx, x0, k, H;
  _CurlPainter({required this.fx, required this.x0, required this.k, required this.H});

  @override
  void paint(Canvas c, Size s) {
    // Ombre portée sous le pli (sur la page révélée)
    final shadow = Path()
      ..moveTo(fx, 0)
      ..quadraticBezierTo(fx + k, H / 2, fx, H)
      ..lineTo(fx - 18, H)
      ..quadraticBezierTo(fx + k - 18, H / 2, fx - 18, 0)
      ..close();
    c.drawPath(shadow, Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // Rabat = verso de la page (parchemin) si le pli a avancé
    if (x0 < fx) {
      final flap = Path()
        ..moveTo(fx, 0)
        ..quadraticBezierTo(fx + k, H / 2, fx, H)
        ..lineTo(x0, H)
        ..quadraticBezierTo(x0 + k, H / 2, x0, 0)
        ..close();
      final g = LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [
        AntiqueTheme.parchment,
        AntiqueTheme.parchmentMid,
        AntiqueTheme.parchmentDark,
      ]);
      c.drawPath(flap, Paint()..shader = g.createShader(Rect.fromLTRB(x0, 0, fx, H)));
      // liseré lumineux le long du pli
      final fold = Path()
        ..moveTo(fx, 0)
        ..quadraticBezierTo(fx + k, H / 2, fx, H);
      c.drawPath(fold, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _CurlPainter old) => true;
}