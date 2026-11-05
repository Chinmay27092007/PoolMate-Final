import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DashedRouteWidget extends StatefulWidget {
  final double height;
  const DashedRouteWidget({super.key, this.height = 140});

  @override
  State<DashedRouteWidget> createState() => _DashedRouteWidgetState();
}

class _DashedRouteWidgetState extends State<DashedRouteWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: DashedCurvePainter(progress: _controller.value),
        );
      },
    );
  }
}

class DashedCurvePainter extends CustomPainter {
  final double progress;

  DashedCurvePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(40, size.height - 25);
    final end = Offset(size.width - 40, 25);
    final control1 = Offset(size.width * 0.45, size.height - 15);
    final control2 = Offset(size.width * 0.70, 30);

    final path = Path();
    path.moveTo(start.dx, start.dy);
    path.cubicTo(control1.dx, control1.dy, control2.dx, control2.dy, end.dx, end.dy);

    final dashPaint = Paint()
      ..color = AppColors.orange
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw dashed path
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      const dashWidth = 8.0;
      const dashSpace = 6.0;

      while (distance < metric.length) {
        final extractLen = min(dashWidth, metric.length - distance);
        final extractPath = metric.extractPath(distance, distance + extractLen);
        canvas.drawPath(extractPath, dashPaint);
        distance += dashWidth + dashSpace;
      }
    }

    // Draw Start Campus point
    final pointPaint = Paint()
      ..color = AppColors.orange
      ..style = PaintingStyle.fill;

    canvas.drawCircle(start, 5, pointPaint);
    canvas.drawCircle(end, 7, pointPaint);

    // Text labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = const TextSpan(
      text: 'CAMPUS',
      style: TextStyle(
        color: AppColors.orange,
        fontWeight: FontWeight.bold,
        fontSize: 11,
        letterSpacing: 1.2,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(start.dx - 18, start.dy + 8));

    textPainter.text = const TextSpan(
      text: 'AIRPORT',
      style: TextStyle(
        color: AppColors.orange,
        fontWeight: FontWeight.bold,
        fontSize: 11,
        letterSpacing: 1.2,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(end.dx - 24, end.dy - 22));

    // Moving Cab along the curve
    for (final metric in path.computeMetrics()) {
      final cabDistance = progress * metric.length;
      final tangent = metric.getTangentForOffset(cabDistance);
      if (tangent != null) {
        final cabPos = tangent.position;

        final cabBgPaint = Paint()
          ..color = AppColors.navyDark
          ..style = PaintingStyle.fill;
        canvas.drawCircle(cabPos, 14, cabBgPaint);

        final cabBorder = Paint()
          ..color = AppColors.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(cabPos, 14, cabBorder);

        // Cab icon
        final iconPainter = TextPainter(textDirection: TextDirection.ltr);
        iconPainter.text = TextSpan(
          text: String.fromCharCode(Icons.local_taxi_rounded.codePoint),
          style: TextStyle(
            inherit: false,
            color: AppColors.orange,
            fontSize: 16,
            fontFamily: Icons.local_taxi_rounded.fontFamily,
            package: Icons.local_taxi_rounded.fontPackage,
          ),
        );
        iconPainter.layout();
        iconPainter.paint(canvas, Offset(cabPos.dx - 8, cabPos.dy - 8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedCurvePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
