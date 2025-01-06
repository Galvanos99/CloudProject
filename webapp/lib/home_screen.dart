import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb; // Alias
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore; // Alias
import 'package:firebase_storage/firebase_storage.dart';
import 'image_detail_screen.dart';
import 'login_screen.dart';

// Home Screen
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final rtdb.DatabaseReference _dbRef =
      rtdb.FirebaseDatabase.instance.ref().child('images');
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _filteredImages = [];
  bool _isAdmin = false;
  bool _isLoading = false;
  int _limit = 6; // Number of images per page
  String? _lastLoadedKey; // To track pagination

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _fetchImages();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final emailPrefix = user.email?.split('@')[0] ?? '';
      final doc = await firestore.FirebaseFirestore.instance
          .collection('users')
          .doc(emailPrefix)
          .get();
      if (doc.exists) {
        setState(() {
          _isAdmin = doc.data()?['isAdmin'] == true;
        });
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

Future<void> _fetchImages({bool loadMore = false}) async {
  if (_isLoading) return; // Zapobiegamy wielokrotnym jednoczesnym ładowaniom
  setState(() {
    _isLoading = true;
  });

  try {
    // Przygotowanie zapytania do bazy danych
    rtdb.Query query = _dbRef.orderByKey().limitToFirst(_limit);
    if (loadMore && _lastLoadedKey != null) {
      // Użycie `startAfter` tylko, gdy `_lastLoadedKey` jest prawidłowy
      query = query.startAfter(_lastLoadedKey);
    }

    // Pobranie danych z Firebase Realtime Database
    final snapshot = await query.get();
    final data = snapshot.value as Map?;

    if (data != null) {
      final List<Map<String, dynamic>> images = [];
      for (var entry in data.entries) {
        final image = Map<String, dynamic>.from(entry.value);
        final id = entry.key;

        image['id'] = id;
        final fileName = image['url'];
        if (fileName != null) {
          try {
            final ref = FirebaseStorage.instance.ref().child(fileName);
            final url = await ref.getDownloadURL();
            image['url'] = url;
            images.add(image);
          } catch (e) {
            print('Failed to load image URL for $fileName: $e');
          }
        }
      }

      // Aktualizacja stanu aplikacji
      setState(() {
        _images.addAll(images);
        _filteredImages = _images;
        if (images.isNotEmpty) {
          _lastLoadedKey = images.last['id'] as String; // Upewnijmy się, że to String
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



  void _filterImages(String query) {
    final filtered = _images.where((image) {
      final title = image['title']?.toLowerCase() ?? '';
      final description = image['description']?.toLowerCase() ?? '';
      return title.contains(query.toLowerCase()) ||
          description.contains(query.toLowerCase());
    }).toList();

    setState(() {
      _filteredImages = filtered;
    });
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
                onChanged: _filterImages,
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
