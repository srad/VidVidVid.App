import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart'; // Ensure this import is present

// This is a conceptual widget structure.
// You'll integrate this into your existing widget tree.
// Make sure '_controller' is a valid, initialized VideoPlayerController.

class ConstrainedVideoPlayer extends StatelessWidget {
  final VideoPlayerController controller;

  final dynamic maxHeight;

  const ConstrainedVideoPlayer({super.key, required this.controller, required this.maxHeight});

  @override
  Widget build(BuildContext context) {
    // It's crucial that the controller is initialized before accessing its value.
    // You should handle loading/error states appropriately in a real app.
    if (!controller.value.isInitialized) {
      // Return a placeholder or loading indicator if the controller isn't ready.
      return Container(
        width: MediaQuery.of(context).size.width,
        height: 200, // Max height
        color: Colors.black, // Placeholder background
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    // Get the video's aspect ratio from the controller.
    // Ensure this value is valid (e.g., > 0) to prevent layout errors.
    final double videoAspectRatio = controller.value.aspectRatio;

    // Defensive check for invalid aspect ratio
    if (videoAspectRatio <= 0) {
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

    return Container(
      // 1. Set the width to the full screen width.
      width: MediaQuery.of(context).size.width,
      // 2. Apply constraints: specifically, a maximum height.
      constraints: const BoxConstraints(
        maxHeight: 200.0,
      ),
      // Optional: Add a background color to the container for debugging or styling.
      // color: Colors.grey[300],
      child: AspectRatio(
        // 3. Use the video's intrinsic aspect ratio.
        // The AspectRatio widget will now work within the bounds
        // defined by the parent Container (full width, max 200 height).
        aspectRatio: videoAspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}

// Example Usage (within a Scaffold or other parent widget):
//
// late VideoPlayerController _myVideoController;
//
// @override
// void initState() {
//   super.initState();
//   _myVideoController = VideoPlayerController.networkUrl(
//     Uri.parse('YOUR_VIDEO_URL_HERE'), // Replace with your video URL
//   )..initialize().then((_) {
//       // Ensure the first frame is shown after the video is initialized,
//       // and trigger a rebuild.
//       setState(() {});
//       _myVideoController.play(); // Optionally start playing
//     }).catchError((error) {
//       // Handle initialization errors
//       print("Error initializing video player: $error");
//       setState(() {
//         // You might want to set a flag to show an error message in the UI
//       });
//     });
// }
//
// @override
// Widget build(BuildContext context) {
//   return Scaffold(
//     appBar: AppBar(title: const Text('Video Player Example')),
//     body: Column(
//       children: [
//         // Other widgets can go here
//         if (_myVideoController.value.isInitialized)
//           ConstrainedVideoPlayer(controller: _myVideoController)
//         else if (_myVideoController.value.hasError)
//            Container(
//              width: MediaQuery.of(context).size.width,
//              height: 200,
//              color: Colors.black,
//              child: const Center(child: Text("Error loading video", style: TextStyle(color: Colors.white)))
//            )
//         else
//           Container( // Placeholder while loading
//             width: MediaQuery.of(context).size.width,
//             height: 200,
//             color: Colors.black,
//             child: const Center(child: CircularProgressIndicator()),
//           ),
//         // Other widgets can go here
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
