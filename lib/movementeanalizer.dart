import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ImprovedMovementAnalyzer extends ChangeNotifier {

  // Ferramenta de debug (opcional, pode ficar)
  final List<String> logPicos = [];

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

  bool isRecording = false;

  final List<int> _intervalosMs = [];
  static const int _tamanhoMediaIntervalos = 4; // Média das últimas 4 remadas

  ImprovedMovementAnalyzer() {
    startAnalysis();
  }

  // --- FILTROS DE SINAL ---
  // 1. Mata a vibração curta (ondas)
  static const double _alphaSmooth = 0.10; 
  double _smoothMagnitude = 9.8;

  // 2. Isola a gravidade (Lento)
  static const double _alphaGravity = 0.002; 
  double _gravity = 9.8;
  bool _gravidadeInicializada = false;

  double _dynamicAcceleration = 0.0;

  // --- GATILHO ANTI-ONDAS (HISTERESE) ---
  // Para ser remada, tem de subir acima de +0.25
  // Para a app voltar a escutar, tem de descer abaixo de -0.10
  double driveThreshold = 0.25; 
  static const double thresholdRecovery = -0.10; 
  
  bool _prontoParaRemar = true; // Estado do Gatilho

  // --- LIMITES TEMPORAIS ---
  static const int _minStrokeInterval = 800;  // Impossível remar a > 75 spm
  static const int _maxStrokeInterval = 4000; // Parado (reset)

  StreamSubscription<AccelerometerEvent>? _subscription;

  void startAnalysis() {
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

  void startRecording() {
    isRecording = true;
  }

  void stopRecording() {
    isRecording = false;
    strokesPerMinute = 0.0;
    _intervalosMs.clear();
    notifyListeners();
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    isWorking = true;
    errorMessage = "";

    x = event.x;
    y = event.y;
    z = event.z;

    final double rawMagnitude = math.sqrt(x * x + y * y + z * z);

    if (!_gravidadeInicializada) {
      _smoothMagnitude = rawMagnitude;
      _gravity = rawMagnitude;
      _gravidadeInicializada = true;
    }

    // 1. Suavizar impactos secos e ondas (Low-Pass Filter)
    _smoothMagnitude = _alphaSmooth * rawMagnitude + (1 - _alphaSmooth) * _smoothMagnitude;

    // 2. Extrair a gravidade (Média super lenta)
    _gravity = _alphaGravity * _smoothMagnitude + (1 - _alphaGravity) * _gravity;

    // 3. Obter a força pura do remador
    _dynamicAcceleration = _smoothMagnitude - _gravity;

    _detectStroke();
  }

  void _detectStroke() {
    // A MAGIA DA HISTERESE: Ignora ruído e ondas
    
    // FASE 1: O barco acelera (O remador faz força)
    if (_prontoParaRemar && _dynamicAcceleration > driveThreshold) {
      _prontoParaRemar = false; // Bloqueia! Nenhuma onda vai contar como remada agora.
      
      final now = DateTime.now();
      
      if (isRecording) {
        if (lastStrokeTime == null ||
            now.difference(lastStrokeTime!).inMilliseconds > _minStrokeInterval) {
          _registerStroke(now);
        } else {
           logPicos.add("Ignorado: Rápido demais");
        }
      }
    } 
    // FASE 2: O barco desliza e perde velocidade (O remador vem ao ataque)
    else if (!_prontoParaRemar && _dynamicAcceleration < thresholdRecovery) {
      _prontoParaRemar = true; // Rearmado! Pronto para a próxima remada.
    }
  }

  double get magnitude => _dynamicAcceleration;

  void _registerStroke(DateTime strokeTime) {
    final msg = "Remada #${totalStrokes + 1} (${_dynamicAcceleration.toStringAsFixed(2)}g)";
    logPicos.add(msg);
    if (logPicos.length > 300) logPicos.removeAt(0);

    totalStrokes++;

    if (firstStrokeTime == null) firstStrokeTime = strokeTime;

    if (lastStrokeTime != null) {
      lastStrokeInterval = strokeTime.difference(lastStrokeTime!);
      _calculateStrokeRates();
    }

    lastStrokeTime = strokeTime;
    strokeTimes.add(strokeTime);
    if (strokeTimes.length > 10) strokeTimes.removeAt(0);

    notifyListeners();
  }

  void _calculateStrokeRates() {
    if (lastStrokeInterval == null) return;

    final int intervalMs = lastStrokeInterval!.inMilliseconds;

    // Se demorou mais de 4s, o barco esteve parado. Reseta para a largada!
    if (intervalMs > _maxStrokeInterval) {
      strokesPerMinute = 0.0;
      _intervalosMs.clear();
      return;
    }

    // Guarda o intervalo na lista
    _intervalosMs.add(intervalMs);
    if (_intervalosMs.length > _tamanhoMediaIntervalos) {
      _intervalosMs.removeAt(0);
    }

    // A VOGA É APENAS A MÉDIA DOS ÚLTIMOS N INTERVALOS
    // Removido o filtro duplo (EMA) para manter a reatividade da largada
    final double mediaMs = _intervalosMs.reduce((a, b) => a + b) / _intervalosMs.length;
    strokesPerMinute = 60000.0 / mediaMs;

    // Average geral da sessão
    if (strokeTimes.length >= 2) {
      final double totalTime =
          strokeTimes.last.difference(strokeTimes.first).inMilliseconds / 1000.0;
      averageStrokeRate = (strokeTimes.length - 1) * 60.0 / totalTime;
    }
  }

  String getMovementStatus() {
    if (!isWorking) return "A aguardar sensor...";
    final now = DateTime.now();
    if (lastStrokeTime != null && now.difference(lastStrokeTime!).inSeconds > 4) {
      return "Barco Parado";
    }
    return !_prontoParaRemar ? "Puxada (Drive)" : "Deslize (Recovery)";
  }

  void reset() {
    _intervalosMs.clear();
    isRecording = false;
    totalStrokes = 0;
    strokesPerMinute = 0.0;
    averageStrokeRate = 0.0;
    firstStrokeTime = null;
    lastStrokeTime = null;
    lastStrokeInterval = null;
    strokeTimes.clear();
    
    _smoothMagnitude = 9.8;
    _gravity = 9.8;
    _gravidadeInicializada = false;
    _dynamicAcceleration = 0.0;

    logPicos.clear();
    
    _prontoParaRemar = true;
    notifyListeners();
  }

  void stopAnalysis() {
    _subscription?.cancel();
    _subscription = null;
  }

  void updateThreshold(double newValue) {
    driveThreshold = newValue;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAnalysis();
    super.dispose();
  }
}