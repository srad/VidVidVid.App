import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vidvidvid/screens/start.dart';

void main() => runApp(VidVidVidApp());

class VidVidVidApp extends StatelessWidget {
  const VidVidVidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VidVidVidApp',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: StartScreen(),
    );
  }
}
