import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:finance_tracker/features/plans/models/destination.dart';
import 'package:finance_tracker/features/plans/models/plan.dart';

/// A painted landscape standing in for a destination photo. Known
/// destinations get their own look (beach, mountains…); otherwise the same
/// plan name always gets the same scene.
class PlanScene extends StatelessWidget {
  const PlanScene({super.key, required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final style = plan.kind == PlanKind.monthly
        ? SceneStyle.city
        : Destination.find(plan.destination)?.style ??
              SceneStyle.values[plan.name.toLowerCase().codeUnits.fold(
                    0,
                    (h, c) => (h * 31 + c) & 0x7fffffff,
                  ) %
                  SceneStyle.values.length];
    return SceneArt(style: style);
  }
}

enum SceneStyle { beach, mountains, sunset, city }

/// The scene itself, for places without a plan yet (e.g. a destination
/// picked in the form).
class SceneArt extends StatelessWidget {
  const SceneArt({super.key, required this.style});

  final SceneStyle style;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ScenePainter(style),
    child: const SizedBox.expand(),
  );
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter(this.style);

  final SceneStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    Paint fill(Color c) => Paint()..color = c;
    Paint vertical(List<Color> colors, Rect r) => Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(r);

    switch (style) {
      case SceneStyle.beach:
        canvas.drawRect(
          rect,
          vertical(const [Color(0xFF6EC6F0), Color(0xFFCDEFFB)], rect),
        );
        canvas.drawCircle(
          Offset(w * 0.8, h * 0.22),
          h * 0.1,
          fill(const Color(0xFFFFF4C2)),
        );
        final sea = Rect.fromLTRB(0, h * 0.55, w, h);
        canvas.drawRect(
          sea,
          vertical(const [Color(0xFF1E9BC4), Color(0xFF0E6E93)], sea),
        );
        // Island with a green hill.
        final island = Path()
          ..moveTo(w * 0.52, h * 0.58)
          ..quadraticBezierTo(w * 0.75, h * 0.18, w * 1.05, h * 0.42)
          ..lineTo(w * 1.05, h * 0.62)
          ..close();
        canvas.drawPath(island, fill(const Color(0xFF2F8A55)));
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.62, h * 0.6)
            ..quadraticBezierTo(w * 0.82, h * 0.34, w * 1.05, h * 0.5)
            ..lineTo(w * 1.05, h * 0.64)
            ..close(),
          fill(const Color(0xFF1F6B40)),
        );
        // Sand and surf.
        canvas.drawPath(
          Path()
            ..moveTo(0, h * 0.86)
            ..quadraticBezierTo(w * 0.35, h * 0.74, w * 0.7, h * 0.9)
            ..lineTo(w * 0.7, h)
            ..lineTo(0, h)
            ..close(),
          fill(const Color(0xFFF2DDB0)),
        );
        for (var i = 0; i < 3; i++) {
          canvas.drawLine(
            Offset(w * (0.1 + i * 0.22), h * (0.66 + i * 0.05)),
            Offset(w * (0.22 + i * 0.22), h * (0.66 + i * 0.05)),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.5)
              ..strokeWidth = math.max(1, h * 0.012)
              ..strokeCap = StrokeCap.round,
          );
        }
      case SceneStyle.mountains:
        canvas.drawRect(
          rect,
          vertical(const [Color(0xFF8DB6EE), Color(0xFFE4EEFB)], rect),
        );
        void peak(
          double x,
          double top,
          double width,
          Color c, {
          bool snow = false,
        }) {
          final p = Path()
            ..moveTo(x - width / 2, h)
            ..lineTo(x, top)
            ..lineTo(x + width / 2, h)
            ..close();
          canvas.drawPath(p, fill(c));
          if (snow) {
            canvas.drawPath(
              Path()
                ..moveTo(x - width * 0.12, top + (h - top) * 0.22)
                ..lineTo(x, top)
                ..lineTo(x + width * 0.12, top + (h - top) * 0.22)
                ..close(),
              fill(Colors.white),
            );
          }
        }
        peak(w * 0.3, h * 0.25, w * 0.9, const Color(0xFF5B7DB1), snow: true);
        peak(w * 0.78, h * 0.32, w * 0.8, const Color(0xFF46679E), snow: true);
        canvas.drawRect(
          Rect.fromLTRB(0, h * 0.8, w, h),
          fill(const Color(0xFF2F6B4F)),
        );
        // Pines.
        for (var i = 0; i < 6; i++) {
          final x = w * (0.08 + i * 0.17);
          canvas.drawPath(
            Path()
              ..moveTo(x - h * 0.06, h * 0.86)
              ..lineTo(x, h * 0.66)
              ..lineTo(x + h * 0.06, h * 0.86)
              ..close(),
            fill(const Color(0xFF1E4D36)),
          );
        }
      case SceneStyle.sunset:
        canvas.drawRect(
          rect,
          vertical(const [Color(0xFFFF9A8B), Color(0xFFFFD3A5)], rect),
        );
        canvas.drawCircle(
          Offset(w * 0.5, h * 0.62),
          h * 0.2,
          fill(const Color(0xFFFFF0B5)),
        );
        final sea = Rect.fromLTRB(0, h * 0.62, w, h);
        canvas.drawRect(
          sea,
          vertical(const [Color(0xFF7B5EA7), Color(0xFF4A3B7A)], sea),
        );
        for (var i = 0; i < 4; i++) {
          canvas.drawLine(
            Offset(w * (0.4 - i * 0.03), h * (0.7 + i * 0.07)),
            Offset(w * (0.6 + i * 0.03), h * (0.7 + i * 0.07)),
            Paint()
              ..color = const Color(0xFFFFE6A8).withValues(alpha: 0.6)
              ..strokeWidth = math.max(1, h * 0.015)
              ..strokeCap = StrokeCap.round,
          );
        }
        // Palm silhouette.
        final trunk = Paint()
          ..color = const Color(0xFF3A2747)
          ..strokeWidth = math.max(2, w * 0.025)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.12, h)
            ..quadraticBezierTo(w * 0.1, h * 0.6, w * 0.2, h * 0.35),
          trunk,
        );
        for (final a in [-2.6, -2.0, -1.2, -0.5, 0.2]) {
          canvas.drawLine(
            Offset(w * 0.2, h * 0.35),
            Offset(
              w * 0.2 + math.cos(a) * w * 0.16,
              h * 0.35 + math.sin(a) * w * 0.1 + h * 0.05,
            ),
            trunk,
          );
        }
      case SceneStyle.city:
        canvas.drawRect(
          rect,
          vertical(const [Color(0xFF7F9CF5), Color(0xFFD9E4FF)], rect),
        );
        canvas.drawCircle(
          Offset(w * 0.22, h * 0.24),
          h * 0.09,
          fill(const Color(0xFFFFF4C2)),
        );
        final rnd = math.Random(7);
        var x = 0.0;
        while (x < w) {
          final bw = w * (0.1 + rnd.nextDouble() * 0.1);
          final bh = h * (0.3 + rnd.nextDouble() * 0.4);
          final b = Rect.fromLTWH(x, h - bh, bw - w * 0.01, bh);
          canvas.drawRect(b, fill(const Color(0xFF3E4C82)));
          // Lit windows.
          for (var wy = b.top + h * 0.05; wy < h - h * 0.05; wy += h * 0.09) {
            for (
              var wx = b.left + bw * 0.18;
              wx < b.right - bw * 0.2;
              wx += bw * 0.3
            ) {
              canvas.drawRect(
                Rect.fromLTWH(wx, wy, bw * 0.14, h * 0.035),
                fill(const Color(0xFFFFE08A).withValues(alpha: 0.85)),
              );
            }
          }
          x += bw;
        }
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.style != style;
}
