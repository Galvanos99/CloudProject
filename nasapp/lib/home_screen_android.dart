import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';

class HomeScreenAndroid extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreenAndroid> {
  final rtdb.DatabaseReference _dbRef =
      rtdb.FirebaseDatabase.instance.ref().child('images');
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _filteredImages = [];
  bool _isLoading = false;
  int _limit = 6;
  String? _lastLoadedKey;
  final String _cloudFunctionUrl =
      'https://us-central1-nasaapp-446811.cloudfunctions.net/createThumbnails';

  bool _isCreatingThumbnails = false;


  @override
  void initState() {
    super.initState();
    _fetchImages().then((_) {
      setState(() {
        _filteredImages = List.from(_images);
      });
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

Future<void> _createThumbnail(String imageUrl) async {
  setState(() {
    _isCreatingThumbnails = true;
  });

  try {
    final response = await http.post(
      Uri.parse(_cloudFunctionUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'imageUrl': imageUrl, 'width': 600, 'height': 800}),
    );
    

      // Zwiększenie licznika w Firestore
        final analyticsRef = FirebaseFirestore.instance
            .collection('analytics')
            .doc('create_thumbnails');

        FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(analyticsRef);

          if (snapshot.exists) {
            final currentCounter = snapshot['counter'] ?? 0; // Pobieramy licznik, jeśli istnieje, lub 0
            if (currentCounter is int) {
              transaction.update(analyticsRef, {'counter': currentCounter + 1});
            } else {
              transaction.update(analyticsRef, {'counter': 1}); // Jeśli typ jest niepoprawny, ustawiamy na 1
            }
          } else {
            transaction.set(analyticsRef, {'counter': 1}); // Jeżeli dokument nie istnieje, ustawiamy licznik na 1
          }
        });


    if (response.statusCode == 200) {
      print('Thumbnail created successfully: ${jsonDecode(response.body)}');
    } else {
      print('Failed to create thumbnail: ${response.body}');
    }
  } catch (e) {
    print('Error while creating thumbnail: $e');
  } finally {
    setState(() {
      _isCreatingThumbnails = false;
    });
  }
}



Future<void> _fetchImages({bool loadMore = false}) async {
  if (_isLoading) return;
  
  setState(() {
    _isLoading = true; // Włącz loader przed rozpoczęciem procesu
  });

  try {
    rtdb.Query query = _dbRef.orderByKey().limitToFirst(_limit);
    if (loadMore && _lastLoadedKey != null) {
      query = query.startAfter(_lastLoadedKey);
    }

    final snapshot = await query.get();
    final data = snapshot.value as Map?;

    if (data != null) {
      final List<Map<String, dynamic>> images = [];
      for (var entry in data.entries) {
        final image = Map<String, dynamic>.from(entry.value);
        final id = entry.key;

        image['id'] = id;

        if (_images.any((img) => img['id'] == id)) {
          continue;
        }

        final filePath = image['url'];
        if (filePath != null) {
          final thumbnailPath = 'thumbnails/${Uri.parse(filePath).pathSegments.last}';
          final ref = FirebaseStorage.instance.ref(thumbnailPath);
          try {
            // Sprawdź, czy miniatura istnieje
            final url = await ref.getDownloadURL();
            image['url'] = url;
          } catch (e) {
            // Jeśli miniatura nie istnieje, utwórz ją
            await _createThumbnail(filePath);
            final url = await ref.getDownloadURL();
            image['url'] = url;
          }
          images.add(image);
        }
      }

      // Aktualizacja stanu po zakończeniu całego procesu
      setState(() {
        _images.addAll(images);
        _filteredImages = _images;

        if (images.isNotEmpty) {
          _lastLoadedKey = images.last['id'] as String;
        } else {
          _lastLoadedKey = null;
        }
      });
    }
  } catch (e) {
    print('Error fetching images: $e');
  } finally {
    // Wyłącz loader po zakończeniu procesu
    setState(() {
      _isLoading = false;
    });
  }
}



Future<void> _searchThumbnailsInStorage(String query) async {
  if (query.isEmpty) {
    setState(() {
      _filteredImages = List.from(_images);
    });
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final List<Map<String, dynamic>> results = [];
    final storageRef = FirebaseStorage.instance.ref('thumbnails');
    final ListResult listResult = await storageRef.listAll();

    for (var item in listResult.items) {
      final name = item.name.toLowerCase();
      if (name.contains(query.toLowerCase())) {
        final url = await item.getDownloadURL();
        results.add({
          'url': url,
          'title': _formatTitle(item.name),
        });
      }
    }

    setState(() {
      _filteredImages = results;
    });
  } catch (e) {
    print('Error searching thumbnails in storage: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}


String _formatTitle(String fileName) {
  final nameWithoutExtension = fileName.split('.').first; // Usuwamy rozszerzenie
  return nameWithoutExtension.replaceAll('_', ' '); // Zamieniamy "_" na spacje
}


@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.black,
      title: Row(
        children: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
          SizedBox(width: 10),
          Text('NASA Search App', style: TextStyle(color: Colors.white)),
        ],
      ),
    ),
    body: Container(
      color: Colors.black,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search',
                      labelStyle: TextStyle(color: Colors.white),
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(color: Colors.white),
                    onSubmitted: _searchThumbnailsInStorage,
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () =>
                      _searchThumbnailsInStorage(_searchController.text),
                  child: Text('Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator()) // Loader na czas całego procesu
                : _filteredImages.isEmpty
                    ? Center(
                        child: Text(
                          'No results found',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredImages.length,
                        itemBuilder: (context, index) {
                          final image = _filteredImages[index];
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Image.network(
                                  image['url'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Center(child: Icon(Icons.error)),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8.0),
                                  color: Colors.black54,
                                  child: Text(
                                    image['title'] ?? 'No title',
                                    style: TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          if (!_isLoading && _lastLoadedKey != null)
            ElevatedButton.icon(
              onPressed: () => _fetchImages(loadMore: true),
              icon: Icon(Icons.arrow_downward),
              label: Text('Load More'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            ),
        ],
      ),
    ),
  );
}

}
