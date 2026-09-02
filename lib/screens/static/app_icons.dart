import 'package:flutter/material.dart';

enum DotStyle { filled, outlined }

class ThreeDotsIcon extends StatelessWidget {
  final Color color;
  final double size;
  final DotStyle style;

  const ThreeDotsIcon({
    super.key,
    this.color = const Color.fromARGB(255, 255, 255, 255),
    this.size = 7,
    this.style = DotStyle.filled,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.4),
          child: Icon(
            style == DotStyle.filled ? Icons.circle : Icons.circle_outlined,
            color: color,
            size: size,
          ),
        ),
      ),
    );
  }
}
