import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserScreen extends StatefulWidget {
  final String userId;

  const UserScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isSigningOut = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Felhasználói adatok betöltése a Firestore-ból
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final docSnapshot =
          await _firestore.collection('users').doc(widget.userId).get();

      if (docSnapshot.exists) {
        setState(() {
          _userData = docSnapshot.data();
          _isLoading = false;
        });
      } else {
        _showErrorMessage('User data not found');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorMessage('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Kijelentkezés funkció
  Future<void> _signOut() async {
    // Prevent multiple sign-out attempts
    if (_isSigningOut) return;

    setState(() {
      _isSigningOut = true;
    });

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );

      // Sign out from Firebase
      await _auth.signOut();

      // Close the loading dialog
      if (mounted) Navigator.of(context).pop();

      // Navigate to login screen using pushNamedAndRemoveUntil to clear the navigation stack
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      }
    } catch (e) {
      // Close the loading dialog if it's open
      if (mounted) Navigator.of(context).pop();

      _showErrorMessage('Error signing out: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
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
        title: Text(
          'User Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.green))
            : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: screenHeight * 0.04),
                      Container(
                        width: 120,
                        height: 120,
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
                          size: 60,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      Text(
                        _userData?['name'] ?? 'User',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        _userData?['email'] ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      _buildInfoCard(
                        title: 'Account Information',
                        children: [
                          _buildInfoRow(
                            icon: Icons.person_outline,
                            title: 'Name',
                            value: _userData?['name'] ?? 'Not provided',
                          ),
                          Divider(color: Colors.white.withOpacity(0.1)),
                          _buildInfoRow(
                            icon: Icons.email_outlined,
                            title: 'Email',
                            value: _userData?['email'] ?? 'Not provided',
                          ),
                          Divider(color: Colors.white.withOpacity(0.1)),
                          _buildInfoRow(
                            icon: Icons.calendar_today,
                            title: 'Created At',
                            value: _userData?['createdAt'] != null
                                ? _formatTimestamp(_userData!['createdAt'])
                                : 'Not available',
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      _buildActionButton(
                        title: 'Edit Profile',
                        icon: Icons.edit,
                        onPressed: () {
                          // Profil szerkesztési képernyő megnyitása (ezt később implementálhatod)
                          // Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => EditProfileScreen()));
                        },
                        screenWidth: screenWidth,
                      ),
                      SizedBox(height: 16),
                      _buildActionButton(
                        title: 'Sign Out',
                        icon: Icons.exit_to_app,
                        onPressed: _signOut,
                        screenWidth: screenWidth,
                        isPrimary: false,
                      ),
                      SizedBox(height: screenHeight * 0.05),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // Timestamp formázása olvasható dátummá
  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // Információs kártya widget
  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // Információs sor widget
  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.green,
            size: 22,
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Akció gomb widget
  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    required double screenWidth,
    bool isPrimary = true,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: screenWidth * 0.8,
        height: 56,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? LinearGradient(
                  colors: [
                    Colors.green.withOpacity(0.7),
                    Colors.green.withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: isPrimary
              ? null
              : Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
