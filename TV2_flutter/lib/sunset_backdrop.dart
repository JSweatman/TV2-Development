import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Original procedural artwork: no images, network requests or asset bundle.
/// The fixed background fills the viewport while foreground content can scroll.
class SunsetBackdrop extends StatelessWidget {
  const SunsetBackdrop(
      {super.key, required this.child, this.showArtwork = true});

  final Widget child;
  // Explicit solid fallback, also useful for future appearance preferences.
  final bool showArtwork;
  static const fallbackColor = Color(0xFF141A2D);

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: fallbackColor,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.topLeft,
          children: [
            if (showArtwork)
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                          painter: SunsetPainter(), isComplex: true),
                    ),
                  ),
                ),
              ),
            child,
          ],
        ),
      );
}

/// Finite, deterministic vector scene. No animation, blur, or saveLayer.
class SunsetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final w = size.width;
    final h = size.height;
    final horizon = h * .45;
    final sun = Offset(w * .84, horizon - h * .025);
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF10182F),
              Color(0xFF39304E),
              Color(0xFF986064),
              Color(0xFFF0A25E),
              Color(0xFF8B5961),
              Color(0xFF191D31)
            ],
            stops: [0, .2, .34, .45, .62, 1],
          ).createShader(bounds));
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(.68, -.15),
            radius: .7,
            colors: [
              const Color(0xFFFFD18A).withValues(alpha: .8),
              const Color(0xFFECA26C).withValues(alpha: 0)
            ],
          ).createShader(bounds));

    // Broken cloud banks with warm lower rims, authored as wave contours.
    for (var bank = 0; bank < 9; bank++) {
      final y = h * (.06 + bank * .043);
      final path = Path()..moveTo(-20, y);
      for (var i = 0; i <= 32; i++) {
        final x = w * i / 32;
        final wave = math.sin(i * .74 + bank * 1.7) * h * .008 +
            math.sin(i * 1.91 + bank) * h * .003;
        path.lineTo(x, y + wave + math.sin(i * .14 + bank) * h * .025);
      }
      path.lineTo(w + 20, y - h * .022);
      path.lineTo(-20, y - h * .026);
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..color = Color.lerp(
                    const Color(0xFF25263F), const Color(0xFF9B6268), bank / 9)!
                .withValues(alpha: .65));
    }
    canvas.drawCircle(sun, w * .014, Paint()..color = const Color(0xFFFFF3CC));
    final sea = Rect.fromLTRB(0, horizon, w, h);
    canvas.drawRect(
        sea,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFAF7167), Color(0xFF484055), Color(0xFF151C2D)],
          ).createShader(sea));
    // Perspective ripples and broken sun reflections, bounded to 74 strokes.
    for (var i = 0; i < 74; i++) {
      final t = i / 73;
      final y = horizon + (h - horizon) * t * t;
      final wave = Path()..moveTo(0, y);
      for (var j = 1; j <= 20; j++) {
        wave.lineTo(w * j / 20, y + math.sin(j * 1.8 + i * .8) * (1 + t * 3));
      }
      canvas.drawPath(
          wave,
          Paint()
            ..color =
                Color.lerp(const Color(0xFFE7AD89), const Color(0xFF716273), t)!
                    .withValues(alpha: .32)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .5 + t);
      final halfWidth =
          w * (.012 + t * .12) * (.55 + .45 * math.sin(i * 2.3).abs());
      final x = sun.dx + math.sin(i * 1.6) * w * .025 * t;
      canvas.drawLine(
          Offset(x - halfWidth, y),
          Offset(x + halfWidth, y),
          Paint()
            ..color = const Color(0xFFFFCD8A).withValues(alpha: .7 * (1 - t))
            ..strokeWidth = 1 + t * 2);
    }
    final shore = Path()
      ..moveTo(0, h * .41)
      ..cubicTo(w * .13, h * .43, w * .12, h * .47, w * .3, h * .48)
      ..lineTo(0, h * .49)
      ..close();
    canvas.drawPath(shore, Paint()..color = const Color(0xFF232336));
    final beach = Path()
      ..moveTo(0, h * .7)
      ..cubicTo(w * .25, h * .78, w * .28, h * .89, w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(beach, Paint()..color = const Color(0xFF141623));

    // Palms use a separate uniform scale so their leaves never stretch.
    canvas.save();
    final scale = math.min(w / 400, h / 700);
    canvas.scale(scale);
    _palm(canvas, const Offset(74, 99), 1);
    canvas.translate(-35, 135);
    _palm(canvas, const Offset(54, 108), .56);
    canvas.restore();
    // Gentle edge shading anchors the silhouette without hiding the sunset.
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(.3, -.1),
            radius: 1.1,
            colors: [Color(0x00101728), Color(0x66101728)],
          ).createShader(bounds));
  }

  void _palm(Canvas canvas, Offset crown, double scale) {
    canvas.save();
    canvas.translate(crown.dx, crown.dy);
    canvas.scale(scale);
    final ink = Paint()..color = const Color(0xFF090F1A);
    final trunk = Path()
      ..moveTo(-115, 550)
      ..quadraticBezierTo(-86, 188, -4, 0)
      ..lineTo(5, 0)
      ..quadraticBezierTo(-53, 208, -83, 550)
      ..close();
    canvas.drawPath(trunk, ink);
    for (final tip in const [
      Offset(-150, -55),
      Offset(-90, -95),
      Offset(18, -100),
      Offset(142, -74),
      Offset(220, -4),
      Offset(224, 94),
      Offset(164, 186),
      Offset(73, 235),
      Offset(-88, 145)
    ]) {
      final control = Offset(tip.dx * .65, tip.dy * .22 - 52);
      final rib = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(control.dx, control.dy, tip.dx, tip.dy);
      canvas.drawPath(
          rib,
          Paint()
            ..color = ink.color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke);
      for (var i = 1; i < 22; i++) {
        final t = i / 23;
        final root = control * (2 * (1 - t) * t) + tip * (t * t);
        final tangent = (control * (1 - 2 * t) + tip * t);
        final length = tangent.distance;
        final normal = Offset(-tangent.dy / length, tangent.dx / length);
        final leafLength = 33 * math.sin(math.pi * t) + 4;
        for (final side in [-1.0, 1.0]) {
          final end = root + normal * (leafLength * side) + Offset(8, 16);
          canvas.drawPath(
              Path()
                ..moveTo(root.dx, root.dy)
                ..quadraticBezierTo(root.dx + normal.dx * side * 10,
                    root.dy + normal.dy * side * 10, end.dx, end.dy)
                ..lineTo(root.dx + 3, root.dy + 2)
                ..close(),
              ink);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SunsetPainter oldDelegate) => false;
}
