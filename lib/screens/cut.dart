import 'dart:async';
import 'dart:io';
import 'dart:math' as math; // For math.max, math.min
import 'dart:ui' as ui; // For TextDirection
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_video_editor/easy_video_editor.dart'; // Main import
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:vidvidvid/screens/video_picker.dart';
import 'package:vidvidvid/widgets/constrained_video_player.dart';
import 'package:vidvidvid/widgets/feature_button.dart';

// Enum to identify which handle is being dragged
enum _DragHandleType { start, end }

enum CutPageState { loadingVideo, ready, idle, exporting, start }

// Data class for a time segment
class TimeSegment {
  Duration start;
  Duration end;
  final String id;

  TimeSegment({required this.start, required this.end}) : id = UniqueKey().toString();

  bool get isValid => start < end && end.inMilliseconds > start.inMilliseconds;

  @override
  bool operator ==(Object other) => identical(this, other) || other is TimeSegment && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CutPage extends StatefulWidget {
  const CutPage({super.key});

  @override
  State<CutPage> createState() => _CutPageState();
}

class _CutPageState extends State<CutPage> {
  CutPageState _screenState = CutPageState.start;
  VideoPlayerController? _videoPlayerController;
  File? _videoFile;
  final List<TimeSegment> _selectedSegments = [];
  TimeSegment? _currentlyEditingSegment; // Segment focused for button edits or list highlight

  Duration? _currentSegmentStartMarker; // For defining NEW segments
  Duration? _currentSegmentEndMarker; // For defining NEW segments

  Duration _currentPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isInitialized = false;
  String _exportProgressMessage = "";

  List<String> _thumbnailPaths = [];
  bool _generatingThumbnails = false;
  final Duration _stepAmount = const Duration(seconds: 1);

  final ScrollController _timelineScrollController = ScrollController();
  static const double _thumbnailWidth = 100.0; // Base width of each thumbnail at zoom 1.0
  static const double _timelineHeight = 90.0;
  String? _scrollToSegmentIdAfterBuild;

  // Drag state for handles
  _DragHandleType? _activeDragHandleType;
  String? _activeDragSegmentId;
  static const double _handleVisibleWidth = 12.0;
  static const double _handleTouchWidth = 30.0;

  // Zoom state
  double _timelineZoomLevel = 1.0;
  static const double _minZoomLevel = 0.25;
  static const double _maxZoomLevel = 4.0;
  static const double _zoomStep = 0.25;
  final GlobalKey _timelineStripKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      var storageStatus = await Permission.storage.request();
      if (storageStatus.isDenied && mounted) {
        var videoStatus = await Permission.videos.request();
        if (videoStatus.isDenied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage/Video permission is required to pick and save videos.')));
        }
      }
    } else if (Platform.isIOS) {
      if (await Permission.photos.request().isDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo library permission is required to pick videos.')));
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_videoListener);
    _videoPlayerController?.dispose();
    _timelineScrollController.dispose();
    _clearThumbnails(clearState: false);
    super.dispose();
  }

  void _videoListener() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) {
      return;
    }
    if (mounted) {
      setState(() {
        _currentPosition = _videoPlayerController!.value.position;
        _isPlaying = _videoPlayerController!.value.isPlaying;
      });
    }
  }

  Future<void> _pickVideo() async {
    if (_screenState == CutPageState.loadingVideo) return;

    setState(() {
      _screenState = CutPageState.loadingVideo;
      // Reset state
      _isInitialized = false;
      _videoFile = null;
      _selectedSegments.clear();
      _currentlyEditingSegment = null;
      _currentSegmentStartMarker = null;
      _currentSegmentEndMarker = null;
      _timelineZoomLevel = 1.0;
    });

    await _clearThumbnails();

    //FilePickerResult? result =
    //await FilePicker.platform.pickFiles(type: FileType.video);
    final file = await Navigator.of(context).push<File>(MaterialPageRoute(builder: (context) => const VideoPickerScreen()));

    if (file != null && file.path != null) {
      _videoFile = File(file.path!);
      await _initializeVideoPlayer();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No video selected.')));
      }
      setState(() => _screenState = CutPageState.idle);
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_videoFile == null) {
      setState(() => _screenState = CutPageState.idle);
      return;
    }

    await _videoPlayerController?.dispose();
    _videoPlayerController = VideoPlayerController.file(_videoFile!);
    _deselectSegment();

    try {
      await _videoPlayerController!.initialize();
      _videoPlayerController!.addListener(_videoListener);
      if (mounted) {
        setState(() {
          _isInitialized = _videoPlayerController!.value.isInitialized;
          _videoDuration = _videoPlayerController!.value.duration;
          _currentPosition = Duration.zero;
          _exportProgressMessage = "";
          _isPlaying = false;
        });
      }
      _videoPlayerController!.seekTo(Duration.zero);

      if (_isInitialized && _videoDuration > Duration.zero) {
        await _generateTimelineThumbnails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error initializing video: $e')));
      }
      if (mounted) {
        setState(() => _screenState = CutPageState.idle);
      }
    }
  }

  Future<void> _clearThumbnails({bool clearState = true}) async {
    final List<String> pathsToDelete = List.from(_thumbnailPaths);
    if (clearState && mounted) {
      setState(() {
        _thumbnailPaths.clear();
      });
    } else {
      _thumbnailPaths.clear();
    }

    for (final path in pathsToDelete) {
      final file = File(path);
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print("Error deleting thumbnail file $path: $e");
      }
    }
  }

  Future<void> _generateTimelineThumbnails() async {
    if (_videoFile == null || _videoDuration == Duration.zero || _generatingThumbnails) return;

    if (mounted) setState(() => _generatingThumbnails = true);

    final tempDir = await getTemporaryDirectory();
    final List<String> newPaths = [];

    final double thumbnailDensityFactor = 0.1;
    int numThumbs = (_videoDuration.inSeconds * thumbnailDensityFactor).round().clamp(5, 50);
    if (_videoDuration.inSeconds < 5 && _videoDuration.inSeconds > 0) {
      numThumbs = _videoDuration.inSeconds.clamp(1, 5);
    } else if (_videoDuration.inSeconds == 0) {
      numThumbs = 1;
    }

    for (int i = 0; i < numThumbs; i++) {
      final double fraction = (numThumbs <= 1) ? 0.5 : (i / (numThumbs - 1));
      final positionMs = (_videoDuration.inMilliseconds * fraction).round();
      final actualPositionMs = positionMs.clamp(0, _videoDuration.inMilliseconds);
      final thumbName = 'thumb_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final thumbPath = p.join(tempDir.path, thumbName);

      try {
        final editor = VideoEditorBuilder(videoPath: _videoFile!.path);
        final generatedPath = await editor.generateThumbnail(outputPath: thumbPath, positionMs: actualPositionMs, quality: 50);
        if (generatedPath != null && await File(generatedPath).exists()) {
          newPaths.add(generatedPath);
          if (mounted) {
            setState(() => _thumbnailPaths = List.from(newPaths));
          }
        }
      } catch (e) {
        print('Error generating thumbnail $i at ${actualPositionMs}ms: $e');
      }
    }
    if (mounted) {
      setState(() {
      _generatingThumbnails = false;
      _screenState = CutPageState.ready;
    });
    }
  }

  void _adjustScrollForZoom(double oldZoomLevel, double newZoomLevel) {
    if (!_timelineScrollController.hasClients || _videoDuration == Duration.zero) return;

    final RenderBox? timelineBox = _timelineStripKey.currentContext?.findRenderObject() as RenderBox?;
    if (timelineBox == null) return;
    final viewportWidth = timelineBox.size.width; // Width of the visible part of the timeline

    // Content width before zoom
    final double oldContentWidth = (_thumbnailPaths.length * _thumbnailWidth) * oldZoomLevel;
    // Pixel position of the current video time on the old zoomed timeline
    final double currentPosPxOld = (_currentPosition.inMilliseconds / _videoDuration.inMilliseconds) * oldContentWidth;
    // Current scroll offset
    final double scrollOffsetBeforeZoom = _timelineScrollController.offset;
    // Relative position of the scrubber within the viewport
    final double scrubberViewportOffset = currentPosPxOld - scrollOffsetBeforeZoom;

    // Content width after zoom
    final double newContentWidth = (_thumbnailPaths.length * _thumbnailWidth) * newZoomLevel;
    // Pixel position of the current video time on the new zoomed timeline
    final double currentPosPxNew = (_currentPosition.inMilliseconds / _videoDuration.inMilliseconds) * newContentWidth;

    // Calculate new scroll offset to keep scrubber at the same viewport position
    double newScrollOffset = currentPosPxNew - scrubberViewportOffset;
    newScrollOffset = newScrollOffset.clamp(0.0, math.max(0, newContentWidth - viewportWidth)); // Clamp to valid scroll range

    _timelineScrollController.jumpTo(newScrollOffset);
  }

  void _zoomIn() {
    final oldZoomLevel = _timelineZoomLevel;
    final newZoomLevel = (_timelineZoomLevel + _zoomStep).clamp(_minZoomLevel, _maxZoomLevel);
    if (oldZoomLevel == newZoomLevel) return;

    setState(() {
      _timelineZoomLevel = newZoomLevel;
    });
    // Adjust scroll after the state is updated and layout is likely done for new zoom level
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustScrollForZoom(oldZoomLevel, newZoomLevel);
    });
  }

  void _zoomOut() {
    final oldZoomLevel = _timelineZoomLevel;
    final newZoomLevel = (_timelineZoomLevel - _zoomStep).clamp(_minZoomLevel, _maxZoomLevel);
    if (oldZoomLevel == newZoomLevel) return;

    setState(() {
      _timelineZoomLevel = newZoomLevel;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjustScrollForZoom(oldZoomLevel, newZoomLevel);
    });
  }

  void _stepForward() {
    if (_videoPlayerController == null || !_isInitialized) return;
    final newPosition = _currentPosition + _stepAmount;
    _videoPlayerController!.seekTo(newPosition < _videoDuration ? newPosition : _videoDuration);
  }

  void _stepBackward() {
    if (_videoPlayerController == null || !_isInitialized) return;
    final newPosition = _currentPosition - _stepAmount;
    _videoPlayerController!.seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  void _goToVideoStart() {
    _videoPlayerController?.seekTo(Duration.zero);
    if (_timelineScrollController.hasClients) {
      _timelineScrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _goToVideoEnd() {
    if (_videoPlayerController != null && _videoDuration > Duration.zero) {
      _videoPlayerController!.seekTo(_videoDuration);
      if (_timelineScrollController.hasClients) {
        _timelineScrollController.animateTo(_timelineScrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }
  }

  void _setSegmentStart() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;

    final newStartTime = _videoPlayerController!.value.position;

    if (_currentlyEditingSegment != null) {
      if (newStartTime < _currentlyEditingSegment!.end) {
        setState(() {
          _currentlyEditingSegment!.start = newStartTime;
        });
        _showFeedback('Selected segment start updated to ${_formatDuration(newStartTime)}');
      } else {
        _showFeedback('Start time cannot be after segment\'s end time.');
      }
    } else {
      setState(() {
        _currentSegmentStartMarker = newStartTime;
      });
      _showFeedback('New segment start set at ${_formatDuration(newStartTime)}');
      _tryAutoAddSegment();
    }
  }

  void _setSegmentEnd() {
    if (_videoPlayerController == null || !_videoPlayerController!.value.isInitialized) return;

    final newEndTime = _videoPlayerController!.value.position;

    if (_currentlyEditingSegment != null) {
      if (newEndTime > _currentlyEditingSegment!.start) {
        setState(() {
          _currentlyEditingSegment!.end = newEndTime;
        });
        _showFeedback('Selected segment end updated to ${_formatDuration(newEndTime)}');
      } else {
        _showFeedback('End time cannot be before segment\'s start time.');
      }
    } else {
      setState(() {
        _currentSegmentEndMarker = newEndTime;
      });
      _showFeedback('New segment end set at ${_formatDuration(newEndTime)}');
      _tryAutoAddSegment();
    }
  }

  void _tryAutoAddSegment() {
    if (_currentlyEditingSegment == null && _currentSegmentStartMarker != null && _currentSegmentEndMarker != null) {
      if (_currentSegmentEndMarker! > _currentSegmentStartMarker!) {
        final newSegment = TimeSegment(start: _currentSegmentStartMarker!, end: _currentSegmentEndMarker!);
        setState(() {
          _selectedSegments.add(newSegment);
          _currentSegmentStartMarker = null;
          _currentSegmentEndMarker = null;
        });
        _showFeedback('Segment automatically added: ${_formatDuration(newSegment.start)} - ${_formatDuration(newSegment.end)}');
      }
    }
  }

  void _removeSegment(TimeSegment segment) {
    setState(() {
      _selectedSegments.remove(segment);
      if (_currentlyEditingSegment?.id == segment.id) {
        _deselectSegment();
      }
    });
    _showFeedback('Segment removed.');
  }

  void _clearNewSegmentMarkers() {
    setState(() {
      _currentSegmentStartMarker = null;
      _currentSegmentEndMarker = null;
    });
    _showFeedback('New segment time markers cleared.');
  }

  void _selectSegmentForEditing(TimeSegment segment) {
    setState(() {
      _currentlyEditingSegment = segment;
      _scrollToSegmentIdAfterBuild = segment.id;
      _videoPlayerController?.seekTo(segment.start);
    });
    _showFeedback('Selected segment for button edits: ${_formatDuration(segment.start)} - ${_formatDuration(segment.end)}');
  }

  void _deselectSegment() {
    setState(() {
      _currentlyEditingSegment = null;
    });
  }

  void _showFeedback(String message, {bool isProgress = false}) {
    if (mounted) {
      if (isProgress) {
        setState(() {
          _exportProgressMessage = message;
        });
      } else {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
      }
    }
  }

  Future<void> _exportVideo() async {
    final currentState = _screenState;

    if (_selectedSegments.isEmpty) {
      _showFeedback('No segments selected to export.');
      return;
    }
    if (_videoFile == null) {
      _showFeedback('No video loaded.');
      return;
    }

    setState(() {
      setState(() => _screenState = CutPageState.exporting);
      _exportProgressMessage = "Starting export...";
    });

    Directory? tempDir;
    String? finalExportedPath;
    final List<String> cutSegmentPaths = [];

    try {
      String? outputDirectoryPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select Output Folder');

      // No folder selected, stop.
      if (outputDirectoryPath == null) {
        _showFeedback('Export cancelled: No output folder selected.');
        setState(() {
          _screenState = currentState;
          _exportProgressMessage = "";
        });
        return;
      }

      tempDir = await getTemporaryDirectory();

      for (int i = 0; i < _selectedSegments.length; i++) {
        final segment = _selectedSegments[i];
        final tempOutputFileName = 'segment_${DateTime.now().millisecondsSinceEpoch}_$i.mp4';
        final tempSegmentOutputPath = p.join(tempDir.path, tempOutputFileName);

        _showFeedback('Processing segment ${i + 1}/${_selectedSegments.length}: Cutting...', isProgress: true);

        try {
          final editorBuilder = VideoEditorBuilder(videoPath: _videoFile!.path).trim(
            startTimeMs: segment.start.inMilliseconds,
            endTimeMs: segment.end.inMilliseconds, //
          );

          String? exportedFilePath = await editorBuilder.export(
            outputPath: tempSegmentOutputPath,
            onProgress: (progress) {
              if (mounted) {
                setState(() {
                  _exportProgressMessage = 'Cutting segment ${i + 1}/${_selectedSegments.length}: ${(progress * 100).toStringAsFixed(0)}%';
                });
              }
            },
          );

          if (exportedFilePath != null && await File(exportedFilePath).exists()) {
            cutSegmentPaths.add(exportedFilePath);
            _showFeedback('Segment ${i + 1} cut successfully.', isProgress: true);
          } else {
            throw Exception('Exported path for segment ${i + 1} is null or file does not exist.');
          }
        } catch (e, s) {
          print('Error cutting segment ${i + 1}: $e\n$s');
          _showFeedback('Error cutting segment ${i + 1}: $e. Skipping this segment.', isProgress: true);
        }
      }

      if (cutSegmentPaths.isEmpty) {
        _showFeedback('No segments were successfully cut. Export aborted.');
        setState(() {
          _screenState = currentState;
          _exportProgressMessage = "";
        });
        return;
      }

      final String outputFileName = 'merged_video_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.mp4';
      final String finalOutputPath = p.join(outputDirectoryPath, outputFileName);

      if (cutSegmentPaths.length == 1) {
        _showFeedback('Only one segment. Copying to output folder...', isProgress: true);
        try {
          await File(cutSegmentPaths.first).copy(finalOutputPath);
          finalExportedPath = finalOutputPath;
        } catch (e, s) {
          print('Error copying single segment: $e\n$s');
          _showFeedback('Error saving single segment: $e');
        }
      } else {
        _showFeedback('Merging ${cutSegmentPaths.length} successfully cut segments...', isProgress: true);
        VideoEditorBuilder mergeBuilder = VideoEditorBuilder(videoPath: cutSegmentPaths.first);
        if (cutSegmentPaths.length > 1) {
          mergeBuilder = mergeBuilder.merge(otherVideoPaths: cutSegmentPaths.sublist(1));
        }

        try {
          finalExportedPath = await mergeBuilder.export(
            outputPath: finalOutputPath,
            onProgress: (progress) {
              if (mounted) {
                setState(() {
                  _exportProgressMessage = 'Merging segments: ${(progress * 100).toStringAsFixed(0)}%';
                });
              }
            },
          );
        } catch (e, s) {
          print('Error during merge export: $e\n$s');
          _showFeedback('Failed to merge videos: $e.');
        }
      }

      if (finalExportedPath != null && await File(finalExportedPath!).exists()) {
        _showFeedback('Video exported successfully to: $finalExportedPath');
      } else {
        if (_screenState != CutPageState.exporting && finalExportedPath == null) {
          _showFeedback('Failed to export video. Output file not found or operation failed.');
        }
      }
    } catch (e, s) {
      print('Overall Export error: $e\n$s');
      _showFeedback('Export failed: $e');
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        for (final path in cutSegmentPaths) {
          final tempFile = File(path);
          if (await tempFile.exists()) {
            try {
              await tempFile.delete();
            } catch (e) {
              print("Error deleting temp segment file $path: $e");
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _screenState = currentState;
          _exportProgressMessage = "";
        });
      }
    }
  }

  String _formatDuration(Duration d, {bool showMillis = false}) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String threeDigits(int n) => n.toString().padLeft(3, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));

    String result = "";
    if (d.inHours > 0) {
      result += "${twoDigits(d.inHours)}:";
    }
    result += "$twoDigitMinutes:$twoDigitSeconds";

    if (showMillis) {
      result += ".${threeDigits(d.inMilliseconds.remainder(1000))}";
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    Widget? body;

    switch (_screenState) {
      case CutPageState.start:
        _pickVideo();
      case CutPageState.idle:
      body = Center(
          child: Padding(padding: EdgeInsets.symmetric(horizontal: 20),
              child: FeatureButton(title: 'Open video', icon: Icons.video_library_rounded, color: Theme.of(context).primaryColor, onTap: _pickVideo)//
          )
      );
      case CutPageState.loadingVideo:
        body = const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Preparing video..."), //
            ],
          ),
        );
      case CutPageState.ready:
        body = Column(
          children: [
            ConstrainedVideoPlayer(controller: _videoPlayerController!, maxHeight: 245),
            _buildVideoControls(),
            if (_generatingThumbnails != null)_buildTimelineStripe(context),
            _buildSegmentDefinitionControls(),
            const Divider(),
            Expanded(child: _buildSelectedSegmentsList()),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.cut),
                label: const Text('Export Selected Segments'),
                onPressed: _selectedSegments.isNotEmpty ? _exportVideo : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), //
                ),
              ),
            ),
          ],
        );
      case CutPageState.exporting:
        body = Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(_exportProgressMessage.isNotEmpty ? _exportProgressMessage : "Exporting... Please wait."), //
            ],
          ),
        );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Cut Video'), //
      ),
      body: body,
    );
  }

  Widget _buildVideoControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Center the group of play controls
        children: [
          IconButton(
            icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
            visualDensity: VisualDensity.compact,
            tooltip: _isMuted ? 'Pause' : 'Play',
            onPressed: () {
              setState(() {
                _videoPlayerController?.setVolume(_isMuted ? 1.0 : 0);
              });
            },
          ),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.skip_previous), tooltip: 'Go to Start', onPressed: _goToVideoStart),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.fast_rewind), tooltip: 'Step Backward', onPressed: _stepBackward),
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
            visualDensity: VisualDensity.compact,
            iconSize: 40,
            tooltip: _isPlaying ? 'Pause' : 'Play',
            onPressed: () {
              if (_videoPlayerController != null) {
                setState(() {
                  _isPlaying ? _videoPlayerController!.pause() : _videoPlayerController!.play();
                });
              }
            },
          ),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.fast_forward), tooltip: 'Step Forward', onPressed: _stepForward),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.skip_next), tooltip: 'Go to End', onPressed: _goToVideoEnd),
          const SizedBox(width: 16), // Spacer before time display
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Text(_formatDuration(_currentPosition), style: const TextStyle(fontSize: 12)), Text("/ ${_formatDuration(_videoDuration)}", style: const TextStyle(fontSize: 12, color: Colors.grey))]),
        ],
      ),
    );
  }

  Widget _buildTimelineStripe(BuildContext context) => LayoutBuilder(
    key: _timelineStripKey,
    builder: (context, constraints) {
      final double viewportWidth = constraints.maxWidth;
      final double baseContentWidth = _thumbnailPaths.length * _thumbnailWidth;
      final double currentContentWidth = baseContentWidth * _timelineZoomLevel;

      final double scrollableAreaWidth = math.max(viewportWidth - 32, currentContentWidth);

      if (_scrollToSegmentIdAfterBuild != null && _videoDuration > Duration.zero) {
        final segmentToScrollIdx = _selectedSegments.indexWhere((s) => s.id == _scrollToSegmentIdAfterBuild);
        if (segmentToScrollIdx != -1) {
          final segmentToScroll = _selectedSegments[segmentToScrollIdx];
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _timelineScrollController.hasClients && _videoDuration.inMilliseconds > 0) {
              double segmentStartPx = (segmentToScroll.start.inMilliseconds / _videoDuration.inMilliseconds) * currentContentWidth;
              double segmentWidthPx = ((segmentToScroll.end.inMilliseconds - segmentToScroll.start.inMilliseconds) / _videoDuration.inMilliseconds) * currentContentWidth;

              double targetOffset = segmentStartPx + (segmentWidthPx / 2) - (viewportWidth / 2);
              targetOffset = targetOffset.clamp(0.0, _timelineScrollController.position.maxScrollExtent);

              _timelineScrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              if (mounted) {
                setState(() {
                  _scrollToSegmentIdAfterBuild = null;
                });
              }
            } else if (mounted) {
              setState(() {
                _scrollToSegmentIdAfterBuild = null;
              });
            }
          });
        } else if (mounted) {
          setState(() {
            _scrollToSegmentIdAfterBuild = null;
          });
        }
      }

      double scrubberPositionXPx = (_videoDuration.inMilliseconds > 0) ? ((_currentPosition.inMilliseconds / _videoDuration.inMilliseconds) * currentContentWidth) : 0.0;

      List<Widget> stackChildren = [
        Positioned.fill(child: CustomPaint(painter: TimeRulerPainter(videoDuration: _videoDuration, totalWidth: currentContentWidth, height: _timelineHeight, textStyle: const TextStyle(color: Colors.white70, fontSize: 10), tickColor: Colors.white54, majorTickColor: Colors.white))),

        if (_thumbnailPaths.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:
                  _thumbnailPaths.map((path) {
                    final file = File(path);
                    return SizedBox(
                      width: _thumbnailWidth * _timelineZoomLevel,
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.black38, width: 0.5)),
                        child: ClipRect(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: Image.file(
                              file,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.broken_image, color: Colors.grey, size: 30);
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),

        ..._selectedSegments
            .map((segment) {
              if (_videoDuration.inMilliseconds == 0) return const SizedBox.shrink();
              final double leftPx = (segment.start.inMilliseconds / _videoDuration.inMilliseconds) * currentContentWidth;
              final double widthPx = ((segment.end.inMilliseconds - segment.start.inMilliseconds) / _videoDuration.inMilliseconds) * currentContentWidth;

              final bool isFocusedSegment = _currentlyEditingSegment?.id == segment.id;

              List<Widget> segmentAndHandles = [
                Positioned(left: leftPx.isNaN || leftPx.isInfinite || leftPx < 0 ? 0 : leftPx, top: 0, bottom: 20, width: widthPx.isNaN || widthPx.isInfinite || widthPx < 0 ? 0 : widthPx.clamp(0, currentContentWidth - leftPx), child: Container(decoration: BoxDecoration(color: isFocusedSegment ? Colors.yellow.withOpacity(0.45) : Colors.green.withOpacity(0.55), border: Border.all(color: isFocusedSegment ? Colors.yellowAccent.shade700 : Colors.lightGreenAccent.withOpacity(0.7), width: isFocusedSegment ? 2.5 : 1.5), borderRadius: BorderRadius.circular(2)))),
                Positioned(
                  left: (leftPx - _handleTouchWidth / 2).clamp(0.0, currentContentWidth - _handleTouchWidth),
                  top: 0,
                  bottom: 20,
                  width: _handleTouchWidth,
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _activeDragHandleType = _DragHandleType.start;
                        _activeDragSegmentId = segment.id;
                        _videoPlayerController?.pause();
                      });
                    },
                    onPanUpdate: (details) {
                      if (_activeDragHandleType == _DragHandleType.start && _activeDragSegmentId == segment.id) {
                        double dx = details.delta.dx;
                        if (currentContentWidth == 0 || _videoDuration.inMilliseconds == 0) return;
                        Duration timeDelta = Duration(milliseconds: (dx / currentContentWidth * _videoDuration.inMilliseconds).round());

                        final int segmentIndex = _selectedSegments.indexWhere((s) => s.id == _activeDragSegmentId);
                        if (segmentIndex == -1) return;
                        TimeSegment s = _selectedSegments[segmentIndex];

                        Duration newStartTime = s.start + timeDelta;

                        newStartTime = newStartTime.isNegative ? Duration.zero : newStartTime;
                        if (newStartTime >= s.end) {
                          newStartTime = s.end - const Duration(milliseconds: 50);
                        }
                        newStartTime = newStartTime.isNegative ? Duration.zero : newStartTime;

                        setState(() {
                          s.start = newStartTime;
                          if (_currentlyEditingSegment?.id == s.id) _currentSegmentStartMarker = newStartTime;
                          _videoPlayerController?.seekTo(newStartTime);
                        });
                      }
                    },
                    onPanEnd: (details) {
                      setState(() {
                        _activeDragHandleType = null;
                        _activeDragSegmentId = null;
                      });
                      _showFeedback('Segment start adjusted.');
                    },
                    child: Container(width: _handleTouchWidth, height: _timelineHeight - 20, color: Colors.transparent, child: Center(child: Container(width: _handleVisibleWidth, height: _timelineHeight - 20, decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.7), borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), bottomLeft: Radius.circular(3)), border: Border.all(color: Colors.white.withOpacity(0.8))), child: const Icon(Icons.drag_indicator, size: 10, color: Colors.white70)))),
                  ),
                ),
                Positioned(
                  left: (leftPx + widthPx - _handleTouchWidth / 2).clamp(0.0, currentContentWidth - _handleTouchWidth),
                  top: 0,
                  bottom: 20,
                  width: _handleTouchWidth,
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _activeDragHandleType = _DragHandleType.end;
                        _activeDragSegmentId = segment.id;
                        _videoPlayerController?.pause();
                      });
                    },
                    onPanUpdate: (details) {
                      if (_activeDragHandleType == _DragHandleType.end && _activeDragSegmentId == segment.id) {
                        double dx = details.delta.dx;
                        if (currentContentWidth == 0 || _videoDuration.inMilliseconds == 0) return;
                        Duration timeDelta = Duration(milliseconds: (dx / currentContentWidth * _videoDuration.inMilliseconds).round());

                        final int segmentIndex = _selectedSegments.indexWhere((s) => s.id == _activeDragSegmentId);
                        if (segmentIndex == -1) return;
                        TimeSegment s = _selectedSegments[segmentIndex];
                        Duration newEndTime = s.end + timeDelta;

                        newEndTime = newEndTime > _videoDuration ? _videoDuration : newEndTime;
                        if (newEndTime <= s.start) {
                          newEndTime = s.start + const Duration(milliseconds: 50);
                        }
                        newEndTime = newEndTime > _videoDuration ? _videoDuration : newEndTime;

                        setState(() {
                          s.end = newEndTime;
                          if (_currentlyEditingSegment?.id == s.id) _currentSegmentEndMarker = newEndTime;
                          _videoPlayerController?.seekTo(newEndTime);
                        });
                      }
                    },
                    onPanEnd: (details) {
                      setState(() {
                        _activeDragHandleType = null;
                        _activeDragSegmentId = null;
                      });
                      _showFeedback('Segment end adjusted.');
                    },
                    child: Container(width: _handleTouchWidth, height: _timelineHeight - 20, color: Colors.transparent, child: Center(child: Container(width: _handleVisibleWidth, height: _timelineHeight - 20, decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.7), borderRadius: const BorderRadius.only(topRight: Radius.circular(3), bottomRight: Radius.circular(3)), border: Border.all(color: Colors.white.withOpacity(0.8))), child: const Icon(Icons.drag_indicator, size: 10, color: Colors.white70)))),
                  ),
                ),
              ];
              return Stack(children: segmentAndHandles);
            })
            .expand((widget) => (widget is Stack ? widget.children : [widget]))
            .toList(),

        if (_currentSegmentStartMarker != null && _currentSegmentEndMarker != null && _videoDuration.inMilliseconds > 0 && _currentlyEditingSegment == null)
          Positioned(left: (_currentSegmentStartMarker!.inMilliseconds / _videoDuration.inMilliseconds) * currentContentWidth, top: 0, bottom: 20, width: ((_currentSegmentEndMarker!.inMilliseconds - _currentSegmentStartMarker!.inMilliseconds) / _videoDuration.inMilliseconds) * currentContentWidth, child: Container(decoration: BoxDecoration(color: Colors.orange.withOpacity(0.35), border: Border.all(color: Colors.orangeAccent.withOpacity(0.6), width: 1.5, style: BorderStyle.solid), borderRadius: BorderRadius.circular(2))))
        else if (_currentSegmentStartMarker != null && _videoDuration.inMilliseconds > 0 && _currentlyEditingSegment == null)
          Positioned(left: (_currentSegmentStartMarker!.inMilliseconds / _videoDuration.inMilliseconds) * currentContentWidth - 1, top: 0, bottom: 20, width: 3, child: Container(decoration: BoxDecoration(color: Colors.orangeAccent, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2, spreadRadius: 1)]))),
        if (_currentSegmentEndMarker != null && _currentSegmentStartMarker == null && _videoDuration.inMilliseconds > 0 && _currentlyEditingSegment == null) Positioned(left: (_currentSegmentEndMarker!.inMilliseconds / _videoDuration.inMilliseconds) * currentContentWidth - 1, top: 0, bottom: 20, width: 3, child: Container(decoration: BoxDecoration(color: Colors.orangeAccent, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 2, spreadRadius: 1)]))),

        if (_videoDuration.inMilliseconds > 0) Positioned(left: (scrubberPositionXPx - 25).clamp(0.0, currentContentWidth - 50), top: _timelineHeight - 19, child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(3)), child: Text(_formatDuration(_currentPosition, showMillis: false), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),

        if (_videoDuration.inMilliseconds > 0) Positioned(left: (scrubberPositionXPx - 1.5).clamp(0.0, currentContentWidth - 3.0), top: 0, bottom: 0, width: 3, child: Container(decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 3, spreadRadius: 1)]))),

        if (_generatingThumbnails && _thumbnailPaths.isEmpty) const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))),
      ];

      return Container(
        height: _timelineHeight,
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        color: Colors.grey.shade800,
        child: SingleChildScrollView(
          controller: _timelineScrollController,
          scrollDirection: Axis.horizontal,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              if (_activeDragHandleType == null && _videoPlayerController != null && _isInitialized && _videoDuration.inMilliseconds > 0 && _screenState != CutPageState.exporting) {
                final double tapPositionOnTimeline = (details.localPosition.dx).clamp(0.0, currentContentWidth);
                final double progress = (tapPositionOnTimeline / currentContentWidth).clamp(0.0, 1.0);
                final Duration seekPosition = Duration(milliseconds: (_videoDuration.inMilliseconds * progress).round());
                _videoPlayerController!.seekTo(seekPosition);
              }
            },
            child: SizedBox(width: scrollableAreaWidth, height: _timelineHeight, child: Stack(alignment: Alignment.bottomLeft, children: stackChildren)),
          ),
        ),
      );
    },
  );

  Widget _buildSegmentDefinitionControls() {
    bool canClearNewSegmentMarkers = _currentlyEditingSegment == null && (_currentSegmentStartMarker != null || _currentSegmentEndMarker != null);

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton.icon(icon: const Icon(Icons.first_page_rounded), label: Text(_currentlyEditingSegment != null ? 'Edit Start' : (_currentSegmentStartMarker == null ? 'Set Start' : 'Start: ${_formatDuration(_currentSegmentStartMarker!)}')), onPressed: _setSegmentStart, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[300])),
          ElevatedButton.icon(icon: const Icon(Icons.last_page_rounded), label: Text(_currentlyEditingSegment != null ? 'Edit End' : (_currentSegmentEndMarker == null ? 'Set End' : 'End: ${_formatDuration(_currentSegmentEndMarker!)}')), onPressed: _setSegmentEnd, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600])),
          // Zoom Controls Moved Here
          IconButton(icon: const Icon(Icons.zoom_out), tooltip: 'Zoom Out Timeline', onPressed: _zoomOut),
          IconButton(icon: const Icon(Icons.zoom_in), tooltip: 'Zoom In Timeline', onPressed: _zoomIn),
          if (canClearNewSegmentMarkers) TextButton.icon(icon: const Icon(Icons.clear), label: const Text('Clear New Markers'), onPressed: _clearNewSegmentMarkers),
        ],
      ),
    );
  }

  Widget _buildSelectedSegmentsList() {
    if (_selectedSegments.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('No segments added yet.'), Text('Use controls above to define segments.')])));
    }
    _selectedSegments.sort((a, b) => a.start.compareTo(b.start));

    return ListView.builder(
      itemCount: _selectedSegments.length,
      itemBuilder: (context, index) {
        final segment = _selectedSegments[index];
        final bool isFocusedSegment = _currentlyEditingSegment?.id == segment.id;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          elevation: isFocusedSegment ? 4 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: isFocusedSegment ? BorderSide(color: Colors.yellowAccent.shade700, width: 2) : BorderSide.none),
          color: isFocusedSegment ? Colors.yellow[100] : null,
          child: ListTile(
            title: Text('Segment ${index + 1}: ${_formatDuration(segment.start)} - ${_formatDuration(segment.end)}'),
            trailing: IconButton(icon: const Icon(Icons.delete_rounded, color: Colors.red), tooltip: 'Remove Segment', onPressed: () => _removeSegment(segment)),
            onTap: () {
              if (isFocusedSegment) {
                _deselectSegment();
              } else {
                _selectSegmentForEditing(segment);
              }
            },
          ),
        );
      },
    );
  }
}

// Custom Painter for the Time Ruler
class TimeRulerPainter extends CustomPainter {
  final Duration videoDuration;
  final double totalWidth; // This should be the currentContentWidth (zoomed)
  final double height;
  final TextStyle textStyle;
  final Color tickColor;
  final Color majorTickColor;
  final int majorTickIntervalSeconds;
  final int minorTickIntervalSecondsRatio;

  TimeRulerPainter({required this.videoDuration, required this.totalWidth, required this.height, this.textStyle = const TextStyle(color: Colors.white70, fontSize: 10), this.tickColor = Colors.white54, this.majorTickColor = Colors.white, this.majorTickIntervalSeconds = 10, this.minorTickIntervalSecondsRatio = 5});

  @override
  void paint(Canvas canvas, Size size) {
    if (videoDuration == Duration.zero || totalWidth <= 0) return;

    final paint = Paint()..strokeWidth = 1;
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr, // Using ui.TextDirection
    );

    final double pixelsPerSecond = totalWidth / math.max(1, videoDuration.inSeconds.toDouble());

    int currentMajorTickIntervalSec = majorTickIntervalSeconds;
    if (pixelsPerSecond * currentMajorTickIntervalSec < 40) {
      currentMajorTickIntervalSec = (40 / pixelsPerSecond).ceil();
      currentMajorTickIntervalSec = ((currentMajorTickIntervalSec + 4) ~/ 5) * 5;
      currentMajorTickIntervalSec = math.max(currentMajorTickIntervalSec, majorTickIntervalSeconds);
    } else if (pixelsPerSecond * currentMajorTickIntervalSec > 200) {
      currentMajorTickIntervalSec = (150 / pixelsPerSecond).floor();
      currentMajorTickIntervalSec = ((currentMajorTickIntervalSec + 4) ~/ 5) * 5;
      currentMajorTickIntervalSec = math.max(5, currentMajorTickIntervalSec);
    }
    currentMajorTickIntervalSec = math.max(1, currentMajorTickIntervalSec);

    final int actualMinorTickIntervalSec = math.max(1, currentMajorTickIntervalSec ~/ minorTickIntervalSecondsRatio);

    const double rulerTextBottomPadding = 2.0;
    const double majorTickVisualHeight = 15.0;
    const double minorTickVisualHeight = 7.0;

    double lastLabelEndX = -double.infinity;

    for (int currentSecond = 0; currentSecond <= videoDuration.inSeconds; currentSecond++) {
      final bool isMajorTick = (currentSecond % currentMajorTickIntervalSec == 0);
      final bool isMinorTick = (currentSecond % actualMinorTickIntervalSec == 0 && !isMajorTick);

      if (!isMajorTick && !isMinorTick) continue;

      final double x = currentSecond * pixelsPerSecond;

      paint.color = isMajorTick ? majorTickColor : tickColor;
      final tickVisualH = isMajorTick ? majorTickVisualHeight : minorTickVisualHeight;

      canvas.drawLine(Offset(x, height - tickVisualH), Offset(x, height), paint);

      if (isMajorTick) {
        final minutes = currentSecond ~/ 60;
        final seconds = currentSecond % 60;
        String timeStr;
        if (videoDuration.inHours > 0 || currentSecond >= 3600) {
          final hours = currentSecond ~/ 3600;
          final remMinutes = (currentSecond % 3600) ~/ 60;
          final remSeconds = currentSecond % 60;
          timeStr = '${hours}:${remMinutes.toString().padLeft(2, '0')}:${remSeconds.toString().padLeft(2, '0')}';
        } else {
          timeStr = '${minutes}:${seconds.toString().padLeft(2, '0')}';
        }

        textPainter.text = TextSpan(text: timeStr, style: textStyle);
        textPainter.layout();

        final double labelStartX = x - textPainter.width / 2;
        final double labelEndX = x + textPainter.width / 2;

        if (labelStartX > lastLabelEndX + 5.0 || currentSecond == 0) {
          if (labelEndX < totalWidth + textPainter.width / 2) {
            textPainter.paint(canvas, Offset(labelStartX.clamp(0, totalWidth - textPainter.width), height - tickVisualH - textPainter.height - rulerTextBottomPadding));
            lastLabelEndX = labelEndX;
          }
        } else if (currentSecond == videoDuration.inSeconds && labelEndX < totalWidth + textPainter.width / 2 && labelStartX > lastLabelEndX + 5.0) {
          textPainter.paint(canvas, Offset(math.min(labelStartX, totalWidth - textPainter.width), height - tickVisualH - textPainter.height - rulerTextBottomPadding));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TimeRulerPainter oldDelegate) {
    return oldDelegate.videoDuration != videoDuration || oldDelegate.totalWidth != totalWidth || oldDelegate.height != height || oldDelegate.textStyle != textStyle || oldDelegate.tickColor != tickColor || oldDelegate.majorTickColor != majorTickColor || oldDelegate.majorTickIntervalSeconds != majorTickIntervalSeconds;
  }
}
