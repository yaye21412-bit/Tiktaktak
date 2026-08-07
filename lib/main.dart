import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(debugShowCheckedModeBanner: false, title: 'Titaktak', home: VideoFeedScreen()));
}

class VideoFeedScreen extends StatefulWidget {
  @override
  _VideoFeedScreenState createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _initializeStore();
  }

  // Inicializar la conexión con Google Play Billing
  void _initializeStore() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    if (_isAvailable) {
      const Set<String> _kIds = {'titaktak_coins_100', 'titaktak_coins_500'}; // IDs de productos creados en Google Play Console
      ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_kIds);
      setState(() {
        _products = response.productDetails;
      });
    }
  }

  // Función para comprar a través de Google Play
  void _comprarMonedas(ProductDetails product) {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
  }

  // Pantalla para mostrar los paquetes de recarga de Google Play
  void _abrirRecargas() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        height: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Recargar Monedas (Google Play)", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            _isAvailable && _products.isNotEmpty
                ? Expanded(
                    child: ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return Card(
                          color: Colors.grey[800],
                          child: ListTile(
                            title: Text(product.title, style: TextStyle(color: Colors.white)),
                            subtitle: Text(product.description, style: TextStyle(color: Colors.grey[400])),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => _comprarMonedas(product),
                              child: Text(product.price),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Center(child: Text(_isAvailable ? "Cargando productos..." : "Tienda no disponible", style: TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder(
            stream: FirebaseFirestore.instance.collection('videos').snapshots(),
            builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              return PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var videoData = docs[index].data() as Map<String, dynamic>;
                  return VideoItem(
                    videoId: docs[index].id,
                    videoUrl: videoData['url'] ?? '',
                    username: videoData['usuario'] ?? 'usuario',
                    caption: videoData['descripcion'] ?? '',
                  );
                },
              );
            },
          ),
          // Botón superior para acceder a las recargas de Google Play
          Positioned(
            top: 40,
            right: 20,
            child: FloatingActionButton.extended(
              backgroundColor: Colors.red,
              icon: Icon(Icons.monetization_on, color: Colors.white),
              label: Text("Recargar", style: TextStyle(color: Colors.white)),
              onPressed: _abrirRecargas,
            ),
          ),
        ],
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
    required this.videoId,
    required this.videoUrl,
    required this.username,
    required this.caption,
  });

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
    final docRef = FirebaseFirestore.instance.collection('videos').doc(widget.videoId);
    docRef.update({'likes': FieldValue.increment(1)});
  }

  void _abrirComentarios() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        height: 350,
        padding: EdgeInsets.all(10),
        child: Column(
          children: [
            Text("Comentarios", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.grey),
                    title: Text("Usuario_Ejemplo", style: TextStyle(color: Colors.white)),
                    subtitle: Text("¡Excelente video!", style: TextStyle(color: Colors.grey[400])),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.expand(
          child: _controller.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
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
                  IconButton(
                    icon: Icon(Icons.favorite, color: Colors.red, size: 40),
                    onPressed: _darLike,
                  ),
                  Text('$likes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  IconButton(
                    icon: Icon(Icons.comment, size: 40, color: Colors.white),
                    onPressed: _abrirComentarios,
                  ),
                  Text('Comentarios', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
