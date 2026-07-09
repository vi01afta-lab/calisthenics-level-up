import 'package:flutter/material.dart';

class RankBadge extends StatelessWidget {
  final String rank;
  final Color color;
  final double fontSize;

  const RankBadge({
    super.key,
    required this.rank,
    required this.color,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)],
      ),
      child: Text(
        'RANGO $rank',
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
