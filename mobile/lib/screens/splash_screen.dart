import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Opening animation: the ABVP emblem rises in a saffron glow with a flickering torch halo,
/// "ABVP" lifts letter by letter, the saffron arc draws itself, and the karyakartas rise
/// from the waves with the bhagwa flag fluttering. About 2.8 seconds, then [onDone].
class AbvpSplash extends StatefulWidget {
  const AbvpSplash({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<AbvpSplash> createState() => _AbvpSplashState();
}

class _AbvpSplashState extends State<AbvpSplash> with TickerProviderStateMixin {
  // The one-way intro.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..forward().whenComplete(widget.onDone);
  // Endless motion: flame flicker, flag flutter, slowly turning rays.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  static const _navy = Color(0xFF13235B);
  static const _saffron = Color(0xFFF26B0F);

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  /// 0→1 between [a] and [b] of the intro, with an easing curve.
  double _step(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_intro.value - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final emblem = math.min(size.width * 0.58, 280.0);
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([_intro, _loop]),
        builder: (context, _) {
          final t = _loop.value * 2 * math.pi;
          final flicker =
              0.5 + 0.3 * math.sin(t * 3) + 0.2 * math.sin(t * 7 + 1.3);
          final emblemIn = _step(0.0, 0.42, Curves.elasticOut);
          final glowIn = _step(0.05, 0.4);
          final arc = _step(0.42, 0.66);
          final crowd = _step(0.45, 0.82, Curves.easeOutBack);
          final words = _step(0.72, 0.95);
          return Stack(
            children: [
              // Soft saffron sunrise behind everything, with slowly turning rays.
              Positioned.fill(
                child: CustomPaint(
                  painter: _RaysPainter(
                    progress: glowIn,
                    turn: _loop.value,
                    centre: Offset(size.width / 2, size.height * 0.30),
                  ),
                ),
              ),
              // Emblem with a flickering torch halo.
              Align(
                alignment: const Alignment(0, -0.52),
                child: Opacity(
                  opacity: _step(0.0, 0.18),
                  child: Transform.rotate(
                    angle: (1 - _step(0.0, 0.4)) * -0.35,
                    child: Transform.scale(
                      scale: 0.4 + 0.6 * emblemIn,
                      child: Container(
                        width: emblem,
                        height: emblem,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _saffron.withValues(
                                alpha: 0.18 + 0.22 * flicker * glowIn,
                              ),
                              blurRadius: 30 + 26 * flicker,
                              spreadRadius: 4 + 10 * flicker * glowIn,
                            ),
                          ],
                        ),
                        child: Image.asset('assets/brand/emblem.png'),
                      ),
                    ),
                  ),
                ),
              ),
              // "ABVP" rising letter by letter, then the arc and the motto.
              Align(
                alignment: const Alignment(0, 0.16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 4; i++)
                          Builder(
                            builder: (_) {
                              final p = _step(
                                0.30 + i * 0.06,
                                0.52 + i * 0.06,
                                Curves.easeOutBack,
                              );
                              return Opacity(
                                opacity: p.clamp(0.0, 1.0),
                                child: Transform.translate(
                                  offset: Offset(0, 36 * (1 - p)),
                                  child: Text(
                                    'ABVP'[i],
                                    style: const TextStyle(
                                      fontFamily: 'Anek',
                                      fontSize: 64,
                                      height: 1,
                                      fontWeight: FontWeight.w800,
                                      color: _navy,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    SizedBox(
                      width: 230,
                      height: 22,
                      child: CustomPaint(painter: _ArcPainter(arc)),
                    ),
                    Opacity(
                      opacity: words,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - words)),
                        child: const Text(
                          'ज्ञान · शील · एकता',
                          style: TextStyle(
                            fontFamily: 'Anek',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.saffronInk,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Karyakartas rising from the waves with the fluttering flag.
              Positioned(
                left: -size.width * 0.05,
                right: -size.width * 0.05,
                bottom: -8 - 160 * (1 - crowd),
                child: Opacity(
                  opacity: _step(0.45, 0.6),
                  child: _Crowd(width: size.width * 1.1, wave: t),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The crowd picture with the flag laid back on its pole and fluttering from the pole side.
class _Crowd extends StatelessWidget {
  const _Crowd({required this.width, required this.wave});
  final double width;
  final double wave;

  // Where the flag sits in crowd.png (950 × 375).
  static const _crowd = Size(950, 375);
  static const _flag = Rect.fromLTRB(390, 43, 638, 193);

  @override
  Widget build(BuildContext context) {
    final k = width / _crowd.width;
    final flutter = math.sin(wave * 2);
    return SizedBox(
      width: width,
      height: _crowd.height * k,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/brand/crowd.png', fit: BoxFit.fill),
          ),
          Positioned(
            left: _flag.left * k,
            top: _flag.top * k,
            width: _flag.width * k,
            height: _flag.height * k,
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..setEntry(1, 0, 0.07 * flutter) // skew: the cloth ripples
                ..scaleByDouble(
                  1 - 0.05 * (1 + math.sin(wave * 2 + 1)) / 2,
                  1.0,
                  1.0,
                  1.0,
                ),
              child: Image.asset('assets/brand/flag.png', fit: BoxFit.fill),
            ),
          ),
        ],
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter({
    required this.progress,
    required this.turn,
    required this.centre,
  });
  final double progress;
  final double turn;
  final Offset centre;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final r = size.longestSide;
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE3C7).withValues(alpha: 0.9 * progress),
            const Color(0xFFFFF6EC).withValues(alpha: 0.6 * progress),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, 0.35, 0.7],
        ).createShader(Rect.fromCircle(center: centre, radius: r * 0.7)),
    );
    final ray = Paint()
      ..color = const Color(0xFFF26B0F).withValues(alpha: 0.05 * progress);
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(turn * math.pi / 6);
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      final p = Path()
        ..moveTo(0, 0)
        ..lineTo(math.cos(a - 0.07) * r, math.sin(a - 0.07) * r)
        ..lineTo(math.cos(a + 0.07) * r, math.sin(a + 0.07) * r)
        ..close();
      canvas.drawPath(p, ray);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.progress != progress || old.turn != turn || old.centre != centre;
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final path = Path()
      ..moveTo(0, size.height * 0.85)
      ..quadraticBezierTo(
        size.width * 0.5,
        -size.height * 0.4,
        size.width,
        size.height * 0.55,
      );
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5
        ..shader = const LinearGradient(
          colors: [Color(0xFFF26B0F), Color(0xFFFFA23C)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}
