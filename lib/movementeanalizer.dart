import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';

class ImprovedMovementAnalyzer {
  // Dados do acelerómetro
  double x = 0, y = 0, z = 0;
  double magnitude = 0.0;
  bool isWorking = false;
  String errorMessage = "";
  
  // Contador de remadas otimizado
  int totalStrokes = 0;
  double strokesPerMinute = 0.0;
  double averageStrokeRate = 0.0;
  
  // Análise temporal
  DateTime? firstStrokeTime;
  DateTime? lastStrokeTime;
  List<DateTime> strokeTimes = [];
  Duration? lastStrokeInterval;
  
  // Configurações de detecção melhoradas
  static const double _movementThreshold = 18.0;
  static const double _stabilityThreshold = 10.0;
  static const int _minStrokeInterval = 400; // 400ms mínimo entre remadas
  static const int _maxStrokeInterval = 4000; // 4s máximo
  static const int _historySize = 20;
  
  // Estado interno
  bool _wasInStroke = false;
  DateTime? _lastStrokeDetected;
  List<double> _magnitudeHistory = [];
  static const int _magnitudeHistorySize = 8;
  
  // Subscription
  StreamSubscription<AccelerometerEvent>? _subscription;
  Function? _onStrokeDetected; // Callback para notificar remada
  
  void startAnalysis({Function? onStrokeDetected}) {
    _onStrokeDetected = onStrokeDetected;
    
    _subscription = accelerometerEvents.listen(
      _processAccelerometerData,
      onError: (error) {
        errorMessage = "Erro no acelerómetro: $error";
        isWorking = false;
      },
    );
    
    // Verificar disponibilidade
    Timer(const Duration(seconds: 3), () {
      if (!isWorking) {
        errorMessage = "Acelerómetro não disponível";
      }
    });
  }
  
  void _processAccelerometerData(AccelerometerEvent event) {
    x = event.x;
    y = event.y;
    z = event.z;
    isWorking = true;
    errorMessage = "";
    
    _updateMagnitude();
    _detectStroke();
  }
  
  void _updateMagnitude() {
    final rawMagnitude = math.sqrt(x * x + y * y + z * z);
    
    _magnitudeHistory.add(rawMagnitude);
    if (_magnitudeHistory.length > _magnitudeHistorySize) {
      _magnitudeHistory.removeAt(0);
    }
    
    // Magnitude suavizada
    if (_magnitudeHistory.isNotEmpty) {
      magnitude = _magnitudeHistory.reduce((a, b) => a + b) / _magnitudeHistory.length;
    }
  }
  
  void _detectStroke() {
    final now = DateTime.now();
    
    // Detectar pico de movimento
    if (magnitude > _movementThreshold && !_wasInStroke) {
      if (_lastStrokeDetected == null || 
          now.difference(_lastStrokeDetected!).inMilliseconds > _minStrokeInterval) {
        
        _registerStroke(now);
        _wasInStroke = true;
        
        // Notificar callback se existir
        _onStrokeDetected?.call();
      }
    }
    else if (magnitude < _stabilityThreshold && _wasInStroke) {
      _wasInStroke = false;
    }
  }
  
  void _registerStroke(DateTime strokeTime) {
    totalStrokes++;
    _lastStrokeDetected = strokeTime;
    
    if (firstStrokeTime == null) {
      firstStrokeTime = strokeTime;
    }
    
    if (lastStrokeTime != null) {
      lastStrokeInterval = strokeTime.difference(lastStrokeTime!);
      _calculateStrokeRates();
    }
    
    lastStrokeTime = strokeTime;
    strokeTimes.add(strokeTime);
    
    if (strokeTimes.length > _historySize) {
      strokeTimes.removeAt(0);
    }
  }
  
  void _calculateStrokeRates() {
    if (lastStrokeInterval == null) return;
    
    final intervalSeconds = lastStrokeInterval!.inMilliseconds / 1000.0;
    
    if (intervalSeconds >= _minStrokeInterval / 1000.0 && 
        intervalSeconds <= _maxStrokeInterval / 1000.0) {
      
      // Taxa instantânea
      strokesPerMinute = 60.0 / intervalSeconds;
      strokesPerMinute = math.min(math.max(strokesPerMinute, 8.0), 50.0);
      
      // Taxa média das últimas 10 remadas
      if (strokeTimes.length >= 10) {
        final recent = strokeTimes.sublist(strokeTimes.length - 10);
        final totalTime = recent.last.difference(recent.first).inMilliseconds / 1000.0;
        if (totalTime > 0) {
          averageStrokeRate = (recent.length - 1) * 60.0 / totalTime;
          averageStrokeRate = math.min(math.max(averageStrokeRate, 8.0), 50.0);
        }
      }
    }
  }
  
  String getSessionDurationString() {
    if (firstStrokeTime == null) return "0s";
    
    final now = lastStrokeTime ?? DateTime.now();
    final elapsed = now.difference(firstStrokeTime!);
    
    if (elapsed.inMinutes > 0) {
      return "${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s";
    }
    return "${elapsed.inSeconds}s";
  }
  
  String getMovementStatus() {
    if (!isWorking) return "Sensor indisponível";
    if (_wasInStroke) return "Remando";
    if (magnitude > _stabilityThreshold) return "Em movimento";
    return "Barco parado - Pronto!";
  }
  
  void reset() {
    totalStrokes = 0;
    strokesPerMinute = 0.0;
    averageStrokeRate = 0.0;
    firstStrokeTime = null;
    lastStrokeTime = null;
    lastStrokeInterval = null;
    strokeTimes.clear();
    _lastStrokeDetected = null;
    _wasInStroke = false;
    _magnitudeHistory.clear();
  }
  
  void stopAnalysis() {
    _subscription?.cancel();
    _subscription = null;
  }
  
  void dispose() {
    stopAnalysis();
  }
}