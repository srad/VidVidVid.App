import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vidvidvid/utils/file_utils.dart';
import 'package:vidvidvid/widgets/feature_button.dart';
import 'package:vidvidvid/widgets/video_list.dart';

class MergePage extends StatefulWidget {
  const MergePage({super.key});

  @override
  _MergePageState createState() => _MergePageState();
}

class _MergePageState extends State<MergePage> {
  List<File> videos = [];
  String status = '';
  double progress = 0.0;
  bool isMerging = false;
  late VideoEditorBuilder _editor; // To keep track of editor instance
  int? _currentVideoSelection;

  // Variable to cancel the merge operation
  late Future<void> mergeOperation;

  Future<void> pickVideos() async {
    //final picked = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
    final files = await FileUtils.pickVideos(context, 20);
    if (files != null && files.isNotEmpty) {
      setState(() {
        videos = files;
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
      status = "";
      //status = "Merging videos...";
    });

    // Initialize VideoEditorBuilder with the first video
    _editor = VideoEditorBuilder(videoPath: videos[0].path);

    for (int i = 1; i < videos.length; i++) {
      _editor.merge(otherVideoPaths: [videos[i].path]);
    }

    // Define the output path for the merged video
    final outputPath = '$outputDir/merged_video.mp4';

    // Start the merge operation and handle cancellation
    mergeOperation = _editor
        .export(
          outputPath: outputPath,
          onProgress: (p) {
            if (mounted) {
              setState(() {
                progress = p;
              });
            }
          },
        )
        .then((_) {
          setState(() {
            status = "✅ Merge complete: $outputPath";
            isMerging = false;
          });
        })
        .catchError((e) {
          setState(() {
            status = "❌ Merge failed: $e";
            isMerging = false;
          });
        });
  }

  Future cancelMerge() async {
    if (isMerging) {
      // Cancel the operation by disposing of the editor and stopping the task
      // TODO: await _editor.cancel();
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
    Widget? body;

    if (isMerging) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(padding: const EdgeInsets.all(16), child: LinearProgressIndicator(value: progress)),
          ElevatedButton(
            onPressed: cancelMerge,
            style: ElevatedButton.styleFrom(surfaceTintColor: Colors.red),
            child: const Text('Cancel merge'), //
          ),
        ],
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Center(
            child: FeatureButton(
              label: 'Open video',
              icon: Icons.video_library_rounded,
              color: Theme.of(context).primaryColor,
              onTap: pickVideos, //
            ), //
          ),
          SizedBox(height: 8),
          if (videos.isNotEmpty) ...[
            //Text('Selected ${videos.length} video(s)'),
            //SizedBox(height: 10),
            FeatureButton(
              label: 'Select Destination Folder',
              icon: Icons.folder_open,
              color: Colors.green.shade800,
              onTap: selectDestinationFolder, //
            ),
            Divider(),
            Expanded(child: VideoList(videos: videos, onRemove: (index) {
              setState(() {
                videos.removeAt(index);
                status = "Selected ${videos.length} video(s)";
              });
            })),
            if (progress == 0.0) ...[
              SizedBox(height: 16),
              Text(status, textAlign: TextAlign.center), //
            ],
          ],
        ],
        ));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        title: Text("Merge Videos"), //
      ),
      body: Padding(padding: EdgeInsets.all(8), child: body),
    );
  }
}
