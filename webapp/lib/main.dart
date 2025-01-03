import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
        apiKey: "AIzaSyCzcBJXY5tjmq2r_dDwNXXW54-3PhRlEVs",
        authDomain: "cloudproject-bda5e.firebaseapp.com",
        projectId: "cloudproject-bda5e",
        storageBucket: "cloudproject-bda5e.firebasestorage.app",
        messagingSenderId: "52378970196",
        appId: "1:52378970196:web:5aea3b07e55812f770e5c1",
        measurementId: "G-JR3HPNQLQS"),
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galeria Firebase',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Logowanie')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Hasło'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  UserCredential userCredential =
                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                    email: emailController.text,
                    password: passwordController.text,
                  );

                  // Przejście do galerii po zalogowaniu
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            GalleryPage(user: userCredential.user)),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logowanie nie powiodło się: $e')),
                  );
                }
              },
              child: Text('Zaloguj się'),
            ),
          ],
        ),
      ),
    );
  }
}

class GalleryPage extends StatelessWidget {
  final User? user;
  GalleryPage({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Galeria'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
          )
        ],
      ),
      body: FutureBuilder(
        future: FirebaseStorage.instance.ref('IMAGES/OG').listAll(),
        builder: (context, AsyncSnapshot<ListResult> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Wystąpił błąd: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.items.isEmpty) {
            return Center(child: Text('Brak zdjęć w katalogu'));
          }

          final files = snapshot.data!.items;

          return GridView.builder(
            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
            itemCount: files.length,
            itemBuilder: (context, index) {
              return FutureBuilder(
                future: files[index].getDownloadURL(),
                builder: (context, AsyncSnapshot<String> urlSnapshot) {
                  if (urlSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (urlSnapshot.hasError) {
                    return Center(child: Icon(Icons.error));
                  } else {
                    return Image.network(urlSnapshot.data!, fit: BoxFit.cover);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}