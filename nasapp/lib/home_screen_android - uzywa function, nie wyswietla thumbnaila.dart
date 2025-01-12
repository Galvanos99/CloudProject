import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http; // Do wywołań HTTP
import 'dart:convert';
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

  final String cloudFunctionUrl =
      "https://us-central1-nasaapp-446811.cloudfunctions.net/createThumbnails";

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

Future<void> _fetchImages({bool loadMore = false}) async {
  if (_isLoading) return;
  setState(() {
    _isLoading = true;
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

        final thumbnailPath = image['thumbnailURL'] ?? '';
        if (thumbnailPath.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.ref('thumbnails/${image['id']}');
          final url = await ref.getDownloadURL();
          image['thumbnailURL'] = url;

          // Debugowanie: loguj znalezione miniatury
          print('Thumbnail exists for ID ${image['id']}: $url');
        } catch (e) {
          print('Thumbnail not found for ID ${image['id']}, creating...');
          await _createThumbnail(image);
        }

      } else {
        print('Thumbnail URL missing, creating thumbnail.');
        await _createThumbnail(image);
              }

              images.add(image);
      }

      setState(() {
        _images.addAll(images);
        _filteredImages = _images;
        if (images.isNotEmpty) {
          _lastLoadedKey = images.last['id'] as String;
        }
      });
    }
  } catch (e) {
    print('Error fetching images: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}


Future<void> _createThumbnail(Map<String, dynamic> image) async {
  final imageUrl = image['url'];
  if (imageUrl == null || imageUrl.isEmpty) return;

 print('Creating thumbnail for image URL: $imageUrl');
try {
  final decodedImageUrl = Uri.decodeComponent(imageUrl);
  print('Decoded image URL: $decodedImageUrl');

  final response = await http.post(
    Uri.parse(cloudFunctionUrl),
    headers: {'Content-Type': 'application/json'},
    body: json.encode({
      'imageUrl': decodedImageUrl,
      'width': 600,
      'height': 800,
    }),
  );

  print('Cloud Function response: ${response.body}');
  if (response.statusCode == 200) {
    final result = json.decode(response.body);
    final thumbnailPath = result['thumbnailPath']; // Zwrócona ścieżka z Cloud Function
    print('Cloud Function returned thumbnailPath: $thumbnailPath');

    if (thumbnailPath != null) {
      final ref = FirebaseStorage.instance.ref(thumbnailPath);
      final url = await ref.getDownloadURL();
      print('Generated thumbnail URL: $url');

      // Zapisz URL miniatury w Firebase Database
      final id = image['id'];
      if (id == null) return;

      try {
        // Sprawdź, czy miniatura już istnieje
        final ref = FirebaseStorage.instance.ref('thumbnails/$id');
        final url = await ref.getDownloadURL();

        // Miniatura istnieje, zapisz URL w bazie danych
        print('Thumbnail already exists for ID $id: $url');
        await _dbRef.child(id).update({'thumbnailURL': url});

        setState(() {
          image['thumbnailURL'] = url;
        });
        return; // Nie twórz nowej miniatury
      } catch (e) {
        print('Thumbnail not found for ID $id, creating new thumbnail...');
      }

      if (id != null) {
        print('Saving thumbnail URL in database for ID: $id');
        await _dbRef.child(id).update({'thumbnailURL': url});
      }

      // Aktualizuj lokalny stan
      setState(() {
        image['thumbnailURL'] = url;
      });
    }
  } else {
    print('Failed to create thumbnail: ${response.body}');
  }
} catch (e) {
  print('Error creating thumbnail: $e');
}

}



  void _searchImagesInDatabase() async {
    String query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _filteredImages = _images;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _dbRef.get();
      final data = snapshot.value as Map?;

      if (data != null) {
        final List<Map<String, dynamic>> searchResults = [];
        for (var entry in data.entries) {
          final image = Map<String, dynamic>.from(entry.value);
          final title = image['title']?.toLowerCase() ?? '';
          final description = image['description']?.toLowerCase() ?? '';

          if (title.contains(query.toLowerCase()) ||
              description.contains(query.toLowerCase())) {
            image['id'] = entry.key;

            final thumbnailPath = image['thumbnailURL'] ?? '';
            if (thumbnailPath.isNotEmpty) {
              try {
                final ref = FirebaseStorage.instance.refFromURL(thumbnailPath);
                final url = await ref.getDownloadURL();
                image['thumbnailURL'] = url;

                // Debugowanie: loguj miniatury wyników wyszukiwania
                print('Search result thumbnail for ID ${image['id']}: $url');
                searchResults.add(image);
              } catch (e) {
                print('Thumbnail not found for search result, creating: $thumbnailPath');
                await _createThumbnail(image);
              }
            } else {
              print('Thumbnail URL missing for search result, creating thumbnail.');
              await _createThumbnail(image);
            }

          }
        }

        setState(() {
          _filteredImages = searchResults;
        });
      }
    } catch (e) {
      print('Error during search: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search',
                  labelStyle: TextStyle(color: Colors.white),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(color: Colors.white),
                onSubmitted: (_) => _searchImagesInDatabase(),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredImages.length,
                itemBuilder: (context, index) {
                  final image = _filteredImages[index];
                  final thumbnailUrl = image['thumbnailURL'];

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        thumbnailUrl != null && thumbnailUrl.isNotEmpty
                        ? Image.network(
                            thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading thumbnail: $thumbnailUrl');
                              return Center(child: Icon(Icons.error));
                            },
                          )
                        : Center(
                            child: CircularProgressIndicator(),
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

            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            if (!_isLoading && _filteredImages.length >= _limit)
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
