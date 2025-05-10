import 'package:flutter/material.dart';

class FeatureButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Function onTap;

  const FeatureButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate alpha value from opacity (0.0 to 1.0)
    // 0.1 opacity * 255 = 25.5, rounded to 26
    final int alpha = (0.1 * 255).round();

    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          // Use withAlpha() instead of withOpacity()
          color: color.withAlpha(alpha), // Corrected line
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color, width: 2.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(width: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}