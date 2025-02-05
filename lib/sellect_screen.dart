import 'package:bus_tracking/destination.dart';
import 'package:bus_tracking/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SellectScreen extends StatefulWidget {
  const SellectScreen({super.key});

  @override
  State<SellectScreen> createState() => _SellectScreenState();
}

class _SellectScreenState extends State<SellectScreen>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: screenHeight * 0.11,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3A3A3C), Color(0xFF1C1C1E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.directions_bus, color: Colors.white, size: 28),
            SizedBox(width: 10),
            Text(
              'Bus Tracking',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.05),
                _buildAnimatedButton(
                  'Select your Destination',
                  () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => PickDestinationScreen(),
                      ),
                    );
                  },
                  screenWidth,
                ),
                SizedBox(height: screenHeight * 0.03),
                const Text(
                  "Track bus with number:",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    letterSpacing: 1.1,
                    shadows: [
                      Shadow(
                        offset: Offset(2.0, 2.0),
                        blurRadius: 3.0,
                        color: Color.fromARGB(150, 0, 0, 0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.03),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                clipBehavior: Clip.none,
                children: [
                  _buildBusButton('23', screenWidth, () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => HomrScreen(
                          destinationLat: 0.0,
                          destinationLng: 0.0,
                          route: 'routes_23.json',
                          busNumber: '23',
                        ),
                      ),
                    );
                  }),
                  _buildBusButton('43', screenWidth, () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => HomrScreen(
                          destinationLat: 0.0,
                          destinationLng: 0.0,
                          route: 'routes_43.json',
                          busNumber: '43',
                        ),
                      ),
                    );
                  }),
                  _buildBusButton('44', screenWidth, () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => HomrScreen(
                          destinationLat: 0.0,
                          destinationLng: 0.0,
                          route: 'routes_44.json',
                          busNumber: '44',
                        ),
                      ),
                    );
                  }),
                  _buildBusButton('21', screenWidth, () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => HomrScreen(
                          destinationLat: 0.0,
                          destinationLng: 0.0,
                          route: 'routes_21.json',
                          busNumber: '21',
                        ),
                      ),
                    );
                  }),
                  _buildBusButton('6', screenWidth, () {
                    _showUnavailableDialog(context);
                  }),
                  _buildBusButton('26', screenWidth, () {
                    _showUnavailableDialog(context);
                  }),
                ],
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent
                    ],
                    stops: [0.0, 0.3, 0.6, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: SizedBox(
                  height: 300,
                  child: LottieBuilder.asset(
                    'assets/bus1.json',
                    width: constraints.maxWidth,
                    repeat: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedButton(
      String title, VoidCallback onPressed, double screenWidth) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: screenWidth * 0.8,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF4A4A4C),
              Color(0xFF303033),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF000000),
              offset: Offset(4, 4),
              blurRadius: 8,
            ),
          ],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusButton(
      String busNumber, double screenWidth, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: 15, vertical: 10), // Space for shadow
        width: screenWidth * 0.35, // Responsive width
        height: screenWidth * 0.35, // Square shape
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A4A4C), Color(0xFF303033)], // Dark theme colors
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              offset: const Offset(4, 4),
              blurRadius: 12,
            ),
          ],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            busNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  void _showUnavailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2E),
          title: const Text(
            "Bus Unavailable",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "This bus is currently not ready for tracking.",
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                "OK",
                style: TextStyle(color: Color(0xFF4A90E2)),
              ),
            ),
          ],
        );
      },
    );
  }
}
