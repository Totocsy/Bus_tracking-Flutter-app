import 'package:bus_tracking/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SellectScreen extends StatefulWidget {
  const SellectScreen({super.key});

  @override
  State<SellectScreen> createState() => _SellectScreenState();
}

class _SellectScreenState extends State<SellectScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(237, 255, 255, 255),
      appBar: AppBar(
          toolbarHeight: 30,
          backgroundColor: Color.fromARGB(241, 238, 236, 236),
          title: const Text('Bus Tracking'),
          titleTextStyle: const TextStyle(
            shadows: <Shadow>[
              Shadow(
                offset: Offset(0.0, 10),
                blurRadius: 80.0,
                color: Colors.black,
              ),
            ],
            color: Colors.black,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(80),
                bottomRight: Radius.circular(80),
              ),
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 46, 28, 28),
                  Color.fromARGB(136, 96, 84, 100)
                ],
                begin: Alignment.bottomRight,
                end: Alignment.topLeft,
              ),
            ),
          )),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 140),
            Title(
              color: Colors.black,
              child: const Text(
                'Select Bus to Track:',
                style: TextStyle(
                  shadows: <Shadow>[
                    Shadow(
                      offset: Offset(3.0, 3.0),
                      blurRadius: 80.0,
                      color: Colors.black,
                    ),
                  ],
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                primary: Color.fromARGB(255, 49, 49, 49),
                onPrimary: Colors.white,
                shadowColor: Colors.black,
                elevation: 10,
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const HomrScreen(),
                  ),
                );
              },
              child: const Text('Start Tracking Bus:23'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                primary: Color.fromARGB(255, 49, 49, 49),
                onPrimary: Colors.white,
                shadowColor: Colors.black,
                elevation: 10,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("A busz nem all rendelkezesre."),
                      content: Text("A busz nem all keszen."),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text("OK"),
                        ),
                      ],
                    );
                  },
                );
              },
              child: Text('Start Tracking Bus: 43'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Color.fromARGB(255, 49, 49, 49),
                  onPrimary: Colors.white,
                  shadowColor: Colors.black,
                  elevation: 10,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("A busz nem all rendelkezesre."),
                        content: Text("A busz nem all keszen."),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text("OK"),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Text('Start Tracking Bus:44')),
            const SizedBox(height: 20),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Color.fromARGB(255, 49, 49, 49),
                  onPrimary: Colors.white,
                  shadowColor: Colors.black,
                  elevation: 10,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("A busz nem all rendelkezesre."),
                        content: Text("A busz nem all keszen."),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text("OK"),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Text('Start Tracking Bus:21')),
            Padding(
              padding: const EdgeInsets.only(bottom: 0, top: 110),
              child: Center(child: LottieBuilder.asset('assets/bust.json')),
            ),
          ],
        ),
      ),
    );
  }
}
