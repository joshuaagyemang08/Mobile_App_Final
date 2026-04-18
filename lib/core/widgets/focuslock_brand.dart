import 'package:flutter/material.dart';

class FocusLockMark extends StatelessWidget {
  final double size;

  const FocusLockMark({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FocusLockMarkPainter(),
    );
  }
}

class _FocusLockMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.3;
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(r),
    );

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9CCFB0), Color(0xFF355B57)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(outer, bgPaint);

    final lockBodyRect = Rect.fromLTWH(
      size.width * 0.22,
      size.height * 0.42,
      size.width * 0.56,
      size.height * 0.38,
    );
    final lockBody = RRect.fromRectAndRadius(
      lockBodyRect,
      Radius.circular(size.width * 0.12),
    );
    final lockBodyPaint = Paint()..color = Colors.white.withOpacity(0.96);
    canvas.drawRRect(lockBody, lockBodyPaint);

    final shackleRect = Rect.fromLTWH(
      size.width * 0.31,
      size.height * 0.19,
      size.width * 0.38,
      size.height * 0.36,
    );
    final shacklePaint = Paint()
      ..color = Colors.white.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(shackleRect, 3.35, 2.72, false, shacklePaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'F',
        style: TextStyle(
          color: const Color(0xFF35615A),
          fontSize: size.width * 0.34,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        size.width * 0.5 - textPainter.width * 0.5,
        size.height * 0.56 - textPainter.height * 0.5,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
