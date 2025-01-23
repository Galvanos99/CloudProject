import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_storage/firebase_storage.dart';
import 'image_detail_screen.dart';
import 'login_screen.dart';
import 'home_screen_web_analitic.dart';

class HomeScreenWeb extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreenWeb> {
  final rtdb.DatabaseReference _dbRef =
      rtdb.FirebaseDatabase.instance.ref().child('images');
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _filteredImages = [];
  bool _isAdmin = false;
  bool _isAnalitic = false;
  bool _isLoading = false;
  int _limit = 6; // Number of images per page
  String? _lastLoadedKey; // To track pagination

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _checkAnaliticStatus();
    _fetchImages(); // Wczytujemy pierwsze 6 zdjęć
  }

Future<void> _checkAdminStatus() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final doc = await firestore.FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid) // Używamy uid zamiast prefixu emaila
        .get();
    if (doc.exists) {
      setState(() {
        _isAdmin = doc.data()?['isAdmin'] == true;
      });
    }
  }
}

Future<void> _checkAnaliticStatus() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final doc = await firestore.FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid) // Używamy uid zamiast prefixu emaila
        .get();
    if (doc.exists) {
      setState(() {
        _isAnalitic = doc.data()?['isAnalitic'] == true;
      });
      
      if (_isAnalitic) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreenWebAnalitic()),
        );
      }
    }
  }
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

          final filePath = image['url'];
          if (filePath != null) {
            try {
              final relativePath = filePath.startsWith('http')
                  ? _getRelativePathFromUrl(filePath)
                  : filePath;
              final ref = FirebaseStorage.instance.ref(relativePath);
              final url = await ref.getDownloadURL();
              image['url'] = url;
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

  Future<void> _searchImagesInDatabase(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredImages = _images; // Wyświetl wszystkie zdjęcia jeśli zapytanie jest puste
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
                onSubmitted: _searchImagesInDatabase, // Zmiana na `onSubmitted`
                decoration: InputDecoration(
                  labelText: 'Search',
                  labelStyle: TextStyle(color: Colors.white),
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(color: Colors.white),
              ),
            ),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: _filteredImages.length,
                itemBuilder: (context, index) {
                  final image = _filteredImages[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageDetailScreen(
                            image: image,
                            isAdmin: _isAdmin,
                          ),
                        ),
                      );
                    },
                    child: GridTile(
                      child: Image.network(
                        image['url'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(Icons.error),
                        ),
                      ),
                      footer: GridTileBar(
                        backgroundColor: Colors.black54,
                        title: Center(
                          child: Text(
                            image['title'] ?? 'No title',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
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
