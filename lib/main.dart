import 'package:flutter/material.dart';
import 'package:vidvidvid/screens/start.dart';

void main() => runApp(VidVidVidApp());

class VidVidVidApp extends StatelessWidget {
  const VidVidVidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VidVidVidApp',
      theme: ThemeData(
        // Set useMaterial3 to true to opt into Material Design 3
        useMaterial3: true,
        // Define the color scheme from a seed color
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent.shade200, // Your primary seed color
          // You can optionally override specific colors in the generated scheme
          // primary: Colors.deepPurple, // If you want to be very specific
          // secondary: Colors.amber,
          brightness: Brightness.light, // Or Brightness.dark for a dark theme base
        ),
      ),
      home: StartScreen(),
    );
  }
}
