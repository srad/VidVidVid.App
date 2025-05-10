import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart'; // Ensure this import is present

class ConstrainedVideoPlayer extends StatelessWidget {
  final VideoPlayerController controller;
  final double maxHeight;

  const ConstrainedVideoPlayer({
    Key? key,
    required this.controller,
    this.maxHeight = 200.0, // Default maxHeight if not provided
  }) : super(key: key);

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
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
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
            style: TextStyle(color: Colors.white),
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
        child: VideoPlayer(controller),
      ),
    );
    // If you want this ConstrainedVideoPlayer to be centered on the screen
    // when it's narrower than the screen, you would wrap its usage in a Center widget:
    // Center(child: ConstrainedVideoPlayer(controller: _controller, maxHeight: 200))
  }
}

// Example Usage (within a Scaffold or other parent widget):
//
// late VideoPlayerController _myVideoController;
//
// @override
// void initState() {
//   super.initState();
//   // Example with a typically narrow/vertical aspect ratio video URL
//   _myVideoController = VideoPlayerController.networkUrl(
//     // Replace with a URL of a known NARROW/VERTICAL video for testing
//     Uri.parse('YOUR_NARROW_VERTICAL_VIDEO_URL_HERE'),
//   )..initialize().then((_) {
//       setState(() {});
//       // Verify the reported aspect ratio:
//       print("Video Initialized. Aspect Ratio: ${_myVideoController.value.aspectRatio}");
//       // For a 9:16 video, aspect ratio should be 9/16 = 0.5625
//       // _myVideoController.play();
//     }).catchError((error) {
//       print("Error initializing video player: $error");
//       setState(() {});
//     });
// }
//
// @override
// Widget build(BuildContext context) {
//   return Scaffold(
//     appBar: AppBar(title: const Text('Video Player Example')),
//     body: Column(
//       mainAxisAlignment: MainAxisAlignment.start,
//       children: [
//         const Padding(
//           padding: EdgeInsets.all(8.0),
//           child: Text("Below is the ConstrainedVideoPlayer. If the video is narrow, the widget itself should also be narrow and centered (due to the Center widget in this example)."),
//         ),
//         if (_myVideoController.value.isInitialized)
//           Center( // Center the ConstrainedVideoPlayer if it's narrower than the screen
//             child: ConstrainedVideoPlayer(
//               controller: _myVideoController,
//               maxHeight: 300.0, // Example maxHeight
//             ),
//           )
//         else if (_myVideoController.value.hasError)
//            Container(
//              width: MediaQuery.of(context).size.width,
//              height: 300.0, // Match example maxHeight
//              color: Colors.black,
//              child: const Center(child: Text("Error loading video", style: TextStyle(color: Colors.white)))
//            )
//         else
//           Container(
//             width: MediaQuery.of(context).size.width,
//             height: 300.0, // Match example maxHeight
//             color: Colors.black,
//             child: const Center(child: CircularProgressIndicator()),
//           ),
//       ],
//     ),
//   );
// }
//
// @override
// void dispose() {
//   _myVideoController.dispose();
//   super.dispose();
// }
