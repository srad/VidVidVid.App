import 'package:flutter/material.dart';

class NiceErrorWidget extends StatelessWidget {
  final String? title;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color textColor;
  final Color buttonColor;
  final Color buttonTextColor;

  const NiceErrorWidget({
    super.key,
    this.title,
    required this.message,
    this.buttonText,
    this.onButtonPressed,
    this.icon = Icons.error_outline,
    this.iconColor = Colors.redAccent,
    this.backgroundColor = Colors.transparent, // Or a subtle background like Colors.grey[50]
    this.textColor = Colors.black87,
    this.buttonColor = Colors.blueAccent,
    this.buttonTextColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 80.0,
              color: iconColor,
            ),
            const SizedBox(height: 24.0),
            if (title != null && title!.isNotEmpty)
              Text(
                title!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.0,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            if (title != null && title!.isNotEmpty)
              const SizedBox(height: 12.0),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.0,
                color: textColor.withOpacity(0.8),
                height: 1.5, // Improves readability
              ),
            ),
            const SizedBox(height: 32.0),
            if (buttonText != null && onButtonPressed != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  elevation: 3.0,
                ),
                onPressed: onButtonPressed,
                child: Text(
                  buttonText!,
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: buttonTextColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}