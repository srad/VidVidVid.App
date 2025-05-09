import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MergePage extends StatefulWidget {
  @override
  _MergePageState createState() => _MergePageState();
}

class _MergePageState extends State<MergePage> {
  List<File> videos = [];
  String status = '';
  double progress = 0.0;
  bool isMerging = false;
  late VideoEditorBuilder _editor;  // To keep track of editor instance

  // Variable to cancel the merge operation
  late Future<void> mergeOperation;

  Future<void> pickVideos() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
    if (picked?.files.isNotEmpty ?? false) {
      setState(() {
        videos = picked!.files.map((file) => File(file.path!)).toList();
        status = "Selected ${videos.length} video(s)";
      });
    }
  }

  Future<void> selectDestinationFolder() async {
    final outputDir = await FilePicker.platform.getDirectoryPath();
    if (outputDir == null) {
      setState(() => status = "❌ No folder selected.");
      return;
    }

    // Start the merging operation
    setState(() {
      isMerging = true;
      progress = 0.0;
      status = "Merging videos...";
    });

    // Initialize VideoEditorBuilder with the first video
    _editor = VideoEditorBuilder(videoPath: videos[0].path);

    for (int i = 1; i < videos.length; i++) {
      _editor.merge(otherVideoPaths: [videos[i].path]);
    }

    // Define the output path for the merged video
    final outputPath = '$outputDir/merged_video.mp4';

    // Start the merge operation and handle cancellation
    mergeOperation = _editor.export(
      outputPath: outputPath,
      onProgress: (p) {
        if (mounted) {
          setState(() {
            progress = p;
          });
        }
      },
    ).then((_) {
      setState(() {
        status = "✅ Merge complete: $outputPath";
        isMerging = false;
      });
    }).catchError((e) {
      setState(() {
        status = "❌ Merge failed: $e";
        isMerging = false;
      });
    });
  }

  Future cancelMerge() async {
    if (isMerging) {
      // Cancel the operation by disposing of the editor and stopping the task
      //await _editor.cancel();
      setState(() {
        status = "❌ Merge canceled.";
        isMerging = false;
        progress = 0.0;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    Permission.storage.request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Merge Videos")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _iconAction(
              icon: Icons.video_library,
              label: 'Select Videos',
              color: Colors.orange,
              onTap: pickVideos,
            ),
            SizedBox(height: 16),
            if (videos.isNotEmpty) ...[
              Text('Selected ${videos.length} video(s)'),
              SizedBox(height: 10),
              _iconAction(
                icon: Icons.folder_open,
                label: 'Select Destination Folder',
                color: Colors.green,
                onTap: selectDestinationFolder,
              ),
            ],
            if (isMerging) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: LinearProgressIndicator(value: progress),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: cancelMerge,
                child: Text('Cancel Merge'),
                style: ElevatedButton.styleFrom(surfaceTintColor: Colors.red),
              ),
            ],
            if (!isMerging && progress == 0.0)
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
