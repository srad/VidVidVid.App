import 'package:flutter/material.dart';

enum FeatureButtonSize { large, medium }

class FeatureButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Function onTap;
  final FeatureButtonSize size;
  final double borderRadius;

  const FeatureButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = FeatureButtonSize.large,
    this.borderRadius = 6.0, //
  });

  @override
  Widget build(BuildContext context) {
    // Calculate alpha value from opacity (0.0 to 1.0)
    // 0.1 opacity * 255 = 25.5, rounded to 26
    final int alpha = (0.1 * 255).round();

    final double iconSize = switch (size) {
      FeatureButtonSize.large => 48,
      FeatureButtonSize.medium => 30, //
    };

    final double fontSize = switch (size) {
      FeatureButtonSize.large => 22,
      FeatureButtonSize.medium => 16, //
    };

    final padding = switch (size) {
      FeatureButtonSize.large => const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      FeatureButtonSize.medium => const EdgeInsets.symmetric(vertical: 10, horizontal: 8), //
    };

    final double gap = switch (size) {
      FeatureButtonSize.large => 20,
      FeatureButtonSize.medium => 10, //
    };

    return InkWell(
      onTap: () => onTap(),
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          // Use withAlpha() instead of withOpacity()
          color: color.withAlpha(alpha), // Corrected line
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: iconSize),
            SizedBox(width:  gap),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: color, //
              ),
            ), //
          ],
        ),
      ),
    );
  }
}
