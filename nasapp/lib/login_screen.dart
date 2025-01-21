import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Dla kIsWeb
import 'dart:io' show Platform; // Dla wykrywania platform mobilnych
import 'home_screen_android.dart';
import 'home_screen_web.dart';

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

      // Wykrywanie platformy i przekierowanie na odpowiedni ekran
      if (kIsWeb) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreenWeb()),
        );
      } else if (Platform.isAndroid) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreenAndroid()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Platform not supported!'),
        ));
      }
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
              'assets/background.gif', // Ścieżka do pliku GIF
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
                    'assets/logo.png', // Ścieżka do logo
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.height * 0.5,
                  ),
                  SizedBox(height: 16),
                  // Nazwa aplikacji
                  Text(
                    'NASA Search App',
                    style: TextStyle(
                      fontSize: 48,
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
                      border: Border.all(color: Colors.black, width: 5),
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
                              style: TextStyle(color: Colors.white, fontSize: 20),
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
