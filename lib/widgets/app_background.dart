import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF2F7FF),
            Color(0xFFE3EEFF),
            Color(0xFFF7FBFF),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _DotPatternPainter(),
        child: child,
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withOpacity(0.35)
      ..style = PaintingStyle.fill;

    const spacing = 34.0;
    const radius = 1.2;

    for (double y = 0; y < size.height; y += spacing) {
      final shift = (y / spacing).floor().isEven ? 0.0 : spacing / 2;
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x + shift, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
