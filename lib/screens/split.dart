import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class SplitPage extends StatefulWidget {
  const SplitPage({super.key});

  @override
  _SplitPageState createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  File? video;
  String status = '';
  double progress = 0.0;
  double splitTimeSeconds = 5.0;
  int videoDurationMs = 10000;

  VideoPlayerController? _videoController;
  bool isSeeking = false;

  Future<void> pickVideo() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.video);
    if (picked?.files.single.path != null) {
      video = File(picked!.files.single.path!);
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(video!)
        ..initialize().then((_) {
          setState(() {});
        });

      final metadata = await VideoEditorBuilder(videoPath: video!.path).getVideoMetadata();
      setState(() {
        videoDurationMs = metadata.duration ?? 10000;
        splitTimeSeconds = (videoDurationMs / 2000).toDouble(); // midpoint
        status = "Video selected: ${video!.path.split('/').last}";
      });
    }
  }

  Future<void> splitVideo() async {
    if (video == null) return;

    // Ask user to pick a folder to save split parts
    final outputDir = await FilePicker.platform.getDirectoryPath();
    if (outputDir == null) {
      setState(() => status = "❌ Split cancelled: no folder selected.");
      return;
    }

    final outputPath1 = '$outputDir/split_part1.mp4';
    final outputPath2 = '$outputDir/split_part2.mp4';
    final splitMs = (splitTimeSeconds * 1000).toInt();

    final part1 = VideoEditorBuilder(videoPath: video!.path)
        .trim(startTimeMs: 0, endTimeMs: splitMs);

    final part2 = VideoEditorBuilder(videoPath: video!.path)
        .trim(startTimeMs: splitMs, endTimeMs: videoDurationMs);

    setState(() {
      progress = 0.0;
      status = "Splitting video at ${splitTimeSeconds.toStringAsFixed(1)}s...";
    });

    await part1.export(
      outputPath: outputPath1,
      onProgress: (p) => setState(() => progress = p / 2),
    );

    await part2.export(
      outputPath: outputPath2,
      onProgress: (p) => setState(() => progress = 0.5 + (p / 2)),
    );

    setState(() => status = "✅ Split complete:\n1️⃣ $outputPath1\n2️⃣ $outputPath2");
  }

  @override
  void initState() {
    super.initState();
    Permission.storage.request();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void seekVideo(double seconds) {
    if (_videoController != null && _videoController!.value.isInitialized) {
      final duration = _videoController!.value.duration;
      if (seconds <= duration.inSeconds) {
        _videoController!.seekTo(Duration(seconds: seconds.toInt()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxSeconds = (videoDurationMs / 1000).floorToDouble();
    return Scaffold(
      appBar: AppBar(title: Text("Split Video")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _iconAction(
              icon: Icons.video_library,
              label: 'Select Video',
              color: Colors.orange,
              onTap: pickVideo,
            ),
            if (video != null && _videoController != null && _videoController!.value.isInitialized) ...[
              SizedBox(height: 20),
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Stack(
                  children: [
                    VideoPlayer(_videoController!),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: IconButton(
                        icon: Icon(
                          _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () {
                          setState(() {
                            _videoController!.value.isPlaying
                                ? _videoController!.pause()
                                : _videoController!.play();
                          });
                        },
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text("Split point: ${splitTimeSeconds.toStringAsFixed(1)} s"),
              Slider(
                value: splitTimeSeconds,
                min: 1.0,
                max: (maxSeconds - 1).clamp(1, double.infinity),
                divisions: (maxSeconds - 2).toInt().clamp(1, 100),
                label: "${splitTimeSeconds.toStringAsFixed(1)}s",
                onChanged: (val) {
                  setState(() {
                    splitTimeSeconds = val;
                    seekVideo(val);
                  });
                },
              ),
              _iconAction(
                icon: Icons.call_split,
                label: 'Split Video',
                color: Colors.orange.shade700,
                onTap: splitVideo,
              ),
            ],
            if (progress > 0 && progress < 1)
              Padding(
                padding: const EdgeInsets.all(16),
                child: LinearProgressIndicator(value: progress),
              ),
            SizedBox(height: 16),
            Text(status, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            SizedBox(width: 20),
            Text(label, style: TextStyle(fontSize: 20, color: color)),
          ],
        ),
      ),
    );
  }
}
