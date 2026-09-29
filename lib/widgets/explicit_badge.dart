import 'package:flutter/material.dart';

class ExplicitBadge extends StatelessWidget {
  final double size;

  const ExplicitBadge({super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6B6B6B),
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.center,
      child: Text(
        'E',
        style: TextStyle(
          color: Colors.black,
          fontSize: size * 0.72,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}
