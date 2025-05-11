import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ConstrainedVideoPlayer extends StatelessWidget {
  final VideoPlayerController controller;
  final double maxHeight;

  const ConstrainedVideoPlayer({super.key, required this.controller, this.maxHeight = 200});

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container(
        // For the placeholder, we might still want it to be discernible.
        // You can choose to make it screen width or also constrained.
        // Here, we'll use maxHeight and let its width be determined by a common placeholder aspect ratio like 16/9,
        // but still constrained by screen width.
        width: MediaQuery.of(context).size.width,
        height: maxHeight,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white), //
          ),
        ), //
      );
    }

    final double videoAspectRatio = controller.value.aspectRatio;

    if (videoAspectRatio <= 0) {
      // Similar placeholder sizing for error state
      return Container(
        width: MediaQuery.of(context).size.width,
        height: maxHeight,
        color: Colors.black,
        child: const Center(
          child: Text(
            'Error: Invalid video aspect ratio.',
            style: TextStyle(color: Colors.white), //
          ),
        ),
      );
    }

    // This is the main change:
    // The outer Container no longer has a fixed width: MediaQuery.of(context).size.width.
    // Instead, it uses BoxConstraints for both maxWidth and maxHeight.
    // The AspectRatio child will then size itself according to its own aspectRatio,
    // fitting within these constraints. The Container will then wrap the AspectRatio.
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width, // Video cannot be wider than the screen
        maxHeight: maxHeight, // Video cannot be taller than maxHeight
      ),
      // Optional: Add a background color to see the bounds of this container
      // color: Colors.grey.withOpacity(0.5),
      child: AspectRatio(
        aspectRatio: videoAspectRatio,
        child: VideoPlayer(controller), //
      ),
    );
    // If you want this ConstrainedVideoPlayer to be centered on the screen
    // when it's narrower than the screen, you would wrap its usage in a Center widget:
    // Center(child: ConstrainedVideoPlayer(controller: _controller, maxHeight: 200))
  }
}
