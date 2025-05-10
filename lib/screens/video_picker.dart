import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import 'package:vidvidvid/widgets/feature_button.dart';
import 'package:vidvidvid/widgets/nice_error.dart'; // Needed for File type

class VideoPickerScreen extends StatefulWidget {
  const VideoPickerScreen({super.key});

  @override
  State<VideoPickerScreen> createState() => _VideoPickerScreenState();
}

class _VideoPickerScreenState extends State<VideoPickerScreen> {
  File? _selectedVideo;
  bool _loading = false;
  final ImagePicker _picker = ImagePicker();
  String _errorMessage = "";

  Future<void> _pickVideo() async {
    try {
      setState(() => _loading = true);
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        setState(() {
          _selectedVideo = File(video.path);
        });
        // Now you have the video file, you can pass it to your video editor
        debugPrint('Video selected: ${video.path}');
        if (mounted) Navigator.pop(context, File(video.path));
      } else {
        // User canceled the picker
        debugPrint('No video selected.');
      }
    } catch (e) {
      _errorMessage = '$e';
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickVideoFromCamera() async {
    setState(() => _loading = true);
    _errorMessage = "";

    try {
      // 1. Check/Request Camera Permission
      PermissionStatus cameraStatus = await Permission.camera.status;
      if (cameraStatus.isDenied || cameraStatus.isRestricted) {
        cameraStatus = await Permission.camera.request();
      }

      // Optional: Check Microphone Permission if your videos need audio (highly recommended)
      PermissionStatus microphoneStatus = await Permission.microphone.status;
      if (microphoneStatus.isDenied || microphoneStatus.isRestricted){
        microphoneStatus = await Permission.microphone.request();
      }

      if (cameraStatus.isGranted && microphoneStatus.isGranted) {
        final XFile? video = await _picker.pickVideo(source: ImageSource.camera);

        if (video != null) {
          setState(() {
            _selectedVideo = File(video.path);
          });
          debugPrint('Video recorded: ${video.path}');
          if (mounted) Navigator.pop(context, File(video.path));
        } else {
          debugPrint('No video recorded (picker returned null).');
          // This could happen if the user exits the camera app without recording
        }
      } else {
        String deniedPermissions = "";
        if (!cameraStatus.isGranted) deniedPermissions += "Camera ";
        if (!microphoneStatus.isGranted) deniedPermissions += "Microphone ";

        debugPrint('Permission denied for: $deniedPermissions');
        _errorMessage = '$deniedPermissions permission was denied.';
        if (cameraStatus.isPermanentlyDenied || microphoneStatus.isPermanentlyDenied) {
          _errorMessage = '$deniedPermissions permission was permanently denied. Please enable it in app settings.';
          // Optionally, offer to open app settings
          // await openAppSettings();
        }
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
      _errorMessage = 'An error occurred: $e';
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Video')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // if (_selectedVideo != null)
              //   Padding(
              //     padding: const EdgeInsets.all(8.0),
              //     // You might want a video player here to preview
              //     child: Text('Selected Video: ${_selectedVideo!.path}'),
              //   )
              // else
              //   const Text('No video selected.'),
              // const SizedBox(height: 20),
              if (_errorMessage != null)
                Column(
                  children: [
                    NiceErrorWidget(
                      title: "Error",
                      message: _errorMessage,
                    ),
                    SizedBox(height: 50), //
                  ],
                ),
              if (_loading) CircularProgressIndicator(),
              if (!_loading)
                Column(
                  children: [
                    FeatureButton(title: 'Record with Cam', icon: Icons.video_camera_front_rounded, onTap: _pickVideoFromCamera, color: Theme.of(context).primaryColor),
                    SizedBox(height: 10),
                    FeatureButton(title: 'Pick from Gallery', icon: Icons.video_library_rounded, onTap: _pickVideo, color: Theme.of(context).primaryColor), //
                  ],
                ),
            ],
          ),
        ), //
      ),
    );
  }
}
