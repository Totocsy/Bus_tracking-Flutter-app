import 'package:bus_tracking/destination.dart';
import 'package:bus_tracking/home_screen.dart';
import 'package:bus_tracking/profil.dart';
import 'package:bus_tracking/tickets.dart';
import 'package:flutter/material.dart';
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

  // List of active buses with their details
  final List<Map<String, dynamic>> activeBuses = [
    {
      'number': '23',
      'route': 'Transport Local - SMURD',
      'status': 'On Time',
      'nextStop': 'Central Station',
      'eta': '2 min'
    },
    {
      'number': '43',
      'route': 'Transport Local - Tudor',
      'status': 'On Time',
      'nextStop': 'Piața Victoriei',
      'eta': '5 min'
    },
    {
      'number': '44',
      'route': 'Sapientia - Combinat',
      'status': 'Delayed',
      'nextStop': 'University',
      'eta': '7 min'
    },
    {
      'number': '21',
      'route': 'Str. 8 Martie - Centru',
      'status': 'On Time',
      'nextStop': 'Municipal Hospital',
      'eta': '3 min'
    },
    {
      'number': '43',
      'route': 'Transport Local - Tudor',
      'status': 'On Time',
      'nextStop': 'Theater',
      'eta': '10 min'
    },
    {
      'number': '23',
      'route': 'Transport Local - SMURD',
      'status': 'On Time',
      'nextStop': 'Shopping Mall',
      'eta': '12 min'
    },
  ];

  @override
  void initState() {
    super.initState();
    _updateTimeOfDay();
    _fetchWeather();
    _fetchForecast();
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
          // just show next 5 forecasts
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
                Container(
                  height: screenHeight * 0.5,
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
                        child: GridView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.all(screenWidth * 0.05),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            childAspectRatio: 1.5,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                          ),
                          itemCount: 6,
                          itemBuilder: (context, index) {
                            final routes = [
                              [
                                '23',
                                'Transport Local - SMURD',
                                'routes_23.json'
                              ],
                              [
                                '43',
                                'Transport Local - Tudor',
                                'routes_43.json'
                              ],
                              ['44', 'Sapientia - Combinat', 'routes_44.json'],
                              [
                                '21',
                                'Str. 8 Martie - Centru',
                                'routes_21.json'
                              ],
                              ['6', '→ Coming Soon', ''],
                              ['26', '→ Coming Soon', ''],
                            ];
                            return _buildModernBusButton(
                              routes[index][0],
                              routes[index][1],
                              screenWidth,
                              () {
                                if (index < 4) {
                                  _navigateToBus(
                                      routes[index][0], routes[index][2]);
                                } else {
                                  _showUnavailableDialog(context);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -50,
                          bottom: -50,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.green.withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GestureDetector(
                              onTap: () {
                                _showActiveBusesDialog(context);
                              },
                              child: _buildInfoCard(
                                "Active Buses",
                                "6",
                                Icons.directions_bus_outlined,
                                Colors.green,
                              ),
                            ),
                            _buildInfoCard(
                              "On Time Arrival",
                              "95%",
                              Icons.timer_outlined,
                              Colors.blue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Update the FloatingActionButton implementation to fix stack overflow
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

  void _showActiveBusesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions_bus,
                        color: Colors.green,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Active Buses',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Total: 6',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: activeBuses.length,
                    itemBuilder: (context, index) {
                      final bus = activeBuses[index];
                      final isOnTime = bus['status'] == 'On Time';

                      // Determine the route file based on bus number
                      String routeFile = 'routes_${bus['number']}.json';

                      return GestureDetector(
                        onTap: () {
                          // Close the dialog first
                          Navigator.of(context).pop();

                          // Navigate to the home screen with the selected bus
                          _navigateToBus(bus['number'], routeFile);
                        },
                        child: Container(
                          margin:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  bus['number'],
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              bus['route'],
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Next: ${bus['nextStop']} • ETA: ${bus['eta']}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isOnTime
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    bus['status'],
                                    style: TextStyle(
                                      color: isOnTime
                                          ? Colors.green
                                          : Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Close',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      width: 140,
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

  // Fixed navigation method to avoid stack overflow
  void _navigateToBus(String busNumber, String route) {
    // Use push instead of pushReplacement
    Navigator.of(context).push(
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
