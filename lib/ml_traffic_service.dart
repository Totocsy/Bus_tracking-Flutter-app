import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

// ML Traffic Service - Minden ML funkcionalitás itt van
class MLTrafficService {
  // Változók
  int _currentTraffic = 0;
  int _prediction = 0;
  int _confidence = 0;
  int _totalTicketsSold = 0;
  bool _isMLLoading = true;
  Timer? _mlUpdateTimer;
  final Random _random = Random();

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

  // Callback funkciókat fogad a UI frissítéshez
  Function(int, int, int, bool)? onTrafficUpdate;

  // Getterek
  int get currentTraffic => _currentTraffic;
  int get prediction => _prediction;
  int get confidence => _confidence;
  int get totalTicketsSold => _totalTicketsSold;
  bool get isMLLoading => _isMLLoading;
  List<MLTrafficData> get historicalData => _historicalData;

  // ML system inicializálása
  Future<void> initializeMLSystem() async {
    _isMLLoading = true;
    _notifyUpdate();

    await _loadHistoricalData();
    await _fetchCurrentTicketData();
    _trainMLModel();
    await _generateEnhancedMLPrediction();

    _isMLLoading = false;
    _notifyUpdate();
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

      _totalTicketsSold = todayTickets.docs.length;
    } catch (e) {
      print('Error fetching ticket data: $e');
      // Fallback to simulated data
      _totalTicketsSold = _random.nextInt(50) + 20;
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

    return prediction.clamp(5, 80);
  }

  // Enhanced ML predikció generálása
  Future<void> _generateEnhancedMLPrediction() async {
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

    _currentTraffic = currentTrafficPrediction.round();
    _prediction = nextHourPrediction.round();
    _confidence = confidence;

    _notifyUpdate();

    // Aktuális adatok mentése a tanuláshoz
    await _saveCurrentDataForLearning(currentTrafficPrediction.round());
  }

  // Aktuális adatok mentése ML tanuláshoz
  Future<void> _saveCurrentDataForLearning(int predictedPassengers) async {
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

  // ML rendszeres frissítés
  void startMLPeriodicUpdate() {
    _mlUpdateTimer = Timer.periodic(Duration(seconds: 45), (timer) {
      _generateEnhancedMLPrediction();
    });
  }

  // Traffic level meghatározása
  TrafficLevel getTrafficLevel(int count) {
    if (count <= 20) {
      return TrafficLevel('Alacsony', Colors.green, Colors.green.shade100);
    } else if (count <= 40) {
      return TrafficLevel('Közepes', Colors.orange, Colors.orange.shade100);
    } else {
      return TrafficLevel('Magas', Colors.red, Colors.red.shade100);
    }
  }

  // Manuális frissítés
  Future<void> refreshPredictions() async {
    await _generateEnhancedMLPrediction();
  }

  // Callback értesítés
  void _notifyUpdate() {
    if (onTrafficUpdate != null) {
      onTrafficUpdate!(_currentTraffic, _prediction, _confidence, _isMLLoading);
    }
  }

  // Cleanup
  void dispose() {
    _mlUpdateTimer?.cancel();
  }
}
