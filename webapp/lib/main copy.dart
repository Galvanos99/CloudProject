import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NASA Search App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(),
    );
  }
}

// Login Screen
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Login failed: ${e.toString()}'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Tło jako animowany GIF
          Positioned.fill(
            child: Image.asset(
              'background.gif', // Ścieżka do pliku GIF
              fit: BoxFit.cover,
            ),
          ),
          // Główna zawartość ekranu
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo aplikacji (większe)
                  Image.asset(
                    'logo.png', // Ścieżka do logo
                    width: MediaQuery.of(context).size.width * 0.5,
                    height: MediaQuery.of(context).size.height * 0.3,
                  ),
                  SizedBox(height: 16),
                  // Nazwa aplikacji
                  Text(
                    'NASA Search App',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 32),
                  // Formularz logowania
                  Container(
                    width: MediaQuery.of(context).size.width * 0.5,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pole e-mail z ikoną @
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.email),
                            hintText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 16),
                        // Pole hasła z ikoną kłódki
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.lock),
                            hintText: 'Password',
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        SizedBox(height: 20),
                        // Przycisk logowania (czarny, większy)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black, // Use backgroundColor instead of primary
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Login',
                              style: TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



// Home Screen
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseReference _dbRef =
      FirebaseDatabase.instance.ref().child('images');
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _filteredImages = [];
  bool _isAdmin = false;

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
      final doc = await FirebaseFirestore.instance
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

  void _fetchImages() async {
    _dbRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        final List<Map<String, dynamic>> images = [];
        for (var entry in data.entries) {
          final image = Map<String, dynamic>.from(entry.value);
          final id = entry.key;

          image['id'] = id; // Dodanie ID do obiektu obrazu
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
        setState(() {
          _images = images;
          _filteredImages = images;
        });
      }
    });
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
                  crossAxisCount: 6, // Updated for 6 images per row
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
          ],
        ),
      ),
    );
  }
}

// Image Detail Screen
class ImageDetailScreen extends StatefulWidget {
  final Map<String, dynamic> image;
  final bool isAdmin;

  const ImageDetailScreen({Key? key, required this.image, required this.isAdmin})
      : super(key: key);

  @override
  _ImageDetailScreenState createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> {
  bool _showDetails = true;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.image['title'] ?? '';
    _descriptionController.text = widget.image['description'] ?? '';
  }

  Future<void> _editImage() async {
    final imageId = widget.image['id'];
    if (imageId != null) {
      await FirebaseDatabase.instance.ref().child('images/$imageId').update({
        'title': _titleController.text,
        'description': _descriptionController.text,
      });
      setState(() {
        widget.image['title'] = _titleController.text;
        widget.image['description'] = _descriptionController.text;
      });
      Navigator.of(context).pop();
    } else {
      print('Image ID is null, cannot update');
    }
  }

  Future<void> _deleteImage() async {
    final imageId = widget.image['id'];
    final imageUrl = widget.image['url'];

    if (imageId != null && imageUrl != null) {
      final confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete this image?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          // Usuń z Firebase Storage
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();

          // Usuń z Firebase Realtime Database
          await FirebaseDatabase.instance.ref().child('images/$imageId').remove();

          // Powrót do poprzedniego ekranu
          Navigator.of(context).pop();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete image: $e')),
          );
        }
      }
    } else {
      print('Image ID or URL is null, cannot delete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.image['url'] ?? '';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.image['title'] ?? '', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.error, color: Colors.white),
              ),
            ),
          ),
          if (_showDetails)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.image['title'] ?? '',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    Text(
                      widget.image['description'] ?? '',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: Icon(_showDetails ? Icons.visibility : Icons.visibility_off, color: Colors.white),
              onPressed: () {
                setState(() {
                  _showDetails = !_showDetails;
                });
              },
            ),
          ),
          if (widget.isAdmin)
            Positioned(
              top: 16,
              right: 70,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteImage,
              ),
            ),
          if (widget.isAdmin)
            Positioned(
              top: 16,
              right: 120,
              child: IconButton(
                icon: Icon(Icons.edit, color: Colors.white),
                onPressed: () async {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('Edit Image'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: _titleController,
                              decoration: InputDecoration(labelText: 'Title'),
                            ),
                            TextField
                            (
                              controller: _descriptionController,
                              decoration: InputDecoration(labelText: 'Description'),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _editImage();
                              Navigator.of(context).pop();
                            },
                            child: Text('Save'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
