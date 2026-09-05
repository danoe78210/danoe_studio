import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/antique_theme.dart';

/// Lueur de bougie vacillante.
class CandleGlow extends StatefulWidget {
  final Alignment alignment;
  final double size;
  final double intensity;
  const CandleGlow(
      {super.key,
      this.alignment = Alignment.center,
      this.size = 500,
      this.intensity = 1});

  @override
  State<CandleGlow> createState() => _CandleGlowState();
}

class _CandleGlowState extends State<CandleGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final opacity = (0.12 + 0.08 * t) * widget.intensity;
          final scale = 1.0 + 0.06 * t;
          return Align(
              alignment: widget.alignment,
              child: Transform.scale(
                  scale: scale,
                  child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            AntiqueTheme.candleGlow.withValues(alpha: opacity),
                            AntiqueTheme.candleGlow.withValues(alpha: 0),
                          ])))));
        });
  }
}

/// Poussière dorée qui dérive lentement.
class DustParticles extends StatefulWidget {
  final int count;
  const DustParticles({super.key, this.count = 28});

  @override
  State<DustParticles> createState() => _DustParticlesState();
}

class _DustParticlesState extends State<DustParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 22))
        ..repeat();
  late final List<_P> _ps = List.generate(widget.count, (i) => _P.rand(i));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) =>
              CustomPaint(painter: _DustPainter(_c.value, _ps))),
    );
  }
}

class _P {
  final double baseX, speed, phase, size;
  _P(this.baseX, this.speed, this.phase, this.size);
  factory _P.rand(int i) {
    final r = math.Random(i);
    return _P(r.nextDouble(), 0.3 + r.nextDouble() * 0.7, r.nextDouble(),
        1.0 + r.nextDouble() * 1.8);
  }
}

class _DustPainter extends CustomPainter {
  final double t;
  final List<_P> ps;
  _DustPainter(this.t, this.ps);

  @override
  void paint(Canvas c, Size s) {
    for (final p in ps) {
      final prog = (t * p.speed + p.phase) % 1.0;
      final y = (1 - prog) * s.height;
      final x =
          p.baseX * s.width + math.sin((prog * 6 + p.phase) * math.pi) * 14;
      final fade = math.sin(prog * math.pi);
      c.drawCircle(
          Offset(x, y),
          p.size,
          Paint()
            ..color = AntiqueTheme.agedGold.withValues(alpha: 0.25 * fade));
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter old) => old.t != t;
}

/// Vignette sombre sur les bords.
class Vignette extends StatelessWidget {
  const Vignette({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
            gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.95,
                colors: [Color(0x00000000), Color(0x99000000)],
                stops: [0.6, 1.0])));
  }
}

/// Couche d'ambiance : translucide, non-interactive, isolée (RepaintBoundary).
/// (Pas d'ExcludeFromSemantics ici pour garantir la compilation.)
class Ambiance extends StatelessWidget {
  final bool subdued;
  const Ambiance({super.key, this.subdued = false});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
          child: Stack(children: [
        CandleGlow(
          alignment: Alignment(0.7, -0.6),
          size: 700,
          intensity: subdued ? 0.45 : 1,
        ),
        CandleGlow(
          alignment: Alignment(-0.7, 0.7),
          size: 600,
          intensity: subdued ? 0.45 : 1,
        ),
        Positioned.fill(child: DustParticles(count: subdued ? 10 : 28)),
        const Positioned.fill(child: Vignette()),
      ])),
    );
  }
}
