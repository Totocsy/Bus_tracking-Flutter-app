import 'package:flutter/material.dart';
import 'destination.dart'; // Assuming this contains your PickDestinationScreen
import 'profil.dart'; // Assuming this contains your ProfileScreen

class BuyTicketsScreen extends StatefulWidget {
  const BuyTicketsScreen({Key? key}) : super(key: key);

  @override
  State<BuyTicketsScreen> createState() => _BuyTicketsScreenState();
}

class _BuyTicketsScreenState extends State<BuyTicketsScreen> {
  bool isNight = false;
  String temperature = "18.7°";

  @override
  void initState() {
    super.initState();
    _updateTimeOfDay();
  }

  void _updateTimeOfDay() {
    final hour = DateTime.now().hour;
    setState(() {
      isNight = hour < 6 || hour > 18;
    });
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
                      Text(
                        'Buy Tickets',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                ],
              ),
            ),

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
                  // Use push instead of pushReplacement to avoid stack overflow
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
                  _buildTicketCard('Single', 'One-way ride', screenWidth),
                  SizedBox(height: 12),
                  _buildTicketCard(
                      'Day Pass', 'Unlimited rides for 24h', screenWidth),
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
                      "Tickets Left",
                      "3",
                      Icons.confirmation_number_outlined,
                      Colors.green,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      "Days Left",
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
      // Bottom Navigation Bar
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

  Widget _buildTicketCard(String title, String subtitle, double screenWidth) {
    return Container(
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
