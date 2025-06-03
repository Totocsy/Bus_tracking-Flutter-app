import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'sellect_screen.dart';

// ML Traffic Level osztály
class TrafficLevel {
  final String level;
  final Color color;
  final Color backgroundColor;

  TrafficLevel(this.level, this.color, this.backgroundColor);
}

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

  LatLng _busPosition = LatLng(46.54245, 24.55747); // Default position
  StreamSubscription? _streamSubscription;
  final String serverUrl = "https://bus-api-7ph1.onrender.com";
  DateTime? _lastUpdateTime;

  static const double averageBusSpeedKmph = 53;

  // ML Traffic Prediction változók
  int _currentTraffic = 0;
  int _prediction = 0;
  int _confidence = 0;
  int _activeUsers = 0;
  int _loggedInUsers = 0;
  bool _isMLLoading = true;
  Timer? _mlUpdateTimer;
  final Random _random = Random();
  bool _showMLCard = false;

  @override
  void initState() {
    super.initState();
    destinationLat = widget.destinationLat;
    destinationLng = widget.destinationLng;
    getCurrentLocation();
    _startTrackingBus();
    _initializeMLModel();
    _startMLPeriodicUpdate();
  }

  // ML model inicializálása
  void _initializeMLModel() async {
    await Future.delayed(Duration(seconds: 2));
    _generateMLPrediction();
    setState(() {
      _isMLLoading = false;
    });
  }

  // ML predikció generálása
  void _generateMLPrediction() {
    final hour = DateTime.now().hour;
    final isWeekend = DateTime.now().weekday >= 6;
    final isRushHour = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19);

    // Szimulált app használati adatok
    final baseActiveUsers = _random.nextInt(150) + 50;
    final baseLoggedUsers = (baseActiveUsers * 0.7).floor();

    // ML algoritmus szimuláció
    int basePrediction = _random.nextInt(40) + 10;

    // Faktorok alkalmazása
    if (isRushHour) basePrediction = (basePrediction * 1.5).floor();
    if (isWeekend) basePrediction = (basePrediction * 0.7).floor();

    // App használati adatok befolyása
    final userActivityFactor = baseActiveUsers / 100;
    basePrediction = (basePrediction * userActivityFactor).floor();

    // Jelenlegi forgalom
    final currentValue = max(0, basePrediction + _random.nextInt(10) - 5);
    final predictionValue = max(0, basePrediction);
    final confidenceValue = _random.nextInt(20) + 75;

    if (mounted) {
      setState(() {
        _currentTraffic = currentValue;
        _prediction = predictionValue;
        _confidence = confidenceValue;
        _activeUsers = baseActiveUsers;
        _loggedInUsers = baseLoggedUsers;
      });
    }
  }

  // ML rendszeres frissítés
  void _startMLPeriodicUpdate() {
    _mlUpdateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _generateMLPrediction();
    });
  }

  // Traffic level meghatározása
  TrafficLevel _getTrafficLevel(int count) {
    if (count <= 15) {
      return TrafficLevel('Alacsony', Colors.green, Colors.green.shade100);
    } else if (count <= 30) {
      return TrafficLevel('Közepes', Colors.orange, Colors.orange.shade100);
    } else {
      return TrafficLevel('Magas', Colors.red, Colors.red.shade100);
    }
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
    if (polylineCoordinates.isEmpty) return 0.0;

    double distanceToDestination = calculateDistance(
        _busPosition.latitude,
        _busPosition.longitude,
        currentLocation!.latitude!,
        currentLocation!.longitude!);

    double estimatedTimeInMinutes =
        (distanceToDestination / averageBusSpeedKmph) * 60 * 1;

    return estimatedTimeInMinutes;
  }

  double _calculateAverageBusSpeed() {
    if (_lastUpdateTime == null || polylineCoordinates.length < 2) {
      return averageBusSpeedKmph;
    }

    LatLng prevPosition = polylineCoordinates[polylineCoordinates.length - 2];
    LatLng currentPosition =
        polylineCoordinates[polylineCoordinates.length - 1];

    double distanceKm = calculateDistance(
      prevPosition.latitude,
      prevPosition.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
    );

    DateTime now = DateTime.now();
    double timeDiffInSeconds =
        now.difference(_lastUpdateTime!).inMilliseconds / 1000;

    if (timeDiffInSeconds < 1) {
      // Ha túl gyors a frissítés, ne számoljunk sebességet
      return averageBusSpeedKmph;
    }

    double speedKmph = (distanceKm / timeDiffInSeconds) * 3600;

    // Csak a negatív és irreálisan magas értékeket szűrjük ki
    if (speedKmph < -1 || speedKmph > 85) {
      return averageBusSpeedKmph;
    }

    return speedKmph;
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
          currentSpeed = _calculateAverageBusSpeed();
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
                _busPosition = newPosition;
                polylineCoordinates.add(newPosition);
                _lastUpdateTime = DateTime.now();

                if (polylineCoordinates.length > 500) {
                  polylineCoordinates = polylineCoordinates
                      .sublist(polylineCoordinates.length - 500);
                }

                estimatedArrivalTime = calculateEstimatedArrivalTime();
                currentSpeed = _calculateAverageBusSpeed();

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

  // ML kártya építése
  Widget _buildMLTrafficCard() {
    if (_isMLLoading) {
      return _buildMLLoadingCard();
    }

    final currentLevel = _getTrafficLevel(_currentTraffic);

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.greenAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Busz Forgalom',
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
                  color: Colors.greenAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ML',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Jelenlegi forgalom
          Row(
            children: [
              Icon(Icons.people, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'Jelenleg: $_currentTraffic utas',
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
                'Előrejelzés: $_prediction utas ($_confidence%)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),

          // Adatforrások
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aktív: $_activeUsers',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 10,
                ),
              ),
              Text(
                'Bejelentkezve: $_loggedInUsers',
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'ML model betöltése...',
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
    _mlUpdateTimer?.cancel();
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
                            'Bus Speed: ${currentSpeed!.toStringAsFixed(2)} km/h',
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
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: _isConnected
                    ? Color.fromARGB(0, 109, 148, 111).withOpacity(0.7)
                    : Colors.red.withOpacity(0.7),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(
                    _isConnected ? Icons.wifi : Icons.wifi_off,
                    color: Colors.white,
                    size: 16,
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
