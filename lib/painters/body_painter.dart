import 'package:flutter/material.dart';
import '../models/muscle_data.dart';
import '../core/constants.dart';

class BodyPainter extends CustomPainter {
  final List<MuscleData> muscles;
  final bool frontal;

  BodyPainter({required this.muscles, required this.frontal});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;

    // Background gradient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFF0D1520),
          const Color(0xFF080810)
        ]).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    final bodyFill = Paint()
      ..color = const Color(0xFF1A2535)
      ..style = PaintingStyle.fill;
    final bodyStroke = Paint()
      ..color = kAccent.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    void drawShape(Path p) {
      canvas.drawPath(p, bodyFill);
      canvas.drawPath(p, bodyStroke);
    }

    // Head
    drawShape(Path()..addOval(Rect.fromCenter(center: Offset(w * .5, h * .08), width: w * .22, height: h * .10)));
    // Neck
    drawShape(Path()..addRect(Rect.fromCenter(center: Offset(w * .5, h * .145), width: w * .09, height: h * .04)));
    // Torso (trapezoidal)
    drawShape(Path()
      ..moveTo(w * .20, h * .165)
      ..lineTo(w * .80, h * .165)
      ..lineTo(w * .70, h * .52)
      ..lineTo(w * .30, h * .52)
      ..close());
    // Left arm
    drawShape(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .04, h * .175, w * .13, h * .30), const Radius.circular(12))));
    // Right arm
    drawShape(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .83, h * .175, w * .13, h * .30), const Radius.circular(12))));
    // Left leg
    drawShape(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .29, h * .53, w * .17, h * .42), const Radius.circular(12))));
    // Right leg
    drawShape(Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * .54, h * .53, w * .17, h * .42), const Radius.circular(12))));

    // Muscle overlays
    for (final m in muscles) {
      final c = m.statusColor;
      final fillP = Paint()
        ..color = c.withOpacity(m.enCooldown ? 0.38 : 0.18)
        ..style = PaintingStyle.fill;
      final glowP = Paint()
        ..color = c.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, m.enCooldown ? 4 : 2);

      Path? p;
      switch (m.id) {
        case 'pectoral':
          p = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * .5, h * .27), width: w * .44, height: h * .10), const Radius.circular(8)));
          break;
        case 'biceps':
          p = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * .105, h * .28), width: w * .09, height: h * .13), const Radius.circular(6)));
          break;
        case 'deltoides':
          p = Path()..addOval(Rect.fromCenter(center: Offset(w * .185, h * .20), width: w * .12, height: h * .07));
          break;
        case 'core':
          p = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * .5, h * .40), width: w * .30, height: h * .13), const Radius.circular(6)));
          break;
        case 'cuadriceps':
          for (final x in [w * .30, w * .55]) {
            final q = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, h * .545, w * .15, h * .20), const Radius.circular(8)));
            canvas.drawPath(q, fillP);
            canvas.drawPath(q, glowP);
          }
          continue;
        case 'dorsal':
          p = Path()
            ..moveTo(w * .22, h * .19)
            ..lineTo(w * .78, h * .19)
            ..lineTo(w * .68, h * .46)
            ..lineTo(w * .32, h * .46)
            ..close();
          break;
        case 'triceps':
          p = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * .895, h * .30), width: w * .09, height: h * .13), const Radius.circular(6)));
          break;
        case 'gluteo':
          p = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * .5, h * .535), width: w * .42, height: h * .07), const Radius.circular(8)));
          break;
        case 'isquio':
          for (final x in [w * .30, w * .55]) {
            final q = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, h * .60, w * .15, h * .20), const Radius.circular(8)));
            canvas.drawPath(q, fillP);
            canvas.drawPath(q, glowP);
          }
          continue;
        case 'trapecio':
          p = Path()
            ..moveTo(w * .36, h * .13)
            ..lineTo(w * .64, h * .13)
            ..lineTo(w * .71, h * .23)
            ..lineTo(w * .29, h * .23)
            ..close();
          break;
      }
      if (p != null) {
        canvas.drawPath(p, fillP);
        canvas.drawPath(p, glowP);
      }
    }
  }

  @override
  bool shouldRepaint(_) => true;
}
