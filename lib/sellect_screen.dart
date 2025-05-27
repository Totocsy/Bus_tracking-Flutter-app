import 'package:bus_tracking/destination.dart';
import 'package:bus_tracking/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SellectScreen extends StatefulWidget {
  const SellectScreen({super.key});

  @override
  State<SellectScreen> createState() => _SellectScreenState();
}

class _SellectScreenState extends State<SellectScreen>
    with SingleTickerProviderStateMixin {
  bool isNight = false;
  String temperature = "Load";

  @override
  void initState() {
    super.initState();
    _updateTimeOfDay();
    _fetchWeather();
  }

  void _updateTimeOfDay() {
    final hour = DateTime.now().hour;
    setState(() {
      isNight = hour < 6 || hour > 18;
    });
  }

  Future<void> _fetchWeather() async {
    final response = await http.get(Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?q=Târgu Mureș&appid=4bb92d87ac86b0368216f5e824a81a62&units=metric'));

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      setState(() {
        temperature = "${data['main']['temp']}°";
      });
    } else {
      setState(() {
        temperature = "Err";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2C2C2E),
                  Color(0xFF1C1C1E),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
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
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.directions_bus,
                              color: Colors.green,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Bus Tracking',
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
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: screenHeight * 0.03,
                  ),
                  child: _buildModernButton(
                    'Select your Destination',
                    Icons.place,
                    () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => PickDestinationScreen(),
                        ),
                      );
                    },
                    screenWidth,
                  ),
                ),
                Container(
                  height: screenHeight * 0.5,
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Colors.white,
                          Colors.white.withOpacity(0.1),
                          Colors.transparent
                        ],
                        stops: [1.0, 1.0, 1.0, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.05,
                            vertical: screenHeight * 0.02,
                          ),
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
                                "Available Routes",
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
                        Expanded(
                          child: GridView.count(
                            scrollDirection: Axis.horizontal,
                            crossAxisCount: 1,
                            padding: EdgeInsets.all(screenWidth * 0.05),
                            mainAxisSpacing: 20,
                            children: [
                              _buildModernBusButton(
                                  '23',
                                  'Autogara Transport Local → SMURD',
                                  screenWidth, () {
                                _navigateToBus('23', 'routes_23.json');
                              }),
                              _buildModernBusButton(
                                  '43',
                                  'Autogara Transport Local → Tudor',
                                  screenWidth, () {
                                _navigateToBus('43', 'routes_43.json');
                              }),
                              _buildModernBusButton(
                                  '44', 'Sapientia → Combinat', screenWidth,
                                  () {
                                _navigateToBus('44', 'routes_44.json');
                              }),
                              _buildModernBusButton(
                                  '21', 'Str. 8 Martie → Centru', screenWidth,
                                  () {
                                _navigateToBus('21', 'routes_21.json');
                              }),
                              _buildModernBusButton(
                                  '6', '→ Coming Soon', screenWidth, () {
                                _showUnavailableDialog(context);
                              }),
                              _buildModernBusButton(
                                  '26', '→ Coming Soon', screenWidth, () {
                                _showUnavailableDialog(context);
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.1),
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.1, 0.8, 1.1],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: LottieBuilder.asset(
                      'assets/bus1.json',
                      repeat: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildModernBusButton(String busNumber, String destination,
      double screenWidth, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              busNumber,
              style: TextStyle(
                color: Colors.white,
                fontSize: 50,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              destination,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBus(String busNumber, String route) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomrScreen(
          destinationLat: 0.0,
          destinationLng: 0.0,
          route: route,
          busNumber: busNumber,
        ),
      ),
    );
  }

  void _showUnavailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF2C2C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                "Coming Soon",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            "This route is currently under development and will be available soon.",
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Got it",
                style: TextStyle(color: Colors.green),
              ),
            ),
          ],
        );
      },
    );
  }
}
