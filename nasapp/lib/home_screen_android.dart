import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb; // Alias
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'login_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Adres URL Twojej funkcji Firebase Cloud
const String cloudFunctionUrl = 'https://us-central1-nasaapp-446811.cloudfunctions.net/createThumbnails';

Future<String?> createThumbnail(String imageUrl, int width, int height) async {
  try {
    final response = await http.post(
      Uri.parse(cloudFunctionUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'imageUrl': imageUrl,
        'width': width,
        'height': height,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      // Sprawdzamy, czy URL miniatury został zwrócony
      return responseData['thumbnailUrl'];
    } else {
      print('Failed to create thumbnail: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Error while creating thumbnail: $e');
    return null;
  }
}

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
  int _limit = 6; // Number of images per page
  String? _lastLoadedKey; // To track pagination

  @override
  void initState() {
    super.initState();
    _fetchImages(); // Wczytujemy pierwsze 6 zdjęć
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  String _getRelativePathFromUrl(String fullUrl) {
    Uri uri = Uri.parse(fullUrl);
    return uri.pathSegments.last; // Pobiera ostatni segment, czyli nazwę pliku
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

        // Obsługa ścieżek względnych
        final filePath = image['url'];
        if (filePath != null) {
          try {
            final relativePath = filePath.startsWith('http')
                ? _getRelativePathFromUrl(filePath)
                : filePath;

            final ref = FirebaseStorage.instance.ref(relativePath);
            final url = await ref.getDownloadURL();
            image['url'] = url;

            // Jeśli nie ma miniatury, tworzysz ją
            if (image['thumbnailURL'] == null) {
              final thumbnailUrl = await createThumbnail(image['url'], 600, 800);
              if (thumbnailUrl != null) {
                setState(() {
                  image['thumbnailURL'] = thumbnailUrl;
                });
              }
            }
            images.add(image);
          } catch (e) {
            print('Failed to load image URL for $filePath: $e');
          }
        }
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

  void _searchImagesInDatabase() async {
    String query = _searchController.text.trim();

    if (query.isEmpty) {
      // Jeśli pole wyszukiwania jest puste, resetuj listę obrazów
      setState(() {
        _filteredImages = _images;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Pobieramy wszystkie wpisy z bazy danych, które pasują do frazy wyszukiwania
      final snapshot = await _dbRef.get();
      final data = snapshot.value as Map?;

      if (data != null) {
        final List<Map<String, dynamic>> searchResults = [];
        for (var entry in data.entries) {
          final image = Map<String, dynamic>.from(entry.value);
          final title = image['title']?.toLowerCase() ?? '';
          final description = image['description']?.toLowerCase() ?? '';

          // Porównujemy tytuły i opisy z frazą wyszukiwania
          if (title.contains(query.toLowerCase()) ||
              description.contains(query.toLowerCase())) {
            image['id'] = entry.key;

            // Pobieramy URL zdjęcia, aby wyświetlić go w aplikacji
            final filePath = image['url'];
            if (filePath != null) {
              try {
                final relativePath = filePath.startsWith('http')
                    ? _getRelativePathFromUrl(filePath)
                    : filePath;
                final ref = FirebaseStorage.instance.ref(relativePath);
                final url = await ref.getDownloadURL();
                image['url'] = url;
                searchResults.add(image);
              } catch (e) {
                print('Failed to load image URL for $filePath: $e');
              }
            }
          }
        }

        // Aktualizujemy listę obrazów w stanie
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
                onSubmitted: (_) {
                  // Wywołujemy wyszukiwanie tylko po naciśnięciu "Enter"
                  _searchImagesInDatabase();
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredImages.length,
                itemBuilder: (context, index) {
                  final image = _filteredImages[index];
                  final thumbnailUrl = image['thumbnailURL'] ?? image['url'];  // Użyj miniatury, jeśli istnieje

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular( 8 ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.network(
                          thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(Icons.error),
                          ),
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
