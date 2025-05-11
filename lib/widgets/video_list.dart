import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:easy_video_editor/easy_video_editor.dart';

class VideoList extends StatefulWidget {
  List<File> videos;
  final Function(int) onRemove;

  VideoList({super.key, required this.videos, required this.onRemove});

  @override
  _VideoListState createState() => _VideoListState();
}

class _VideoListState extends State<VideoList> {
  late List<File> _videos;
  final Map<String, Uint8List?> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _videos = List.from(widget.videos);
  }

  @override
  void didUpdateWidget(VideoList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if the initialVideos prop has actually changed.
    // A simple reference check (widget.initialVideos != oldWidget.initialVideos)
    // works if the parent always provides a new list instance when data changes.
    // For more complex scenarios or if you want to compare list contents,
    // you might use something like `ListEquality` from the `collection` package.
    if (widget.videos != oldWidget.videos) {
      setState(() {
        _videos = List.from(widget.videos); // Update with the new list
        // When the entire input list changes, it's often safest to clear the thumbnail cache
        // as the set of videos might be completely different.
        // If changes are incremental, more sophisticated cache management might be needed.
        _thumbnailCache.clear();
      });
    }
  }

  void _removeVideo(int index) {
    if (index < 0 || index >= _videos.length) return;

    final String videoPath = _videos[index].path;
    setState(() {
      _videos.removeAt(index);
      if (_thumbnailCache.containsKey(videoPath)) {
        _thumbnailCache.remove(videoPath);
      }
    });
    widget.onRemove(index);
  }

  Future<Uint8List?> _generateThumbnail(String videoPath) async {
    if (_thumbnailCache.containsKey(videoPath)) {
      return _thumbnailCache[videoPath];
    }

    try {
      final editor = VideoEditorBuilder(videoPath: videoPath);
      final String? thumbnailPath = await editor.generateThumbnail(
        positionMs: 0, // For the first frame
        quality: 70,
        height: 100,
      );

      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        final File thumbnailFile = File(thumbnailPath);
        if (await thumbnailFile.exists()) {
          final Uint8List bytes = await thumbnailFile.readAsBytes();
          _thumbnailCache[videoPath] = bytes;
          // Consider deleting temp thumbnailFile if plugin doesn't manage it
          // await thumbnailFile.delete();
          return bytes;
        } else {
          _thumbnailCache[videoPath] = null;
          return null;
        }
      } else {
        _thumbnailCache[videoPath] = null;
        return null;
      }
    } catch (e) {
      debugPrint('Error generating thumbnail for $videoPath: $e');
      _thumbnailCache[videoPath] = null;
      return null;
    }
  }

  Future<void> _confirmRemoveVideo(int index) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to remove this video from the list?'), //
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false), //
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)), //
              onPressed: () => Navigator.of(context).pop(true),
            ), //
          ],
        );
      },
    );

    if (confirm == true) {
      _removeVideo(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_videos.isEmpty) {
      return const Center(child: Text('No videos have been selected.', style: TextStyle(fontSize: 16)));
    }

    return ListView.separated(
      separatorBuilder: (context, index) => Divider(color: Colors.transparent, height: 6),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final File videoFile = _videos[index];
        final String fileName = videoFile.path.split('/').last;
        final color = Colors.blueGrey.shade400;
        final alpha = 30;

        return InkWell(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
              // Use withAlpha() instead of withOpacity()
              color: color.withAlpha(alpha), // Corrected line
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                FutureBuilder<Uint8List?>(
                  future: _generateThumbnail(videoFile.path),
                  builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()), //
                      );
                    } else if (snapshot.hasError || snapshot.data == null) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.videocam_off_outlined, color: Colors.redAccent, size: 40)), //
                      );
                    } else {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.memory(
                          snapshot.data!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover, //
                          errorBuilder: (context, error, stackTrace) {
                            return Container(width: 80, height: 80, color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40)));
                          }, //
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2, //
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_rounded, color: Colors.red[700]),
                  tooltip: 'Remove video', //
                  onPressed: () {
                    _confirmRemoveVideo(index);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
