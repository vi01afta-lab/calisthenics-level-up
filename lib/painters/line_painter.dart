import 'package:flutter/material.dart';

class LinePainter extends CustomPainter {
  final double x1, y1, x2, y2;
  final Color color;

  LinePainter({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.color,
  });

  @override
  void paint(Canvas c, Size s) => c.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = color
          ..strokeWidth = 1.0,
      );

  @override
  bool shouldRepaint(_) => false;
}
