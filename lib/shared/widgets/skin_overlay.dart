import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_skin.dart';

/// 氛围叠纹画在内容后面，不挡点击、不盖住字。
class SkinFrame extends StatelessWidget {
  const SkinFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).colorScheme.surface),
        const SkinBackdrop(),
        child,
      ],
    );
  }
}

class SkinBackdrop extends StatelessWidget {
  const SkinBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.chengboSkin;
    if (skin.overlay == SkinOverlayKind.none) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: SkinOverlayPainter(kind: skin.overlay, glow: skin.playerGlow),
          ),
        ),
      ),
    );
  }
}

class SkinOverlayPainter extends CustomPainter {
  const SkinOverlayPainter({required this.kind, required this.glow});

  final SkinOverlayKind kind;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case SkinOverlayKind.none:
        return;
      case SkinOverlayKind.scanline:
        _paintScanlines(canvas, size);
      case SkinOverlayKind.hex:
        _paintHex(canvas, size);
      case SkinOverlayKind.glitch:
        _paintGlitch(canvas, size);
    }
  }

  void _paintScanlines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = glow.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintHex(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9B6DCF).withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const r = 18.0;
    const h = r * 1.732;
    for (var row = 0; row < size.height / h + 2; row++) {
      for (var col = 0; col < size.width / (r * 1.5) + 2; col++) {
        final cx = col * r * 1.5;
        final cy = row * h + (col.isOdd ? h / 2 : 0);
        _hex(canvas, Offset(cx, cy), r, paint);
      }
    }
  }

  void _hex(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * math.pi / 180;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _paintGlitch(Canvas canvas, Size size) {
    final yellow = Paint()
      ..color = const Color(0xFFE8DE00).withValues(alpha: 0.045)
      ..strokeWidth = 1;
    final cyan = Paint()
      ..color = const Color(0xFF00D4E8).withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 5) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        (y ~/ 5).isEven ? yellow : cyan,
      );
    }
    final band = Paint()..color = const Color(0xFFE8DE00).withValues(alpha: 0.035);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.22, size.width, 3), band);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.71, size.width, 2), band);
  }

  @override
  bool shouldRepaint(SkinOverlayPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.glow != glow;
}
