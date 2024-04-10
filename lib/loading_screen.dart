import 'package:bus_tracking/sellect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

class LoadindScreen extends StatefulWidget {
  const LoadindScreen({Key? key});

  @override
  State<LoadindScreen> createState() => _LoadindScreenState();
}

class _LoadindScreenState extends State<LoadindScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    Future.delayed(const Duration(seconds: 8), () {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => const SellectScreen(),
      ));
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
              center: Alignment.center,
              radius: 100.0,
              colors: [Colors.white70, Color.fromARGB(255, 17, 9, 37)]),
        ),
        child: Column(
          children: [
            const SizedBox(height: 250),
            Center(child: LottieBuilder.asset('assets/busanim.json')),
            const SizedBox(height: 20),
            const Text(
              'Bus Tracking App',
              style: TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 16, 58, 92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
