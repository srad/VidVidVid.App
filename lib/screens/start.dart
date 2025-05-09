import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vidvidvid/screens/cut.dart';
import 'package:vidvidvid/screens/merge.dart';
import 'package:vidvidvid/screens/split.dart';

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
            _featureButton(
              context,
              title: 'Cut Video',
              icon: Icons.content_cut,
              color: Colors.redAccent,
              page: CutPage(),
            ),
            SizedBox(height: 24),
            _featureButton(
              context,
              title: 'Merge Videos',
              icon: Icons.video_call,
              color: Colors.teal,
              page: MergePage(),
            ),
            SizedBox(height: 24),
            _featureButton(
              context,
              title: 'Split Video',
              icon: Icons.call_split,
              color: Colors.orange,
              page: SplitPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureButton(BuildContext context,
      {required String title,
        required IconData icon,
        required Color color,
        required Widget page}) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 48),
            SizedBox(width: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
