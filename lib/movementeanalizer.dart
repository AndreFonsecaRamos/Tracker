import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ImprovedMovementAnalyzer extends ChangeNotifier {

  //para guardar os picos de voga regeitados
  final List<String> logPicos = [];


  //tentativa de duplo filtro com analize rapida e lenta para tirar possiveis interferencias

  double _emaVoga1 = 0.0;
  double _emaVoga2 = 0.0;
  bool _emaVogaInicializada = false;

  static const double _alphaVoga1 = 0.40; // Reativo — captura mudanças reais
  static const double _alphaVoga2 = 0.35; // Suave — elimina saltos

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

  // --- FILTRO DE GRAVIDADE E ACELERAÇÃO ---
  double _gravity = 9.8;
  bool _gravidadeInicializada = false;
  static const double _alphaFast = 0.15; // Suaviza a força resultante
  double _dynamicAcceleration = 0.0;

  // --- LIMITES DE REMADA ---
  static const int _minStrokeInterval = 800;  // ms — mínimo entre remadas (~75 spm max)
  static const int _maxStrokeInterval = 4000; // ms — máximo (~15 spm min)

  // --- DETEÇÃO DE PICO COM BASELINE DINÂMICA ---
  final List<double> _janelaAceleracao = [];
  static const int _tamanhoJanela = 80; // ~0.8 segundos reais a 100Hz

  double _baselineDinamica = 0.0;
  double _picoAtual = 0.0;
  bool _subindoPico = false;
  DateTime? _inicioPico; // Guarda a hora em que o pico começou

  // Threshold: quanto acima da baseline para contar como remada
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
    _emaVoga1 = 0.0;
    _emaVoga2 = 0.0;
    _emaVogaInicializada = false;
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

    // Inicializa gravidade com primeiro ponto real
    if (!_gravidadeInicializada) {
      _gravity = rawMagnitude;
      _gravidadeInicializada = true;
    }

    // Gravidade = média muito lenta da magnitude total
    _gravity = 0.001 * rawMagnitude + 0.999 * _gravity;

    // Aceleração dinâmica = diferença em relação à gravidade
    final double dinamica = rawMagnitude - _gravity;

    // Suavização leve
    _dynamicAcceleration = _alphaFast * dinamica + (1 - _alphaFast) * _dynamicAcceleration;

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

    // O threshold adapta-se ao movimento (não é absoluto)
    final double thresholdAdaptativo = _baselineDinamica + driveThreshold;

    // Estamos a subir para um pico?
    if (_dynamicAcceleration > thresholdAdaptativo) {
      if (!_subindoPico) {
        _inicioPico = now; // Marca o exato milissegundo em que a força começou
        _subindoPico = true;
      }
      if (_dynamicAcceleration > _picoAtual) {
        _picoAtual = _dynamicAcceleration;
      }
    } else if (_subindoPico) {
      // Passámos o pico e descemos (acabou o drive)
      _subindoPico = false;

      // VALIDAÇÃO DA DURAÇÃO (O Segredo!)
      // Remada real = 100ms a ~800ms. Pancada/Onda = < 80ms.
      final int duracaoPicoMs = _inicioPico != null 
          ? now.difference(_inicioPico!).inMilliseconds 
          : 0;

      if (duracaoPicoMs >= 100 && duracaoPicoMs <= 800) {
        if (isRecording) {
          if (lastStrokeTime == null ||
              now.difference(lastStrokeTime!).inMilliseconds > _minStrokeInterval) {
            _registerStroke(now);
          }
        }
      } else {
        final msg = "❌ ${duracaoPicoMs}ms rejeitado";
        logPicos.add(msg);
        if (logPicos.length > 300) logPicos.removeAt(0);
      }
      _picoAtual = 0.0;
      _inicioPico = null;
    }
  }

  double get magnitude => _dynamicAcceleration;

  void _registerStroke(DateTime strokeTime) {

    final msg = "Remada #${totalStrokes + 1}";
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
      _emaVoga1 = 0.0;
      _emaVoga2 = 0.0;
      _emaVogaInicializada = false;
      _intervalosMs.clear();
      return;
    }

    // Guarda o intervalo na lista
    _intervalosMs.add(intervalMs);
    if (_intervalosMs.length > _tamanhoMediaIntervalos) {
      _intervalosMs.removeAt(0);
    }

    // Calcula a voga como média dos últimos N intervalos (super estável no ecrã)
    final double mediaMs = _intervalosMs.reduce((a, b) => a + b) / _intervalosMs.length;
    final double vogaCalculada = 60000.0 / mediaMs;

    if (!_emaVogaInicializada) {
      _emaVoga1 = vogaCalculada;
      _emaVoga2 = vogaCalculada;
      _emaVogaInicializada = true;
    } else {
      _emaVoga1 = _alphaVoga1 * vogaCalculada + (1 - _alphaVoga1) * _emaVoga1;
      _emaVoga2 = _alphaVoga2 * _emaVoga1 + (1 - _alphaVoga2) * _emaVoga2;
    }

    strokesPerMinute = _emaVoga2;

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
    
    _gravity = 9.8;
    _gravidadeInicializada = false;
    _dynamicAcceleration = 0.0;

    _emaVoga1 = 0.0;
    _emaVoga2 = 0.0;
    _emaVogaInicializada = false;

    logPicos.clear();
    
    _janelaAceleracao.clear();
    _baselineDinamica = 0.0;
    _picoAtual = 0.0;
    _subindoPico = false;
    _inicioPico = null;
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