import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sellect_screen.dart';

// ML Traffic Level osztály
class TrafficLevel {
  final String level;
  final Color color;
  final Color backgroundColor;

  TrafficLevel(this.level, this.color, this.backgroundColor);
}

// ML Learning Data osztály
class MLTrafficData {
  final DateTime timestamp;
  final int ticketsSold;
  final int actualPassengers;
  final double hour;
  final bool isWeekend;
  final bool isRushHour;
  final String weatherCondition;

  MLTrafficData({
    required this.timestamp,
    required this.ticketsSold,
    required this.actualPassengers,
    required this.hour,
    required this.isWeekend,
    required this.isRushHour,
    required this.weatherCondition,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'ticketsSold': ticketsSold,
      'actualPassengers': actualPassengers,
      'hour': hour,
      'isWeekend': isWeekend,
      'isRushHour': isRushHour,
      'weatherCondition': weatherCondition,
    };
  }
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

  LatLng _busPosition = LatLng(46.54245, 24.55747);
  StreamSubscription? _streamSubscription;
  final String serverUrl = "https://bus-api-7ph1.onrender.com";
  DateTime? _lastUpdateTime;

  static const double averageBusSpeedKmph = 53;

  // Enhanced ML Traffic Prediction változók
  int _currentTraffic = 0;
  int _prediction = 0;
  int _confidence = 0;
  int _totalTicketsSold = 0;
  bool _isMLLoading = true;
  Timer? _mlUpdateTimer;
  final Random _random = Random();
  bool _showMLCard = false;

  // ML Learning komponensek
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<MLTrafficData> _historicalData = [];
  Map<String, double> _mlWeights = {
    'hour': 0.3,
    'isWeekend': 0.2,
    'isRushHour': 0.25,
    'ticketsSold': 0.15,
    'weatherFactor': 0.1,
  };

  @override
  void initState() {
    super.initState();
    destinationLat = widget.destinationLat;
    destinationLng = widget.destinationLng;
    getCurrentLocation();
    _startTrackingBus();
    _initializeMLSystem();
    _startMLPeriodicUpdate();
  }

  // Enhanced ML system inicializálása
  void _initializeMLSystem() async {
    setState(() {
      _isMLLoading = true;
    });

    await _loadHistoricalData();
    await _fetchCurrentTicketData();
    _trainMLModel();
    _generateEnhancedMLPrediction();

    setState(() {
      _isMLLoading = false;
    });
  }

  // Történelmi adatok betöltése
  Future<void> _loadHistoricalData() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('ml_traffic_data')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      _historicalData = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return MLTrafficData(
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          ticketsSold: data['ticketsSold'] ?? 0,
          actualPassengers: data['actualPassengers'] ?? 0,
          hour: data['hour'] ?? 0.0,
          isWeekend: data['isWeekend'] ?? false,
          isRushHour: data['isRushHour'] ?? false,
          weatherCondition: data['weatherCondition'] ?? 'clear',
        );
      }).toList();
    } catch (e) {
      print('Error loading historical data: $e');
    }
  }

  // Aktuális jegy adatok lekérése
  Future<void> _fetchCurrentTicketData() async {
    try {
      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);
      final DateTime endOfDay = startOfDay.add(Duration(days: 1));

      // Mai napi jegyek lekérése
      final QuerySnapshot todayTickets = await _firestore
          .collection('tickets')
          .where('purchaseDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('purchaseDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      setState(() {
        _totalTicketsSold = todayTickets.docs.length;
      });
    } catch (e) {
      print('Error fetching ticket data: $e');
      // Fallback to simulated data
      setState(() {
        _totalTicketsSold = _random.nextInt(50) + 20;
      });
    }
  }

  // ML model tanítása
  void _trainMLModel() {
    if (_historicalData.isEmpty) return;

    // Súlyok finomhangolása a múltbeli adatok alapján
    double totalError = 0;
    int validPredictions = 0;

    for (var data in _historicalData) {
      double predictedTraffic = _calculateTrafficPrediction(
        data.hour,
        data.isWeekend,
        data.isRushHour,
        data.ticketsSold,
        data.weatherCondition,
      );

      double error = (predictedTraffic - data.actualPassengers).abs();
      totalError += error;
      validPredictions++;
    }

    // Adaptív tanulás - súlyok módosítása a hibák alapján
    if (validPredictions > 0) {
      double avgError = totalError / validPredictions;

      // Ha a hiba túl nagy, csökkentjük a jegyek súlyát és növeljük az időfaktorokét
      if (avgError > 10) {
        _mlWeights['ticketsSold'] = max(0.1, _mlWeights['ticketsSold']! - 0.02);
        _mlWeights['hour'] = min(0.4, _mlWeights['hour']! + 0.01);
        _mlWeights['isRushHour'] = min(0.3, _mlWeights['isRushHour']! + 0.01);
      }
    }
  }

  // Forgalom predikció számítása
  double _calculateTrafficPrediction(double hour, bool isWeekend,
      bool isRushHour, int ticketsSold, String weatherCondition) {
    double prediction = 0;

    // Óra alapján
    double hourFactor = 1.0;
    if (hour >= 7 && hour <= 9)
      hourFactor = 1.8; // Reggeli csúcs
    else if (hour >= 17 && hour <= 19)
      hourFactor = 1.6; // Délutáni csúcs
    else if (hour >= 22 || hour <= 5) hourFactor = 0.3; // Éjszaka
    prediction += hourFactor * 15 * _mlWeights['hour']!;

    // Hétvége faktor
    if (isWeekend) {
      prediction *= 0.7 * _mlWeights['isWeekend']!;
    }

    // Rush hour faktor
    if (isRushHour) {
      prediction *= 1.4 * _mlWeights['isRushHour']!;
    }

    // Jegyek alapján - ez a legfontosabb új komponens
    double ticketFactor = ticketsSold / 30.0; // Normalizálás
    prediction += ticketFactor * 25 * _mlWeights['ticketsSold']!;

    // Időjárás faktor
    double weatherFactor = 1.0;
    if (weatherCondition.contains('rain'))
      weatherFactor = 1.2;
    else if (weatherCondition.contains('snow')) weatherFactor = 0.8;
    prediction *= weatherFactor * _mlWeights['weatherFactor']!;

    return prediction.clamp(5, 80);
  }

  // Enhanced ML predikció generálása
  void _generateEnhancedMLPrediction() async {
    await _fetchCurrentTicketData();

    final DateTime now = DateTime.now();
    final double hour = now.hour.toDouble();
    final bool isWeekend = now.weekday >= 6;
    final bool isRushHour =
        (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19);

    // Aktuális forgalom számítása a jegyek alapján
    double currentTrafficPrediction = _calculateTrafficPrediction(
        hour, isWeekend, isRushHour, _totalTicketsSold, 'clear');

    // Jövő órára előrejelzés
    double nextHourPrediction = _calculateTrafficPrediction(
        hour + 1,
        isWeekend,
        ((hour + 1) >= 7 && (hour + 1) <= 9) ||
            ((hour + 1) >= 17 && (hour + 1) <= 19),
        _totalTicketsSold,
        'clear');

    // Konfidencia számítása az adatok mennyisége alapján
    int confidence = min(95, 60 + (_historicalData.length * 2));

    if (mounted) {
      setState(() {
        _currentTraffic = currentTrafficPrediction.round();
        _prediction = nextHourPrediction.round();
        _confidence = confidence;
      });
    }

    // Aktuális adatok mentése a tanuláshoz
    _saveCurrentDataForLearning(currentTrafficPrediction.round());
  }

  // Aktuális adatok mentése ML tanuláshoz
  void _saveCurrentDataForLearning(int predictedPassengers) async {
    try {
      final DateTime now = DateTime.now();
      final MLTrafficData currentData = MLTrafficData(
        timestamp: now,
        ticketsSold: _totalTicketsSold,
        actualPassengers:
            predictedPassengers, // Ezt később valós adattal kellene frissíteni
        hour: now.hour.toDouble(),
        isWeekend: now.weekday >= 6,
        isRushHour: (now.hour >= 7 && now.hour <= 9) ||
            (now.hour >= 17 && now.hour <= 19),
        weatherCondition:
            'clear', // Ezt is frissíteni kellene valós időjárás adatokkal
      );

      await _firestore.collection('ml_traffic_data').add(currentData.toMap());
    } catch (e) {
      print('Error saving ML data: $e');
    }
  }

  // ML rendszeres frissítés - most jegy adatokkal
  void _startMLPeriodicUpdate() {
    _mlUpdateTimer = Timer.periodic(Duration(seconds: 45), (timer) {
      _generateEnhancedMLPrediction();
    });
  }

  // Traffic level meghatározása
  TrafficLevel _getTrafficLevel(int count) {
    if (count <= 20) {
      return TrafficLevel('Alacsony', Colors.green, Colors.green.shade100);
    } else if (count <= 40) {
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
      return averageBusSpeedKmph;
    }

    double speedKmph = (distanceKm / timeDiffInSeconds) * 3600;

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

  // Enhanced ML kártya építése
  Widget _buildMLTrafficCard() {
    if (_isMLLoading) {
      return _buildMLLoadingCard();
    }

    final currentLevel = _getTrafficLevel(_currentTraffic);
    final predictedLevel = _getTrafficLevel(_prediction);

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
                'Most: $_currentTraffic utas',
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
                'Következő óra: $_prediction utas',
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
                'Pontosság: $_confidence%',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Tanulási adatok: ${_historicalData.length}',
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
