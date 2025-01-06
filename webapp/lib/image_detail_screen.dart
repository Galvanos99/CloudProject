import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
              boundaryMargin: EdgeInsets.fromLTRB(140, 140, 140, 140), // Pozwala obrazowi wychodzić poza granice
              clipBehavior: Clip.none, // Zapobiega przycinaniu obrazu
              minScale: 1.0, // Minimalne skalowanie (oddalanie)
              maxScale: 5.0, // Maksymalne skalowanie (przybliżanie)
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