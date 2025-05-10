import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vidvidvid/screens/cut.dart';
import 'package:vidvidvid/screens/merge.dart';
import 'package:vidvidvid/screens/split.dart';
import 'package:vidvidvid/widgets/feature_button.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('VidVidVidApp')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FeatureButton(
              title: 'Cut Video',
              icon: Icons.content_cut,
              color: Colors.deepPurple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CutPage())), //
            ),
            SizedBox(height: 24),
            FeatureButton(
              title: 'Merge Videos',
              icon: Icons.video_call,
              color: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MergePage())), //
            ),
            SizedBox(height: 24),
            FeatureButton(
              title: 'Split Video',
              icon: Icons.call_split,
              color: Colors.deepOrangeAccent,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SplitPage())), //
            ),
          ],
        ),
      ),
    );
  }
}
