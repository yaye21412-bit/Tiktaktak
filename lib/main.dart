import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, title: 'Titaktak', home: VideoFeedScreen()));
}

class VideoFeedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('videos').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return VideoItem(
                videoId: docs[index].id,
                videoUrl: data['url'] ?? '',
                username: data['usuario'] ?? 'usuario',
                caption: data['descripcion'] ?? '',
              );
            },
          );
        },
      ),
    );
  }
}

class VideoItem extends StatefulWidget {
  final String videoId;
  final String videoUrl;
  final String username;
  final String caption;

  const VideoItem({required this.videoId, required this.videoUrl, required this.username, required this.caption});

  @override
  _VideoItemState createState() => _VideoItemState();
}

class _VideoItemState extends State<VideoItem> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _darLike() {
    FirebaseFirestore.instance.collection('videos').doc(widget.videoId).update({'likes': FieldValue.increment(1)});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.expand(
          child: _controller.value.isInitialized
              ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: _controller.value.size.width, height: _controller.value.size.height, child: VideoPlayer(_controller)))
              : Center(child: CircularProgressIndicator()),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@${widget.username}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 8),
              Text(widget.caption, style: TextStyle(fontSize: 14, color: Colors.white)),
              SizedBox(height: 20),
            ],
          ),
        ),
        Positioned(
          right: 15,
          bottom: 100,
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('videos').doc(widget.videoId).snapshots(),
            builder: (context, snapshot) {
              int likes = 0;
              if (snapshot.hasData && snapshot.data!.exists) {
                likes = (snapshot.data!.data() as Map<String, dynamic>)['likes'] ?? 0;
              }
              return Column(
                children: [
                  IconButton(icon: Icon(Icons.favorite, color: Colors.red, size: 40), onPressed: _darLike),
                  Text('$likes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
