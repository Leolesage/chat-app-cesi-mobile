import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.label,
    this.size = 46,
    this.isOnline = true,
  });

  final String label;
  final double size;
  final bool isOnline;

  Color _colorForLabel(String value) {
    const palette = [
      Color(0xFF0C8A6A),
      Color(0xFF2B7A78),
      Color(0xFF3A6D8C),
      Color(0xFF7A4EAB),
      Color(0xFFC46D4C),
      Color(0xFFB84C65),
    ];

    final hash = value.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = label.isEmpty ? '?' : label.substring(0, 1).toUpperCase();
    final baseColor = _colorForLabel(label);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor.withOpacity(0.9),
                baseColor.withOpacity(0.55),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.42,
              ),
            ),
          ),
        ),
        if (isOnline)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              height: size * 0.22,
              width: size * 0.22,
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
