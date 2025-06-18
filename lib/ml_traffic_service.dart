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

// ML Learning Data osztály - egyszerűsített
class MLTrafficData {
  final DateTime timestamp;
  final int ticketsSold;
  final int actualPassengers;

  MLTrafficData({
    required this.timestamp,
    required this.ticketsSold,
    required this.actualPassengers,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'ticketsSold': ticketsSold,
      'actualPassengers': actualPassengers,
    };
  }
}

// ML Model - csak jegyek alapján
class SimpleMLModel {
  double multiplier;
  double offset;
  DateTime lastUpdated;
  int trainingCycles;
  double avgError;

  SimpleMLModel({
    this.multiplier = 1.5, // Alapértelmezett: 1 jegy = 1.5 utas
    this.offset = 5.0, // Alapértelmezett offset
    required this.lastUpdated,
    this.trainingCycles = 0,
    this.avgError = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'multiplier': multiplier,
      'offset': offset,
      'lastUpdated': lastUpdated,
      'trainingCycles': trainingCycles,
      'avgError': avgError,
    };
  }

  factory SimpleMLModel.fromMap(Map<String, dynamic> map) {
    return SimpleMLModel(
      multiplier: map['multiplier'] ?? 1.5,
      offset: map['offset'] ?? 5.0,
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
      trainingCycles: map['trainingCycles'] ?? 0,
      avgError: map['avgError'] ?? 0.0,
    );
  }
}

// Egyszerűsített ML Traffic Service - csak jegyek alapján
class MLTrafficService {
  // Helyi változók
  int _currentTraffic = 0;
  int _prediction = 0;
  int _confidence = 0;
  int _totalTicketsSold = 0;
  bool _isMLLoading = true;
  Timer? _mlUpdateTimer;
  final Random _random = Random();

  // Firestore és ML komponensek
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<MLTrafficData> _historicalData = [];
  SimpleMLModel? _mlModel;

  // Callback funkciókat fogad a UI frissítéshez
  Function(int, int, int, bool)? onTrafficUpdate;

  // Getterek
  int get currentTraffic => _currentTraffic;
  int get prediction => _prediction;
  int get confidence => _confidence;
  int get totalTicketsSold => _totalTicketsSold;
  bool get isMLLoading => _isMLLoading;
  List<MLTrafficData> get historicalData => _historicalData;
  SimpleMLModel? get mlModel => _mlModel;

  // ML system inicializálása
  Future<void> initializeMLSystem() async {
    _isMLLoading = true;
    _notifyUpdate();

    // Betöltjük a modellt a Firestore-ból
    await _loadMLModelFromFirestore();

    // Betöltjük a történelmi adatokat
    await _loadHistoricalData();

    // Lekérjük az aktuális jegy adatokat
    await _fetchCurrentTicketData();

    // Tanítjuk a modellt
    await _trainSimpleModel();

    // Generálunk predikciót
    await _generateSimplePrediction();

    _isMLLoading = false;
    _notifyUpdate();
  }

  // ML modell betöltése Firestore-ból
  Future<void> _loadMLModelFromFirestore() async {
    try {
      final DocumentSnapshot modelDoc = await _firestore
          .collection('simple_ml_models')
          .doc('ticket_traffic_model')
          .get();

      if (modelDoc.exists) {
        _mlModel =
            SimpleMLModel.fromMap(modelDoc.data() as Map<String, dynamic>);
        print(
            'ML model loaded: multiplier=${_mlModel!.multiplier}, offset=${_mlModel!.offset}');
      } else {
        // Ha nincs mentett modell, inicializáljuk
        _mlModel = SimpleMLModel(lastUpdated: DateTime.now());
        await _saveMLModelToFirestore();
        print('New simple ML model initialized');
      }
    } catch (e) {
      print('Error loading ML model: $e');
      _mlModel = SimpleMLModel(lastUpdated: DateTime.now());
    }
  }

  // ML modell mentése Firestore-ba
  Future<void> _saveMLModelToFirestore() async {
    try {
      if (_mlModel != null) {
        await _firestore
            .collection('simple_ml_models')
            .doc('ticket_traffic_model')
            .set(_mlModel!.toMap());
        print('Simple ML model saved');
      }
    } catch (e) {
      print('Error saving ML model: $e');
    }
  }

  // Történelmi adatok betöltése
  Future<void> _loadHistoricalData() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('simple_ml_data')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();

      _historicalData = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return MLTrafficData(
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          ticketsSold: data['ticketsSold'] ?? 0,
          actualPassengers: data['actualPassengers'] ?? 0,
        );
      }).toList();

      print('Loaded ${_historicalData.length} simple data points');
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

      final QuerySnapshot todayTickets = await _firestore
          .collection('tickets')
          .where('purchaseDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('purchaseDate', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      _totalTicketsSold = todayTickets.docs.length;
      print('Today tickets sold: $_totalTicketsSold');
    } catch (e) {
      print('Error fetching ticket data: $e');
      _totalTicketsSold = _random.nextInt(30) + 10;
    }
  }

  // Egyszerű modell tanítása - csak jegyek vs utasok
  Future<void> _trainSimpleModel() async {
    if (_historicalData.isEmpty || _mlModel == null) return;

    double totalError = 0;
    int validData = 0;
    double sumTickets = 0;
    double sumPassengers = 0;

    List<double> tickets = [];
    List<double> passengers = [];

    // Adatok gyűjtése
    for (var data in _historicalData) {
      if (data.ticketsSold > 0) {
        tickets.add(data.ticketsSold.toDouble());
        passengers.add(data.actualPassengers.toDouble());
        sumTickets += data.ticketsSold;
        sumPassengers += data.actualPassengers;
        validData++;
      }
    }

    if (validData < 2) return;

    // Egyszerű lineáris regresszió: passengers = multiplier * tickets + offset
    double avgTickets = sumTickets / validData;
    double avgPassengers = sumPassengers / validData;

    double numerator = 0;
    double denominator = 0;

    for (int i = 0; i < tickets.length; i++) {
      double ticketDiff = tickets[i] - avgTickets;
      double passengerDiff = passengers[i] - avgPassengers;
      numerator += ticketDiff * passengerDiff;
      denominator += ticketDiff * ticketDiff;
    }

    // Új multiplier számítása
    if (denominator != 0) {
      double newMultiplier = numerator / denominator;
      double newOffset = avgPassengers - (newMultiplier * avgTickets);

      // Hibák számítása
      for (int i = 0; i < tickets.length; i++) {
        double predicted = newMultiplier * tickets[i] + newOffset;
        double error = (predicted - passengers[i]).abs();
        totalError += error;
      }

      double avgError = totalError / validData;

      // Modell frissítése ha jobb lett
      if (avgError < _mlModel!.avgError || _mlModel!.trainingCycles == 0) {
        _mlModel!.multiplier = newMultiplier.clamp(0.5, 5.0);
        _mlModel!.offset = newOffset.clamp(0.0, 20.0);
        _mlModel!.avgError = avgError;
      }

      _mlModel!.trainingCycles++;
      _mlModel!.lastUpdated = DateTime.now();

      // Mentjük a modellt
      await _saveMLModelToFirestore();

      print(
          'Model trained: multiplier=${_mlModel!.multiplier.toStringAsFixed(2)}, '
          'offset=${_mlModel!.offset.toStringAsFixed(2)}, '
          'error=${_mlModel!.avgError.toStringAsFixed(2)}');
    }
  }

  // Egyszerű predikció generálása
  Future<void> _generateSimplePrediction() async {
    await _fetchCurrentTicketData();

    if (_mlModel == null) return;

    // Aktuális forgalom számítása
    double currentPrediction =
        (_mlModel!.multiplier * _totalTicketsSold) + _mlModel!.offset;
    _currentTraffic = currentPrediction.clamp(0, 100).round();

    // Jövő órára becslés (+ 10% több jegy eladva)
    double futureTickets = _totalTicketsSold * 1.1;
    double futurePrediction =
        (_mlModel!.multiplier * futureTickets) + _mlModel!.offset;
    _prediction = futurePrediction.clamp(0, 100).round();

    // Konfidencia számítása
    _confidence = _calculateSimpleConfidence();

    _notifyUpdate();

    // Aktuális adatok mentése
    await _saveCurrentDataForLearning(_currentTraffic);
  }

  // Konfidencia számítása
  int _calculateSimpleConfidence() {
    if (_mlModel == null) return 50;

    int confidence = 50;

    // Tanítási ciklusok alapján
    confidence += min(20, _mlModel!.trainingCycles * 2);

    // Adatok mennyisége alapján
    confidence += min(20, _historicalData.length ~/ 5);

    // Hiba alapján
    if (_mlModel!.avgError < 5)
      confidence += 15;
    else if (_mlModel!.avgError > 15) confidence -= 15;

    return confidence.clamp(30, 95);
  }

  // Aktuális adatok mentése
  Future<void> _saveCurrentDataForLearning(int currentPassengers) async {
    try {
      final MLTrafficData currentData = MLTrafficData(
        timestamp: DateTime.now(),
        ticketsSold: _totalTicketsSold,
        actualPassengers: currentPassengers,
      );

      await _firestore.collection('simple_ml_data').add(currentData.toMap());
      print('Current simple data saved for learning');
    } catch (e) {
      print('Error saving simple ML data: $e');
    }
  }

  // Rendszeres frissítés
  void startMLPeriodicUpdate() {
    _mlUpdateTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      await _generateSimplePrediction();

      // 30 percenként újratanítás
      if (DateTime.now().minute % 30 == 0) {
        await _loadHistoricalData();
        await _trainSimpleModel();
      }
    });
  }

  // Traffic level meghatározása
  TrafficLevel getTrafficLevel(int count) {
    if (count <= 20) {
      return TrafficLevel('Low', Colors.green, Colors.green.shade100);
    } else if (count <= 40) {
      return TrafficLevel('Mid', Colors.orange, Colors.orange.shade100);
    } else if (count <= 60) {
      return TrafficLevel('High', Colors.red, Colors.red.shade100);
    } else {
      return TrafficLevel('Critical', Colors.red.shade800, Colors.red.shade200);
    }
  }

  // Manuális frissítés
  Future<void> refreshPredictions() async {
    _isMLLoading = true;
    _notifyUpdate();

    await _loadHistoricalData();
    await _trainSimpleModel();
    await _generateSimplePrediction();

    _isMLLoading = false;
    _notifyUpdate();
  }

  // Egyszerű statisztikák
  Map<String, dynamic> getSimpleStats() {
    return {
      'multiplier': _mlModel?.multiplier ?? 0.0,
      'offset': _mlModel?.offset ?? 0.0,
      'trainingCycles': _mlModel?.trainingCycles ?? 0,
      'avgError': _mlModel?.avgError ?? 0.0,
      'confidence': _confidence,
      'dataPoints': _historicalData.length,
      'ticketsSoldToday': _totalTicketsSold,
    };
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
