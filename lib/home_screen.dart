import 'dart:async';
import 'dart:math' show cos, sqrt, asin;
import 'package:bus_tracking/sellect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class HomrScreen extends StatefulWidget {
  const HomrScreen({Key? key}) : super(key: key);

  @override
  State<HomrScreen> createState() => _HomrScreenState();
}

final Completer<GoogleMapController> _controller = Completer();
String mapTheme = "";
const String apiKey = 'YOUR_API_KEY';
const double startAddresslat = 46.523310;
const double startAddresslng = 24.543450;
const double destinationAddresslat = 46.559942;
const double destinationAddresslng = 24.581594;
const double mylocationlat = 46.546622;
const double mylocationlng = 24.569379;
const double averageBusSpeedKmph = 10.0;

class _HomrScreenState extends State<HomrScreen> {
  List<LatLng> polylineCoordinates = [];
  LocationData? currentLocation;
  late GoogleMapController _googleMapController;
  BitmapDescriptor busIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor destinationIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor myLocationIcon = BitmapDescriptor.defaultMarker;
  double? estimatedArrivalTime;
  double? currentSpeed;
  bool followBus = false;

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
    getPolypoints();
    setCustomMarkerIcon();
    DefaultAssetBundle.of(context)
        .loadString('assets/maptheme.json')
        .then((themeValue) {
      mapTheme = themeValue;
    });
  }

  @override
  void dispose() {
    _googleMapController.dispose();
    super.dispose();
  }

  void setCustomMarkerIcon() async {
    busIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration.empty, "assets/bus.png");
    destinationIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration.empty, "assets/destination.png");
    myLocationIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration.empty, "assets/mylocation.png");
  }

  void getCurrentLocation() async {
    Location location = Location();
    location.getLocation().then((location) {
      currentLocation = location;
      setState(() {});
    });

    _googleMapController = await _controller.future;

    location.onLocationChanged.listen((newLoc) {
      currentLocation = newLoc;
      if (followBus) {
        _googleMapController.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(newLoc.latitude!, newLoc.longitude!),
            zoom: 16,
          ),
        ));
      }

      setState(() {
        estimatedArrivalTime = calculateEstimatedArrivalTime(
            currentLocation!.latitude!,
            currentLocation!.longitude!,
            currentLocation!.speed);
        currentSpeed = (currentLocation!.speed! * 2);
      });
    });
  }

  double calculateDistance(double startLatitude, double startLongitude,
      double endLatitude, double endLongitude) {
    const double p = 0.017453292519943295;
    double a = 0.5 -
        cos((endLatitude - startLatitude) * p) / 2 +
        cos(startLatitude * p) *
            cos(endLatitude * p) *
            (1 - cos((endLongitude - startLongitude) * p)) /
            2;
    return 12742 * asin(sqrt(a));
  }

  double calculateEstimatedArrivalTime(
      double currentLatitude, double currentLongitude, double? currentSpeed) {
    double distanceToDestination = calculateDistance(
        currentLatitude, currentLongitude, mylocationlat, mylocationlng);
    double estimatedTime = (distanceToDestination / averageBusSpeedKmph) * 60;
    return estimatedTime;
  }

  void getPolypoints() async {
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult polylineResult =
        await polylinePoints.getRouteBetweenCoordinates(
            apiKey,
            const PointLatLng(startAddresslat, startAddresslng),
            const PointLatLng(destinationAddresslat, destinationAddresslng));

    if (polylineResult.points.isNotEmpty) {
      polylineResult.points.forEach((PointLatLng point) =>
          polylineCoordinates.add(LatLng(point.latitude, point.longitude)));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(46.54245, 24.55747),
              zoom: 14.0,
            ),
            polylines: {
              Polyline(
                polylineId: const PolylineId('Utvonal'),
                points: polylineCoordinates,
                color: Color.fromARGB(255, 27, 126, 32),
                width: 6,
              ),
            },
            markers: {
              if (currentLocation != null)
                Marker(
                  markerId: const MarkerId('Busz'),
                  icon: busIcon,
                  position: LatLng(
                      currentLocation!.latitude!, currentLocation!.longitude!),
                  onTap: () {
                    setState(() {
                      followBus = !followBus;
                    });
                  },
                ),
              Marker(
                markerId: const MarkerId('Indulas'),
                icon: destinationIcon,
                position: const LatLng(startAddresslat, startAddresslng),
              ),
              Marker(
                markerId: const MarkerId('MyLocation'),
                icon: myLocationIcon,
                position: const LatLng(mylocationlat, mylocationlng),
              ),
              Marker(
                markerId: const MarkerId('Vegallomas'),
                icon: destinationIcon,
                position:
                    const LatLng(destinationAddresslat, destinationAddresslng),
              ),
            },
            onMapCreated: (GoogleMapController controller) {
              controller.setMapStyle(mapTheme);
              _controller.complete(controller);
            },
          ),
          Positioned(
            top: 30,
            left: 95,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
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
                  const Text('Bus Tracking',
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
                    activeTrackColor: Colors.lightGreenAccent,
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
            top: 745,
            left: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            blurRadius: 5,
                          ),
                        ],
                        color: Color.fromRGBO(37, 150, 190, 170.0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      height: 90,
                      width: 395,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (estimatedArrivalTime != null)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: 90.0, top: 20),
                              child: Text(
                                'Varhato erkezesi ido : ${estimatedArrivalTime!.toStringAsFixed(0)} perc',
                                style: const TextStyle(
                                  shadows: <Shadow>[
                                    Shadow(
                                      offset: Offset(2.0, 2.0),
                                      blurRadius: 20.0,
                                      color: Color.fromARGB(255, 82, 74, 74),
                                    ),
                                  ],
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (currentSpeed != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 150.0),
                              child: Text(
                                'Busz sebesseg: ${currentSpeed!.toStringAsFixed(2)} km/h',
                                style: const TextStyle(
                                  shadows: <Shadow>[
                                    Shadow(
                                      offset: Offset(2.0, 2.0),
                                      blurRadius: 20.0,
                                      color: Color.fromARGB(255, 82, 74, 74),
                                    ),
                                  ],
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 660,
            left: 190,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/zte.png'),
                  fit: BoxFit.scaleDown,
                ),
              ),
              height: 150,
            ),
          ),
          Positioned(
            top: 685,
            left: 0,
            right: 280,
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/23.png'),
                  fit: BoxFit.scaleDown,
                ),
              ),
              height: 100,
            ),
          ),
          Positioned(
            top: 650,
            right: 330,
            left: 0,
            child: IconButton(
              icon: Icon(Icons.zoom_out, color: Colors.white, size: 30),
              onPressed: () {
                _googleMapController.animateCamera(
                  CameraUpdate.zoomOut(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
