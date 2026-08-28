import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // ← classe Ticker

/// Effet K2000 (Knight Rider) : barre de LED rouges avec traînée
/// persistante et halo subtil. Visible pendant les traitements.
class K2000Scanner extends StatefulWidget {
  final bool active;
  final double height;
  final int nombreLed;
  final double vitesse;      // fraction de la barre par seconde
  final double persistance;  // décroissance de la traînée

  const K2000Scanner({
    super.key,
    required this.active,
    this.height = 34,
    this.nombreLed = 60,
    this.vitesse = 0.55,
    this.persistance = 2.2,
  });

  @override
  State<K2000Scanner> createState() => _K2000ScannerState();
}

class _K2000ScannerState extends State<K2000Scanner>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _position = 0.0;
  double _sens = 1.0;
  double _lastSeconds = 0.0;
  List<double> _charges = [];

  @override
  void initState() {
    super.initState();
    _charges = List.filled(widget.nombreLed, 0.0);
    _ticker = createTicker(_onTick);
    if (widget.active) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant K2000Scanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ticker.isActive) {
      _position = 0.0;
      _sens = 1.0;
      _lastSeconds = 0.0;
      _charges = List.filled(widget.nombreLed, 0.0);
      _ticker.start();
    } else if (!widget.active && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMilliseconds / 1000.0;
    final dt = _lastSeconds == 0 ? 0.016 : (t - _lastSeconds).clamp(0.0, 0.1);
    _lastSeconds = t;

    // Déplacement avec rebond
    _position += widget.vitesse * dt * _sens;
    if (_position >= 1.0) {
      _position = 1.0;
      _sens = -1.0;
    } else if (_position <= 0.0) {
      _position = 0.0;
      _sens = 1.0;
    }

    // Charges des LED (persistance)
    final decay = math.exp(-widget.persistance * dt);
    final n = _charges.length;
    for (var i = 0; i < n; i++) {
      final ledX = (i + 0.5) / n;
      if ((ledX - _position).abs() < 0.8 / n) {
        _charges[i] = 1.0;
      } else {
        _charges[i] *= decay;
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _K2000Painter(charges: _charges),
      ),
    );
  }
}

class _K2000Painter extends CustomPainter {
  final List<double> charges;
  _K2000Painter({required this.charges});

  static Color _couleurLed(double c) {
    if (c <= 0.02) return const Color(0xFF140000);
    final r = (70 + 185 * c).clamp(0, 255).round();
    final g = (60 * c * c * c).clamp(0, 255).round();
    final b = (25 * c * c * c * c).clamp(0, 255).round();
    return Color.fromARGB(255, r, g, b);
  }

  static Color _couleurHalo(double c) {
    final r = (110 * c).clamp(0, 255).round();
    final g = (15 * c * c * c).clamp(0, 255).round();
    return Color.fromARGB(255, r, g, 0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = charges.length;
    if (n == 0) return;
    final ledW = size.width / n;
    final ledH = size.height * 0.28;
    final cy = size.height / 2;

    // Boîtier sombre (ligne de fond)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, cy - ledH / 2, size.width, cy + ledH / 2),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF1A0505),
    );

    // LED + halo
    for (var i = 0; i < n; i++) {
      final c = charges[i];
      final x = (i + 0.5) * ledW;

      if (c > 0.25) {
        final rayon = ledH * (0.5 + 0.9 * c);
        canvas.drawCircle(
          Offset(x, cy),
          rayon,
          Paint()
            ..color = _couleurHalo(c)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, rayon),
        );
      }

      canvas.drawRect(
        Rect.fromLTRB(
            x - ledW / 2 + 0.5, cy - ledH / 2, x + ledW / 2 - 0.5, cy + ledH / 2),
        Paint()..color = _couleurLed(c),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _K2000Painter oldDelegate) => true;
}