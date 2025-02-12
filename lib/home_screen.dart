import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'sellect_screen.dart';

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

  late double destinationLat;
  late double destinationLng;

  int _currentBusPositionIndex = 0;
  List<List<double>> _busRouteCoordinates = [];

  static const double averageBusSpeedKmph = 52.1;

  @override
  void initState() {
    super.initState();
    destinationLat = widget.destinationLat;
    destinationLng = widget.destinationLng;
    getCurrentLocation();
    loadBusRouteCoordinates();
    _startBusMovement();
  }

  Future<void> loadBusRouteCoordinates() async {
    String jsonString = await rootBundle.loadString('assets/${widget.route}');
    Map<String, dynamic> jsonResponse = jsonDecode(jsonString);
    List<dynamic> busRouteList = jsonResponse['busRoute'];

    setState(() {
      _busRouteCoordinates = busRouteList
          .map((route) => [route[0] as double, route[1] as double])
          .toList();

      polylineCoordinates = _busRouteCoordinates
          .map((coord) => LatLng(coord[0], coord[1]))
          .toList();
    });
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
    if (_busRouteCoordinates.isEmpty) return 0.0;

    double remainingRouteDistance = 0.0;
    for (int i = _currentBusPositionIndex;
        i < _busRouteCoordinates.length - 1;
        i++) {
      remainingRouteDistance += calculateDistance(
          _busRouteCoordinates[i][0],
          _busRouteCoordinates[i][1],
          _busRouteCoordinates[i + 1][0],
          _busRouteCoordinates[i + 1][1]);
    }

    double estimatedTimeInMinutes =
        (remainingRouteDistance / averageBusSpeedKmph) * 60 * 1.1;

    return estimatedTimeInMinutes;
  }

  double _calculateAverageBusSpeed() {
    if (_busRouteCoordinates.isEmpty || _currentBusPositionIndex < 1) {
      return averageBusSpeedKmph;
    }

    double distance = calculateDistance(
        _busRouteCoordinates[_currentBusPositionIndex - 1][0],
        _busRouteCoordinates[_currentBusPositionIndex - 1][1],
        _busRouteCoordinates[_currentBusPositionIndex][0],
        _busRouteCoordinates[_currentBusPositionIndex][1]);

    double speedKmph = (distance * 3600);

    if (speedKmph > 80 || speedKmph < 0) {
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

      if (followBus && _busRouteCoordinates.isNotEmpty) {
        mapController.move(
          LatLng(
            _busRouteCoordinates[_currentBusPositionIndex][0],
            _busRouteCoordinates[_currentBusPositionIndex][1],
          ),
          16,
        );
      }
    });
  }

  late Timer _busMovementTimer;

  void _startBusMovement() {
    _busMovementTimer = Timer.periodic(Duration(milliseconds: 2000), (timer) {
      if (_busRouteCoordinates.isNotEmpty) {
        setState(() {
          if (_currentBusPositionIndex < _busRouteCoordinates.length - 1) {
            _currentBusPositionIndex++;
            updateBusPosition();
          } else {
            _currentBusPositionIndex = 0;
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void updateBusPosition() {
    if (followBus && _busRouteCoordinates.isNotEmpty) {
      mapController.move(
        LatLng(
          _busRouteCoordinates[_currentBusPositionIndex][0],
          _busRouteCoordinates[_currentBusPositionIndex][1],
        ),
        mapController.zoom,
      );
    }
  }

  @override
  void dispose() {
    _busMovementTimer.cancel();
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
                  if (_busRouteCoordinates.isNotEmpty)
                    Marker(
                      point: LatLng(
                        _busRouteCoordinates[_currentBusPositionIndex][0],
                        _busRouteCoordinates[_currentBusPositionIndex][1],
                      ),
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
        ],
      ),
    );
  }
}
