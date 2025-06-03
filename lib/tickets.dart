import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'destination.dart'; // Assuming this contains your PickDestinationScreen
import 'profil.dart'; // Assuming this contains your ProfileScreen
import 'package:http/http.dart' as http;
import 'dart:convert';

class BuyTicketsScreen extends StatefulWidget {
  const BuyTicketsScreen({Key? key}) : super(key: key);

  @override
  State<BuyTicketsScreen> createState() => _BuyTicketsScreenState();
}

class _BuyTicketsScreenState extends State<BuyTicketsScreen> {
  bool isNight = false;
  String temperature = "18.7°";
  User? currentUser;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _updateTimeOfDay();
    _fetchWeather();
    _fetchForecast();
    _checkCurrentUser();
  }

  void _checkCurrentUser() {
    setState(() {
      currentUser = _auth.currentUser;
    });
  }

  void _updateTimeOfDay() {
    final hour = DateTime.now().hour;
    setState(() {
      isNight = hour < 6 || hour > 18;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchForecast() async {
    try {
      final response = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?q=Târgu Mureș&appid=4bb92d87ac86b0368216f5e824a81a62&units=metric',
      ));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        List<Map<String, dynamic>> forecast = [];

        for (var item in data['list'].take(5)) {
          forecast.add({
            'time': item['dt_txt'],
            'temp': item['main']['temp'],
            'description': item['weather'][0]['description'],
          });
        }
        return forecast;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<void> _fetchWeather() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?q=Târgu Mureș&appid=4bb92d87ac86b0368216f5e824a81a62&units=metric'));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (mounted) {
          setState(() {
            temperature = "${data['main']['temp']}°";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            temperature = "Err";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          temperature = "Err";
        });
      }
    }
  }

  void _showForecastPopup(
      BuildContext context, List<Map<String, dynamic>> forecast) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        final mediaQuery = MediaQuery.of(context);
        final height = mediaQuery.size.height;

        return Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: mediaQuery.viewInsets.bottom + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: height * 0.8, // Prevent it from taking full screen
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Today Forecast",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...forecast.map(
                    (item) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              item['time'],
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${item['temp']}°C",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  item['description'],
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.end,
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
            ),
          ),
        );
      },
    );
  }

  Future<void> _buyTicket(
      String ticketType, String description, double price) async {
    if (currentUser == null) {
      _showAuthRequiredDialog();
      return;
    }

    // Show confirmation dialog
    bool? confirmed = await _showPurchaseConfirmationDialog(ticketType, price);
    if (confirmed != true) return;

    try {
      // Add ticket to Firestore
      await _firestore.collection('tickets').add({
        'userId': currentUser!.uid,
        'userEmail': currentUser!.email,
        'ticketType': ticketType,
        'description': description,
        'price': price,
        'purchaseDate': FieldValue.serverTimestamp(),
        'isActive': true,
        'expiryDate': ticketType == 'Day Pass'
            ? Timestamp.fromDate(DateTime.now().add(Duration(days: 1)))
            : null,
      });

      _showSuccessDialog(ticketType);
    } catch (e) {
      _showErrorDialog('Failed to purchase ticket: $e');
    }
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2C2C2E),
          title: Text(
            'Login Required',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'You need to login to purchase tickets.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProfileScreen()),
                );
              },
              child: Text('Login', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showPurchaseConfirmationDialog(
      String ticketType, double price) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2C2C2E),
          title: Text(
            'Confirm Purchase',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Do you want to buy a $ticketType ticket for \$${price.toStringAsFixed(2)}?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Buy Now', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String ticketType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2C2C2E),
          title: Text(
            'Purchase Successful!',
            style: TextStyle(color: Colors.green),
          ),
          content: Text(
            'Your $ticketType ticket has been purchased successfully.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2C2C2E),
          title: Text(
            'Error',
            style: TextStyle(color: Colors.red),
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App Bar
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.02,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.confirmation_number,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buy Tickets',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (currentUser != null)
                            Text(
                              'Welcome, ${currentUser!.email?.split('@')[0] ?? 'User'}',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () async {
                      final forecast = await _fetchForecast();
                      if (!context.mounted) return;
                      _showForecastPopup(context, forecast);
                    },
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isNight ? Icons.nights_stay : Icons.wb_sunny,
                            color: isNight ? Colors.blue : Colors.orange,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            temperature,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),

            // Login status indicator
            if (currentUser == null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You need to login to purchase tickets',
                          style: TextStyle(color: Colors.orange, fontSize: 14),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ProfileScreen()),
                          );
                        },
                        child: Text('Login',
                            style: TextStyle(color: Colors.orange)),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            // Destination selection button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenHeight * 0.02,
              ),
              child: _buildModernButton(
                'Select your Destination',
                Icons.place,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PickDestinationScreen(),
                    ),
                  );
                },
                screenWidth,
              ),
            ),

            // Ticket Type section
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Select Ticket Type",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Ticket type cards
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Column(
                children: [
                  _buildTicketCard('Single', 'One-way ride', 2.50, screenWidth),
                  SizedBox(height: 12),
                  _buildTicketCard(
                      'Day Pass', 'Unlimited rides for 24h', 8.00, screenWidth),
                ],
              ),
            ),

            Spacer(),

            // Stats cards
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      "Tickets Bought",
                      "3",
                      Icons.confirmation_number_outlined,
                      Colors.green,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      "Hours Left",
                      "6",
                      Icons.access_time_outlined,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton(
              heroTag: "mapBtn",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PickDestinationScreen(),
                  ),
                );
              },
              backgroundColor: Colors.green,
              child: Icon(
                Icons.map,
                color: Colors.white,
              ),
            ),
            FloatingActionButton(
              heroTag: "profileBtn",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(),
                  ),
                );
              },
              backgroundColor: Colors.green,
              child: Icon(
                Icons.person,
                color: Colors.white,
              ),
            ),
            FloatingActionButton(
              heroTag: "ticketsBtn",
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BuyTicketsScreen(),
                  ),
                );
              },
              backgroundColor: Colors.green,
              child: Icon(
                Icons.shopify_outlined,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernButton(
      String title, IconData icon, VoidCallback onPressed, double screenWidth) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: screenWidth * 0.9,
        height: 60,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
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

  Widget _buildTicketCard(
      String title, String subtitle, double price, double screenWidth) {
    return GestureDetector(
      onTap: () => _buyTicket(title, subtitle, price),
      child: Container(
        width: screenWidth * 0.9,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${price.toStringAsFixed(2)}-Ron',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: currentUser != null ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    currentUser != null ? 'Buy' : 'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      String title, String value, IconData icon, Color color) {
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
