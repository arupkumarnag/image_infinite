import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Image Viewer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ImageListScreen(),
    );
  }
}

class ImageListScreen extends StatefulWidget {
  @override
  _ImageListScreenState createState() => _ImageListScreenState();
}

class _ImageListScreenState extends State<ImageListScreen> {
  final Dio _dio = Dio();
  final ScrollController _scrollController = ScrollController();
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  final int _imagesPerPage = 20;
  List<dynamic> _images = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchImages();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _hasMore) {
        _fetchImages();
      }
    });
  }

  Future<void> _fetchImages({bool isRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _dio.get('https://picsum.photos/v2/list', queryParameters: {
        'page': isRefresh ? 1 : _currentPage,
        'limit': _imagesPerPage,
      });

      if (response.statusCode == 200) {
        List<dynamic> fetchedImages = response.data;

        setState(() {
          if (isRefresh) {
            _images = fetchedImages;
            _currentPage = 1;
          } else {
            _images.addAll(fetchedImages);
          }
          _currentPage++;
          _hasMore = fetchedImages.length == _imagesPerPage;
        });
      } else {
        _showError('Failed to load images');
      }
    } catch (e) {
      _showError('Failed to load images');
    } finally {
      setState(() {
        _isLoading = false;
      });

      if (isRefresh) {
        _refreshController.refreshCompleted();
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onRefresh() async {
    await _fetchImages(isRefresh: true);
  }

  void _shareImage(String imageUrl) {
    Share.share(imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigoAccent.shade200,
      appBar: AppBar(
        backgroundColor: Colors.amber,
        centerTitle: true,
        title: const Padding(
          padding: EdgeInsets.only(top: 8.0),
          child: Text('Infinite Scrolling Image Gallery',
              style: TextStyle(fontWeight: FontWeight.w500)
          ),
        ),
      ),
      //FAB
      floatingActionButton: FloatingActionButton(
        onPressed: () {
            _showMyDialog(context);
        },
        backgroundColor: Colors.transparent,
        // shape: const StadiumBorder(),
        child: const Icon(Icons.info, size: 40,color: Colors.amber,),
      ),
      body: SmartRefresher(
        controller: _refreshController,
        enablePullDown: true,
        enablePullUp: true,
        onRefresh: _onRefresh,
        child: _buildImageList(),
      ),
    );
  }


  Widget _buildImageList() {
    if (_images.isEmpty && !_isLoading) {
      return const Center(child: Text('No images found'));
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _images.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _images.length) {
          return const Center(child: Text('Getting images...'));
        }
        final image = _images[index];
        final imageUrl = image['download_url'];

        return Card(
          color: Colors.teal,
          elevation: 5.0,
          margin: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              InkWell(
                onTap: () async{
                  await launchUrl(Uri.parse(imageUrl.toString()));
                },
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                  cacheManager: DefaultCacheManager(),
                ),
              ),
              ListTile(
                title: Text(image['author'],
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                  ),),
                trailing: IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => _shareImage(imageUrl),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _showMyDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.amber.shade200,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Info'),
          ],
        ),
        content: const SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Click on the image to view on a larger scale and download to your device.'),
            ],
          ),
        ),
        actions: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                child: const Text('Okay'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      );
    },
  );
}


