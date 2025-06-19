import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'sellect_screen.dart';
import 'ml_traffic_service.dart'; // Import the ML service

class HomrScreen extends StatefulWidget {
  final double destinationLat;
  final double destinationLng;
  final String route;
  final String busNumber;

  const HomrScreen({
    Key? key,
    required this.destinationLat,
    required this.destinationLng,
    required this.route,
    required this.busNumber,
  }) : super(key: key);

  @override
  State<HomrScreen> createState() => _HomrScreenState();
}

class _HomrScreenState extends State<HomrScreen> {
  List<LatLng> polylineCoordinates = [];
  LocationData? currentLocation;
  MapController mapController = MapController();
  double? estimatedArrivalTime;
  double? currentSpeed;
  bool followBus = false;
  bool _isConnected = false;

  late double destinationLat;
  late double destinationLng;

  LatLng _busPosition = LatLng(46.54245, 24.55747);
  LatLng? _previousBusPosition;
  StreamSubscription? _streamSubscription;
  final String serverUrl = "https://bus-api-7ph1.onrender.com";
  DateTime? _lastUpdateTime;
  DateTime? _previousUpdateTime;

  List<double> _speedHistory = [];
  static const int maxSpeedHistoryLength = 5;
  static const double minDistanceForSpeedCalc = 0.005;
  static const double maxRealisticSpeed = 80.0;
  static const double minRealisticSpeed = 0.0;

  static const double averageBusSpeedKmph = 25;

  late MLTrafficService _mlService;
  bool _showMLCard = false;

  @override
  void initState() {
    super.initState();
    destinationLat = widget.destinationLat;
    destinationLng = widget.destinationLng;

    _mlService = MLTrafficService();
    _mlService.onTrafficUpdate =
        (currentTraffic, prediction, confidence, isLoading) {
      if (mounted) {
        setState(() {});
      }
    };

    getCurrentLocation();
    _startTrackingBus();
    _initializeMLSystem();
  }

  // Initialize ML system
  void _initializeMLSystem() async {
    await _mlService.initializeMLSystem();
    _mlService.startMLPeriodicUpdate();
  }

  double calculateDistance(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    const double earthRadius = 6371;
    final double dLat = _degreesToRadians(endLatitude - startLatitude);
    final double dLon = _degreesToRadians(endLongitude - startLongitude);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(startLatitude)) *
            cos(_degreesToRadians(endLatitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  double calculateEstimatedArrivalTime() {
    if (currentLocation == null) return 0.0;

    double distanceToDestination = calculateDistance(
        _busPosition.latitude,
        _busPosition.longitude,
        currentLocation!.latitude!,
        currentLocation!.longitude!);

    double speedToUse = currentSpeed ?? averageBusSpeedKmph;
    if (speedToUse < 5) speedToUse = averageBusSpeedKmph;

    double estimatedTimeInMinutes = (distanceToDestination / speedToUse) * 60;

    return estimatedTimeInMinutes;
  }

  double? _calculateRealTimeBusSpeed() {
    if (_previousBusPosition == null ||
        _lastUpdateTime == null ||
        _previousUpdateTime == null) {
      return null;
    }

    double timeDiffInSeconds =
        _lastUpdateTime!.difference(_previousUpdateTime!).inMilliseconds /
            1000.0;

    if (timeDiffInSeconds < 1.0) {
      return currentSpeed;
    }

    double distanceKm = calculateDistance(
      _previousBusPosition!.latitude,
      _previousBusPosition!.longitude,
      _busPosition.latitude,
      _busPosition.longitude,
    );

    if (distanceKm < minDistanceForSpeedCalc) {
      return currentSpeed;
    }

    double speedKmph = (distanceKm / timeDiffInSeconds) * 3600;

    if (speedKmph < minRealisticSpeed || speedKmph > maxRealisticSpeed) {
      return currentSpeed;
    }

    _speedHistory.add(speedKmph);
    if (_speedHistory.length > maxSpeedHistoryLength) {
      _speedHistory.removeAt(0);
    }

    double smoothedSpeed =
        _speedHistory.reduce((a, b) => a + b) / _speedHistory.length;

    return smoothedSpeed;
  }

  void getCurrentLocation() async {
    Location location = Location();
    location.getLocation().then((location) {
      if (mounted) {
        setState(() {
          currentLocation = location;
        });
      }
    });

    location.onLocationChanged.listen((newLoc) {
      if (mounted) {
        setState(() {
          currentLocation = newLoc;
          estimatedArrivalTime = calculateEstimatedArrivalTime();
        });
      }
    });
  }

  void _startTrackingBus() async {
    setState(() {
      _isConnected = false;
    });

    await _streamSubscription?.cancel();

    try {
      final Uri url = Uri.parse('$serverUrl/bus/${widget.busNumber}/movement');
      final request = http.Request('GET', url);
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final client = http.Client();
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        print('Error: Server returned ${streamedResponse.statusCode}');
        _reconnectAfterDelay();
        return;
      }

      setState(() {
        _isConnected = true;
      });

      _streamSubscription = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
        if (line.startsWith('data: ')) {
          try {
            final jsonData = json.decode(line.substring(6));

            if (jsonData.containsKey('lat') && jsonData.containsKey('lon')) {
              final double lat = double.parse(jsonData['lat'].toString());
              final double lon = double.parse(jsonData['lon'].toString());
              final newPosition = LatLng(lat, lon);

              setState(() {
                // Store previous position and time for speed calculation
                _previousBusPosition = _busPosition;
                _previousUpdateTime = _lastUpdateTime;

                // Update current position and time
                _busPosition = newPosition;
                _lastUpdateTime = DateTime.now();

                // Add to polyline (keep last 100 points for performance)
                polylineCoordinates.add(newPosition);
                if (polylineCoordinates.length > 100) {
                  polylineCoordinates = polylineCoordinates
                      .sublist(polylineCoordinates.length - 100);
                }

                // Calculate real-time speed
                double? newSpeed = _calculateRealTimeBusSpeed();
                if (newSpeed != null) {
                  currentSpeed = newSpeed;
                }

                // Update arrival time with new speed
                estimatedArrivalTime = calculateEstimatedArrivalTime();

                // Follow bus if enabled
                if (followBus) {
                  mapController.move(_busPosition, mapController.camera.zoom);
                }
              });
            }
          } catch (e) {
            print('Error parsing SSE data: $e');
          }
        }
      }, onError: (error) {
        print('Stream error: $error');
        setState(() {
          _isConnected = false;
        });
        _reconnectAfterDelay();
      }, onDone: () {
        print('Stream closed');
        setState(() {
          _isConnected = false;
        });
        _reconnectAfterDelay();
      });
    } catch (e) {
      print('Connection error: $e');
      setState(() {
        _isConnected = false;
      });
      _reconnectAfterDelay();
    }
  }

  void _reconnectAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _startTrackingBus();
      }
    });
  }

  // Enhanced ML kártya építése
  Widget _buildMLTrafficCard() {
    if (_mlService.isMLLoading) {
      return _buildMLLoadingCard();
    }

    final currentLevel = _mlService.getTrafficLevel(_mlService.currentTraffic);
    final predictedLevel = _mlService.getTrafficLevel(_mlService.prediction);

    return Container(
      margin: EdgeInsets.all(30),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 49, 49, 49).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Traffic Prediction',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(2.0, 2.0),
                          blurRadius: 10.0,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'AI+',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Jelenlegi forgalom
          Row(
            children: [
              Icon(Icons.people, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'Now: ${_mlService.currentTraffic} Passanger',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: currentLevel.backgroundColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: currentLevel.color, width: 1),
                ),
                child: Text(
                  currentLevel.level,
                  style: TextStyle(
                    fontSize: 10,
                    color: currentLevel.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          // Előrejelzés
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Text(
                'Next hour: ${_mlService.prediction} passanger',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              SizedBox(width: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: predictedLevel.backgroundColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: predictedLevel.color, width: 1),
                ),
                child: Text(
                  predictedLevel.level,
                  style: TextStyle(
                    fontSize: 8,
                    color: predictedLevel.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          // ML adatok
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Conficence: ${_mlService.confidence}%',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Learning data: ${_mlService.historicalData.length}',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ML betöltő kártya
  Widget _buildMLLoadingCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 49, 49, 49).withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'AI modell betöltés és tanulás...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _mlService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: LatLng(46.54245, 24.55747),
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylineCoordinates,
                    color: Color.fromARGB(255, 42, 128, 46),
                    strokeWidth: 6,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _busPosition,
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          followBus = !followBus;
                        });
                      },
                      child: Image.asset('assets/bus.png'),
                    ),
                  ),
                  if (currentLocation != null)
                    Marker(
                      point: LatLng(
                        currentLocation!.latitude!,
                        currentLocation!.longitude!,
                      ),
                      width: 40,
                      height: 40,
                      child: Image.asset('assets/mylocation.png'),
                    ),
                  Marker(
                    point: LatLng(destinationLat, destinationLng),
                    width: 40,
                    height: 40,
                    child: Image.asset('assets/destination.png'),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: size.height * 0.05,
            left: size.width * 0.08,
            right: size.width * 0.08,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 49, 49, 49).withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SellectScreen()),
                      );
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 30,
                      shadows: [
                        Shadow(
                          offset: Offset(4.0, 4.0),
                          blurRadius: 15.0,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                  const Text('  Bus Tracking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(4.0, 4.0),
                            blurRadius: 15.0,
                            color: Colors.black,
                          ),
                        ],
                      )),
                  Switch(
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.white10,
                    activeTrackColor: Colors.greenAccent,
                    activeColor: Colors.green,
                    value: followBus,
                    onChanged: (value) {
                      setState(() {
                        followBus = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // ML Traffic Prediction Card
          if (_showMLCard)
            Positioned(
              top: size.height * 0.15,
              left: 0,
              right: 0,
              child: _buildMLTrafficCard(),
            ),

          // ML Toggle Button
          Positioned(
            top: size.height * 0.13,
            left: size.width * 0.05,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showMLCard = !_showMLCard;
                });
              },
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _showMLCard
                      ? Colors.greenAccent.withOpacity(0.7)
                      : Color.fromARGB(255, 49, 49, 49).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

          Positioned(
            top: size.height * 0.89,
            left: size.width * 0.02,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 49, 49, 49).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 94, 94, 94)
                            .withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  height: size.height * 0.1,
                  width: size.width * 0.95,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (estimatedArrivalTime != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 90.0, top: 10),
                          child: Text(
                            'Estimated Arrival time: ${estimatedArrivalTime!.toStringAsFixed(0)} min',
                            style: TextStyle(
                              shadows: <Shadow>[
                                Shadow(
                                  offset: Offset(2.0, 2.0),
                                  blurRadius: 10.0,
                                  color: Colors.greenAccent.withOpacity(0.3),
                                ),
                              ],
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (currentSpeed != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 150.0, top: 5),
                          child: Text(
                            'Bus Speed: ${currentSpeed!.toStringAsFixed(1)} km/h',
                            style: TextStyle(
                              shadows: <Shadow>[
                                Shadow(
                                  offset: Offset(2.0, 2.0),
                                  blurRadius: 10.0,
                                  color: Colors.greenAccent.withOpacity(0.3),
                                ),
                              ],
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: size.height * 0.81,
            left: size.width * 0.5 - 5,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/zte.png'),
                  fit: BoxFit.scaleDown,
                ),
              ),
              height: size.height * 0.15,
            ),
          ),
          Positioned(
            top: size.height * 0.83,
            left: 0,
            right: size.width * 0.70,
            child: Container(
              height: size.height * 0.1,
              child: Center(
                child: Text(
                  widget.busNumber,
                  style: const TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(2.0, 2.0),
                        blurRadius: 10.0,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.16,
            right: size.width * 0.86,
            left: 0,
            child: IconButton(
              icon: Icon(Icons.zoom_out, color: Colors.white, size: 30),
              onPressed: () {
                mapController.move(
                  mapController.camera.center,
                  mapController.camera.zoom - 1,
                );
              },
            ),
          ),
          Positioned(
            top: size.height * 0.13,
            right: size.width * 0.05,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isConnected
                    ? Color.fromARGB(255, 49, 49, 49).withOpacity(0.7)
                    : Colors.red.withOpacity(0.7),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 20,
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
