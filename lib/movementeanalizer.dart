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

  bool isRecording = false;

  ImprovedMovementAnalyzer() {
    startAnalysis();
  }

  // --- SUAVIZAÇÃO DA MAGNITUDE ---
  static const double _alphaFast = 0.15;
  double _smoothMagnitude = 9.8;

  static const double _alphaSlow = 0.01;
  double _gravity = 9.8;

  double _dynamicAcceleration = 0.0;

  // --- LIMITES DE REMADA ---
  static const int _minStrokeInterval = 800;  // ms — mínimo entre remadas (~75 spm max)
  static const int _maxStrokeInterval = 4000; // ms — máximo (~15 spm min)

  // --- DETEÇÃO DE PICO COM BASELINE DINÂMICA ---
  final List<double> _janelaAceleracao = [];
  static const int _tamanhoJanela = 8; // ~0.8 segundos de histórico

  double _baselineDinamica = 0.0;
  double _picoAtual = 0.0;
  bool _subindoPico = false;

  // Threshold: quanto acima da baseline para contar como remada
  // Valor baixo = deteta remadas suaves
  // Valor alto = só deteta remadas fortes
  double driveThreshold = 0.20;

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

    // Mantém a janela deslizante de histórico
    _janelaAceleracao.add(_dynamicAcceleration);
    if (_janelaAceleracao.length > _tamanhoJanela) {
      _janelaAceleracao.removeAt(0);
    }
    // Espera que a janela esteja cheia antes de começar a detetar
    if (_janelaAceleracao.length < _tamanhoJanela) return;

    // Baseline dinâmica = média do ruído de fundo atual
    _baselineDinamica = _janelaAceleracao.reduce((a, b) => a + b) / _janelaAceleracao.length;

    // O threshold adapta-se ao teu movimento — não é um valor absoluto
    final double thresholdAdaptativo = _baselineDinamica + driveThreshold;

    // Estamos a subir para um pico?
    if (_dynamicAcceleration > thresholdAdaptativo) {
      if (_dynamicAcceleration > _picoAtual) {
        _picoAtual = _dynamicAcceleration;
        _subindoPico = true;
      }
    } else if (_subindoPico) {
      // Passámos o pico e voltámos a descer — é uma remada!
      _subindoPico = false;

      if (isRecording) {
        if (lastStrokeTime == null ||
            now.difference(lastStrokeTime!).inMilliseconds > _minStrokeInterval) {
          _registerStroke(now);
        }
      }

      _picoAtual = 0.0;
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

    notifyListeners();
  }

  void _calculateStrokeRates() {
    if (lastStrokeInterval == null) return;

    final double intervalSeconds = lastStrokeInterval!.inMilliseconds / 1000.0;

    if (intervalSeconds >= _minStrokeInterval / 1000.0 &&
        intervalSeconds <= _maxStrokeInterval / 1000.0) {
      strokesPerMinute = 60.0 / intervalSeconds;

      if (strokeTimes.length >= 2) {
        final double totalTime =
            strokeTimes.last.difference(strokeTimes.first).inMilliseconds / 1000.0;
        averageStrokeRate = (strokeTimes.length - 1) * 60.0 / totalTime;
      }
    } else if (intervalSeconds > _maxStrokeInterval / 1000.0) {
      strokesPerMinute = 0.0;
    }
  }

  String getMovementStatus() {
    if (!isWorking) return "A aguardar sensor...";
    final now = DateTime.now();
    if (lastStrokeTime != null && now.difference(lastStrokeTime!).inSeconds > 4) {
      return "Barco Parado";
    }
    return _subindoPico ? "Puxada (Drive)" : "Deslize (Recovery)";
  }

  double get magnitude => _dynamicAcceleration;

  void reset() {
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
    _dynamicAcceleration = 0.0;
    _janelaAceleracao.clear();
    _baselineDinamica = 0.0;
    _picoAtual = 0.0;
    _subindoPico = false;
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