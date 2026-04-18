import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SceneBackground extends StatelessWidget {
  final Widget child;
  final bool? dark;

  const SceneBackground({super.key, required this.child, this.dark});

  @override
  Widget build(BuildContext context) {
    final useDark = dark ?? Theme.of(context).brightness == Brightness.dark;

    final background = useDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141120), Color(0xFF1E1730), Color(0xFF100F1B)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.bgCanvas, AppTheme.bgCanvasSoft, Color(0xFFF1E7FF)],
          );

    final glow = useDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.75);

    return Container(
      decoration: BoxDecoration(gradient: background),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child: _Blob(
              size: 200,
              color: useDark ? AppTheme.primary.withOpacity(0.18) : AppTheme.primaryLight.withOpacity(0.26),
            ),
          ),
          Positioned(
            top: 120,
            right: -80,
            child: _Blob(
              size: 180,
              color: useDark ? AppTheme.accent.withOpacity(0.16) : AppTheme.accent.withOpacity(0.18),
            ),
          ),
          Positioned(
            bottom: -100,
            left: 40,
            child: _Blob(
              size: 240,
              color: useDark ? AppTheme.primaryLight.withOpacity(0.08) : AppTheme.primaryLight.withOpacity(0.18),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _DotGridPainter(color: glow),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0.0)]),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;

  _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 36.0;
    const radius = 1.2;

    for (double y = 24; y < size.height; y += spacing) {
      for (double x = 24; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) => oldDelegate.color != color;
}