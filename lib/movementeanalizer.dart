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

  final List<int> _intervalosMs = [];
  static const int _tamanhoMediaIntervalos = 4;

  ImprovedMovementAnalyzer() {
    startAnalysis();
  }

  static const double _alphaGravity = 0.05; // Muito lento, descobre o "Centro da Terra"
  double _gx = 0.0, _gy = 0.0, _gz = 0.0;   // Vetor da Gravidade

  static const double _alphaFast = 0.15;    // Suaviza a força resultante
  double _dynamicAcceleration = 0.0;

  // --- LIMITES DE REMADA ---
  static const int _minStrokeInterval = 800;  // ms — mínimo entre remadas (~75 spm max)

  // --- LIMITES DE REMADA ---
  static const int _maxStrokeInterval = 4000; // ms — máximo (~15 spm min)

  // --- DETEÇÃO DE PICO COM BASELINE DINÂMICA ---
  final List<double> _janelaAceleracao = [];
  static const int _tamanhoJanela = 80; // ~0.8 segundos reais a 100Hz

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
    _intervalosMs.clear();
    notifyListeners();
  }

  void _processAccelerometerData(AccelerometerEvent event) {
    isWorking = true;
    errorMessage = "";

    x = event.x;
    y = event.y;
    z = event.z;

    // 1. Isolar o Vetor da Gravidade (Para onde é "baixo")
    _gx = _alphaGravity * x + (1 - _alphaGravity) * _gx;
    _gy = _alphaGravity * y + (1 - _alphaGravity) * _gy;
    _gz = _alphaGravity * z + (1 - _alphaGravity) * _gz;

    // 2. Descobrir a Força Dinâmica Pura (Sem a atração do planeta)
    final double dx = x - _gx;
    final double dy = y - _gy;
    final double dz = z - _gz;

    // 3. Projeção Vetorial: Cortar o eixo vertical (Ondas/Saltos)
    final double gMag = math.sqrt(_gx * _gx + _gy * _gy + _gz * _gz);
    
    double horizontalMag = 0.0;
    
    if (gMag > 0.1) { // Previne divisão por zero
      // Descobre o Vetor Unitário da Gravidade (aponta para baixo com força 1)
      final double ugx = _gx / gMag;
      final double ugy = _gy / gMag;
      final double ugz = _gz / gMag;

      // Produto Escalar (Dot Product): Quanta força foi gasta na vertical?
      final double forcaVertical = (dx * ugx) + (dy * ugy) + (dz * ugz);

      // Subtrai a força vertical ao movimento total. O que sobra é puro movimento HORIZONTAL.
      final double hx = dx - (forcaVertical * ugx);
      final double hy = dy - (forcaVertical * ugy);
      final double hz = dz - (forcaVertical * ugz);

      // A magnitude do movimento puramente horizontal (Aceleração do barco)
      horizontalMag = math.sqrt(hx * hx + hy * hy + hz * hz);
    }

    // 4. Suavizar ligeiramente o resultado horizontal para ignorar trepidação mínima
    _dynamicAcceleration = _alphaFast * horizontalMag + (1 - _alphaFast) * _dynamicAcceleration;

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
      // Passámos o pico e voltámos a descer — é uma remada
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

  double get magnitude => _dynamicAcceleration;

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

    final int intervalMs = lastStrokeInterval!.inMilliseconds;

    //com um intervalo superior a 4s reseta a voga para poder arrancar em largada
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

    // Calcula a voga como média dos últimos N intervalos
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
    return _subindoPico ? "Puxada (Drive)" : "Deslize (Recovery)";
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
    
    _gx = 0.0;
    _gy = 0.0;
    _gz = 0.0;
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