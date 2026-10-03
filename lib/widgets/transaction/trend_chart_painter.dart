import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class TrendChartPainter extends CustomPainter {
  final List<double> values;

  TrendChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final double minVal = values.reduce(min);
    final double maxVal = values.reduce(max);
    final double range = (maxVal - minVal) == 0 ? 1 : maxVal - minVal;

    final gridPaint = Paint()
      ..color = lightGreen.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    const int gridLines = 5;
    for (int i = 0; i <= gridLines; i++) {
      final double y = size.height * i / gridLines;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.length == 1) {
      // Just draw a line in the middle if only one value
      final double y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()..color = const Color(0xFFE53935)..strokeWidth = 2);
      canvas.drawCircle(Offset(size.width/2, y), 3, Paint()..color = const Color(0xFFE53935));
      return;
    }

    final List<Offset> points = [];
    for (int i = 0; i < values.length; i++) {
      final double x = size.width * i / (values.length - 1);
      final double normalized = (values[i] - minVal) / range;
      final double y = size.height * (1 - normalized);
      points.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final pt in points) {
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFE53935).withValues(alpha: 0.15),
          const Color(0xFFE53935).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = const Color(0xFFE53935)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;
    for (final pt in points) {
      canvas.drawCircle(pt, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(TrendChartPainter oldDelegate) => true;
}
