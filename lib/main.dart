import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TitaktakApp());
}

class TitaktakApp extends StatelessWidget {
  const TitaktakApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Titaktak',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FirebaseInitializer(),
    );
  }
}

class FirebaseInitializer extends StatelessWidget {
  const FirebaseInitializer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Firebase.initializeApp(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const VideoFeedScreen();
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'Error al iniciar:\n${snapshot.error}',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      },
    );
  }
}

class VideoFeedScreen extends StatelessWidget {
  const VideoFeedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('videos').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No hay videos disponibles',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            );
          }
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

  const VideoItem({
    Key? key,
    required this.videoId,
    required this.videoUrl,
    required this.username,
    required this.caption,
  }) : super(key: key);

  @override
  _VideoItemState createState() => _VideoItemState();
}

class _VideoItemState extends State<VideoItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    if (widget.videoUrl.isEmpty) return;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          _controller.play();
          _controller.setLooping(true);
        }
      }).catchError((error) {
        print("Error al reproducir video: $error");
      });
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _darLike() {
    FirebaseFirestore.instance
        .collection('videos')
        .doc(widget.videoId)
        .update({'likes': FieldValue.increment(1)});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.expand(
          child: _isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.username}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.caption,
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        Positioned(
          right: 15,
          bottom: 100,
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('videos')
                .doc(widget.videoId)
                .snapshots(),
            builder: (context, snapshot) {
              int likes = 0;
              if (snapshot.hasData && snapshot.data!.exists) {
                var dataDoc = snapshot.data!.data() as Map<String, dynamic>?;
                if (dataDoc != null && dataDoc.containsKey('likes')) {
                  likes = dataDoc['likes'] ?? 0;
                }
              }
              return Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red, size: 40),
                    onPressed: _darLike,
                  ),
                  Text(
                    '$likes',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
