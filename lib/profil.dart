import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Profile',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF1C1C1E),
      ),
      home: ProfileScreen(),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  // Firebase szolgáltatások inicializálása
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Ellenőrizzük, hogy a felhasználó már be van-e jelentkezve
    // Use WidgetsBinding to ensure navigation happens after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCurrentUser();
    });
  }

  // A felhasználó bejelentkezési állapotának ellenőrzése induláskor
  Future<void> _checkCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null && mounted) {
      // Ha a felhasználó már be van jelentkezve, átirányítjuk a UserScreen-re
      _navigateToUserScreen(user);
    }
  }

  // Átirányítás a UserScreen-re
  void _navigateToUserScreen(User user) {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => UserScreen(userId: user.uid),
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  Future<void> _submitForm() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Alapvető validáció
    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar('Please fill in all required fields');
      return;
    }

    // Regisztráció esetén ellenőrizzük a nevet is
    if (!_isLogin && _nameController.text.trim().isEmpty) {
      _showErrorSnackBar('Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        // Bejelentkezés meglévő fiókkal
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        _showSuccessSnackBar('Login successful!');

        // Sikeres bejelentkezés után átirányítás a UserScreen-re
        _navigateToUserScreen(userCredential.user!);
      } else {
        // Új fiók létrehozása
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Felhasználói profil adatok mentése Firestore-ba
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });

        _showSuccessSnackBar('Account created successfully!');

        // Sikeres regisztráció után átirányítás a UserScreen-re
        _navigateToUserScreen(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Authentication failed';

      // Részletes hibaüzenetek a különböző esetekre
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'The email address is already in use';
      } else if (e.code == 'weak-password') {
        errorMessage = 'The password is too weak';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address';
      }

      _showErrorSnackBar(errorMessage);
    } catch (e) {
      _showErrorSnackBar('Error occurred: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight * 0.04),
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.green,
                      size: 50,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),
                Center(
                  child: Text(
                    _isLogin ? 'Login to Your Account' : 'Create New Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),
                // Név mező csak regisztrációnál jelenik meg
                if (!_isLogin) ...[
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Name',
                    icon: Icons.person,
                  ),
                  SizedBox(height: 16),
                ],
                _buildTextField(
                  controller: _emailController,
                  hint: 'Email',
                  icon: Icons.email,
                ),
                SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordController,
                  hint: 'Password',
                  icon: Icons.lock,
                  isPassword: true,
                ),
                SizedBox(height: 24),
                Center(
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.green)
                      : _buildAuthButton(
                          _isLogin ? 'Login' : 'Sign Up',
                          _submitForm,
                          screenWidth,
                        ),
                ),
                SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _toggleAuthMode,
                    child: Text(
                      _isLogin
                          ? 'Don\'t have an account? Sign Up'
                          : 'Already have an account? Login',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: Colors.white),
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: Colors.green),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildAuthButton(
      String title, VoidCallback onPressed, double screenWidth) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: screenWidth * 0.8,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.withOpacity(0.7),
              Colors.green.withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
