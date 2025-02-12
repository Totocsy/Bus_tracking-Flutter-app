import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'home_screen.dart';
import 'sellect_screen.dart';

class PickDestinationScreen extends StatefulWidget {
  @override
  _PickDestinationScreenState createState() => _PickDestinationScreenState();
}

class _PickDestinationScreenState extends State<PickDestinationScreen> {
  LatLng? _pickedLocation;
  LatLng? _userLocation;
  MapController _mapController = MapController();
  String? _selectedRoute;
  List<Polyline> _polylines = [];

  final Map<String, List<LatLng>> _busRoutes = {
    'routes_23.json': [],
    'routes_43.json': [],
    'routes_44.json': [],
    'routes_21.json': [],
  };

  @override
  void initState() {
    super.initState();
    _loadBusRoutes();
    _getUserLocation();
  }

  void _showBusRouteBottomSheet() {
    final List<Map<String, dynamic>> _busRoutesList = [
      {
        'number': '23',
        'name': 'Autogara Transport Local - SMURD',
        'color': Color.fromARGB(66, 46, 204, 112),
        'file': 'routes_23.json',
      },
      {
        'number': '43',
        'name': 'Autogara Transport Local - Tudor',
        'color': Color.fromARGB(80, 52, 152, 219),
        'file': 'routes_43.json',
      },
      {
        'number': '44',
        'name': 'Sapientia - Combinat',
        'color': Color.fromARGB(68, 231, 77, 60),
        'file': 'routes_44.json',
      },
      {
        'number': '21',
        'name': 'Str. 8 Martie - Centru',
        'color': Color.fromARGB(54, 243, 157, 18),
        'file': 'routes_21.json',
      },
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Select Bus Route',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _busRoutesList.length,
              itemBuilder: (context, index) {
                final route = _busRoutesList[index];
                return ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: route['color'],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        route['number'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    'Bus ${route['number']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  subtitle: Text(
                    route['name'],
                    style: const TextStyle(
                        color: Color.fromARGB(255, 179, 178, 178)),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedRoute = route['file'];
                    });
                    _drawSelectedRoute(_selectedRoute!);
                    Navigator.pop(context);
                  },
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _loadBusRoutes() async {
    for (var routeFile in _busRoutes.keys) {
      try {
        final data = await rootBundle.loadString('assets/$routeFile');
        final jsonData = jsonDecode(data);

        if (jsonData is Map && jsonData['busRoute'] is List) {
          final routePoints = (jsonData['busRoute'] as List)
              .map((point) => LatLng(point[0], point[1]))
              .toList();

          setState(() {
            _busRoutes[routeFile] = routePoints;
          });
        } else {
          throw Exception('Invalid JSON format in $routeFile');
        }
      } catch (e) {
        print('Error loading $routeFile: $e');
      }
    }
  }

  Future<void> _getUserLocation() async {
    final location = Location();

    try {
      final userLocation = await location.getLocation();
      setState(() {
        _userLocation = LatLng(userLocation.latitude!, userLocation.longitude!);
      });

      _mapController.move(_userLocation!, 13);
    } catch (e) {
      print('Error getting user location: $e');
    }
  }

  void _onTap(TapPosition tapPosition, LatLng location) {
    setState(() {
      _pickedLocation = location;
    });

    final closestRoute = _getClosestRoute();
    if (closestRoute != null) {
      setState(() {
        _selectedRoute = closestRoute;
      });
      final busNumber = closestRoute.replaceAll(RegExp(r'[^\d]'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Closest bus route found: $busNumber'),
        ),
      );

      _drawSelectedRoute(closestRoute);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No bus routes found near the selected location'),
        ),
      );
    }
  }

  String? _getClosestRoute() {
    const double maxDistance = 0.01;
    for (var entry in _busRoutes.entries) {
      for (var point in entry.value) {
        if ((point.latitude - _pickedLocation!.latitude).abs() < maxDistance &&
            (point.longitude - _pickedLocation!.longitude).abs() <
                maxDistance) {
          return entry.key;
        }
      }
    }
    return null;
  }

  void _drawSelectedRoute(String route) {
    final routePoints = _busRoutes[route];
    if (routePoints != null) {
      setState(() {
        _polylines = [
          Polyline(
            points: routePoints,
            color: Colors.green,
            strokeWidth: 5,
          ),
        ];
      });
    }
  }

  void _confirmDestination() {
    if (_pickedLocation != null && _selectedRoute != null) {
      print('Selected location: $_pickedLocation');

      final busNumber = _selectedRoute!.replaceAll(RegExp(r'[^\d]'), '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bus route found with number: $busNumber'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomrScreen(
            destinationLat: _pickedLocation!.latitude,
            destinationLng: _pickedLocation!.longitude,
            route: _selectedRoute!,
            busNumber: busNumber,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location on the map'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(46.54245, 24.55747),
              initialZoom: 13.0,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: _polylines,
              ),
              MarkerLayer(
                markers: [
                  if (_pickedLocation != null)
                    Marker(
                      point: _pickedLocation!,
                      width: 40,
                      height: 40,
                      child: Icon(Icons.location_pin,
                          color: Colors.green, size: 40),
                    ),
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 40,
                      height: 40,
                      child: Image.asset('assets/mylocation.png'),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: screenSize.height * 0.05,
            left: screenSize.width * 0.08,
            right: screenSize.width * 0.08,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 49, 49, 49).withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Select the destination',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.check,
                      color: Colors.white,
                    ),
                    onPressed: _confirmDestination,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 15,
            right: screenSize.width * 0.5 - 28,
            child: FloatingActionButton(
              backgroundColor: Color.fromARGB(255, 49, 49, 49).withOpacity(0.7),
              onPressed: _showBusRouteBottomSheet,
              child: const Icon(Icons.directions_bus, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
