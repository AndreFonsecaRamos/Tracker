import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ImprovedMovementAnalyzer extends ChangeNotifier {
  double x = 0, y = 0, z = 0;
  bool isWorking = false;
  String errorMessage = "";
  
  int totalStrokes = 0;
  double strokesPerMinute = 0.0;
  double averageStrokeRate = 0.0;
  
  DateTime? firstStrokeTime;
  DateTime? lastStrokeTime;
  List<DateTime> strokeTimes = [];
  Duration? lastStrokeInterval;

  // NOVO: O CADEADO DE GRAVAÇÃO
  bool isRecording = false; 

  ImprovedMovementAnalyzer() {
    startAnalysis();
  }
  
  static const double _alphaFast = 0.15; 
  double _smoothMagnitude = 9.8; 
  
  static const double _alphaSlow = 0.01; 
  double _gravity = 9.8; 
  
  double _dynamicAcceleration = 0.0;
  bool _isRecoveryPhase = true; 
  
  static const double _driveThreshold = 0.4;    
  static const double _recoveryThreshold = 0.0; 
  
  static const int _minStrokeInterval = 800; 
  static const int _maxStrokeInterval = 4000; 
  
  StreamSubscription<AccelerometerEvent>? _subscription;
  
  void startAnalysis({Function? onStrokeDetected}) {
    _subscription = accelerometerEvents.listen(
      _processAccelerometerData,
      onError: (error) {
        errorMessage = "Erro no acelerómetro: $error";
        isWorking = false;
        notifyListeners();
      },
    );
    
    Timer(const Duration(seconds: 3), () {
      if (!isWorking) {
        errorMessage = "Acelerómetro não detetado.";
        notifyListeners();
      }
    });
  }

  // NOVOS MÉTODOS DE CONTROLO
  void startRecording() {
    isRecording = true;
  }

  void stopRecording() {
    isRecording = false;
    strokesPerMinute = 0.0; // Coloca a voga a 0 visualmente quando pausas
    notifyListeners();
  }
  
  void _processAccelerometerData(AccelerometerEvent event) {
    isWorking = true;
    errorMessage = "";
    
    x = event.x;
    y = event.y;
    z = event.z;
    
    final rawMagnitude = math.sqrt(x * x + y * y + z * z);
    _smoothMagnitude = _smoothMagnitude + _alphaFast * (rawMagnitude - _smoothMagnitude);
    _gravity = _gravity + _alphaSlow * (_smoothMagnitude - _gravity);
    _dynamicAcceleration = _smoothMagnitude - _gravity;
    
    _detectStroke();
  }
  
  void _detectStroke() {
    final now = DateTime.now();
    
    if (_dynamicAcceleration > _driveThreshold && _isRecoveryPhase) {
      if (lastStrokeTime == null || now.difference(lastStrokeTime!).inMilliseconds > _minStrokeInterval) {
        
        // CADEADO EM AÇÃO: Só regista se o utilizador já deu o Start!
        if (isRecording) {
          _registerStroke(now);
        }
        
        _isRecoveryPhase = false;
        notifyListeners(); 
      }
    }
    else if (_dynamicAcceleration < _recoveryThreshold && !_isRecoveryPhase) {
      _isRecoveryPhase = true; 
    }
  }
  
  void _registerStroke(DateTime strokeTime) {
    totalStrokes++;
    
    if (firstStrokeTime == null) firstStrokeTime = strokeTime;
    
    if (lastStrokeTime != null) {
      lastStrokeInterval = strokeTime.difference(lastStrokeTime!);
      _calculateStrokeRates();
    }
    
    lastStrokeTime = strokeTime;
    strokeTimes.add(strokeTime);
    if (strokeTimes.length > 10) strokeTimes.removeAt(0);
  }
  
  void _calculateStrokeRates() {
    if (lastStrokeInterval == null) return;
    
    final intervalSeconds = lastStrokeInterval!.inMilliseconds / 1000.0;
    
    if (intervalSeconds >= _minStrokeInterval / 1000.0 && intervalSeconds <= _maxStrokeInterval / 1000.0) {
      strokesPerMinute = 60.0 / intervalSeconds;
      if (strokeTimes.length >= 2) {
        final totalTime = strokeTimes.last.difference(strokeTimes.first).inMilliseconds / 1000.0;
        averageStrokeRate = (strokeTimes.length - 1) * 60.0 / totalTime;
      }
    } else if (intervalSeconds > _maxStrokeInterval / 1000.0) {
      strokesPerMinute = 0.0;
    }
  }
  
  String getSessionDurationString() {
    if (firstStrokeTime == null) return "00:00";
    final now = DateTime.now();
    final end = (lastStrokeTime != null && now.difference(lastStrokeTime!).inSeconds > 5) 
        ? lastStrokeTime! 
        : now;
    final elapsed = end.difference(firstStrokeTime!);
    
    final m = elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }
  
  String getMovementStatus() {
    if (!isWorking) return "A aguardar sensor...";
    final now = DateTime.now();
    if (lastStrokeTime != null && now.difference(lastStrokeTime!).inSeconds > 4) {
      return "Barco Parado";
    }
    return !_isRecoveryPhase ? "Puxada (Drive)" : "Deslize (Recovery)";
  }
  
  double get magnitude => _dynamicAcceleration; 

  void reset() {
    isRecording = false; // Garante que tranca ao fazer reset
    totalStrokes = 0;
    strokesPerMinute = 0.0;
    averageStrokeRate = 0.0;
    firstStrokeTime = null;
    lastStrokeTime = null;
    lastStrokeInterval = null;
    strokeTimes.clear();
    _isRecoveryPhase = true;
    _smoothMagnitude = 9.8;
    _gravity = 9.8;
    _dynamicAcceleration = 0.0;
    notifyListeners();
  }
  
  void stopAnalysis() {
    _subscription?.cancel();
    _subscription = null;
  }
  
  @override
  void dispose() {
    stopAnalysis();
    super.dispose();
  }
}