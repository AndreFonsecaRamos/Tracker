import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'movementeanalizer.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'heart_rate_controller.dart';

// 1. CLASSE DE DADOS (Átomo)
class Pontodetreino {
  final DateTime tempo;
  final double lat;
  final double long;
  final double velocidade;
  final int cadencia;
  final int frequenciaCardiaca;

  Pontodetreino({
    required this.tempo,
    required this.lat,
    required this.long,
    required this.velocidade,
    required this.cadencia,
    required this.frequenciaCardiaca,
  });
}

class _GpsSample {
  final DateTime timestamp;
  final double distance;
  final double speed;
  final double timeDelta;
  _GpsSample({required this.timestamp, required this.distance, required this.speed, required this.timeDelta});
}

class GPSController extends ChangeNotifier {
  double lat = 0.0;
  double long = 0.0;
  String erro = '';

  double distanciaTotal = 0.0;
  double distanciaUltimaRemada = 0.0;
  double velocidadeAtual = 0.0;
  double parcialPor500m = 0.0;

  Position? ultimaPosicao;
  StreamSubscription<Position>? _posicaoSubscription;
  DateTime? _ultimoUpdate;

  static const double _precisaoMinima = 15.0;
  static const double _distanciaMinima = 0.5;

  // --- FILTRO DE JANELA DESLIZANTE & EMA ---
  final List<_GpsSample> _gpsWindow = [];
  static const int _windowDurationSeconds = 2;

  double _ema1 = 0.0;
  double _ema2 = 0.0;
  bool _emaInicializada = false;

  static const double _alpha1 = 0.55; // Mais reativo à aceleração
  static const double _alpha2 = 0.35; // Mais ágil na descida do parcial

  // --- AVERAGE /500m ---
  DateTime? _inicioSessao;

  bool emPausaAutomatica = false;
  DateTime? _inicioVelocidadeBaixa;
  static const int _milissegundosParaPausar = 3000;
  static const double _velocidadeMinimaPausa = 0.5;

  double tempoAtivoSegundos = 0.0; 

  // --- LISTA PARA O STRAVA ---
  List<Pontodetreino> sessaoAtual = [];

  // 2. MÉTODO PARA LIGAR O TRACKING
  void iniciarTracking(ImprovedMovementAnalyzer analyzer, {HeartRateController? hrController}) {
    LocationSettings settings;

    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: true,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Treino de Remo",
          notificationText: "A gravar a tua sessão...",
          enableWakeLock: true,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      );
    }

    _posicaoSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        if (pos.accuracy > _precisaoMinima) return;

        lat = pos.latitude;
        long = pos.longitude;

        if (ultimaPosicao != null) {
          final currentHr = hrController?.heartRate ?? 0;
          _processarPonto(pos, analyzer.strokesPerMinute.round(), currentHr, analyzer.isRecording);
        }

        ultimaPosicao = pos;
        _ultimoUpdate = DateTime.now();
        notifyListeners();
      },
      onError: (e) {
        erro = 'Erro GPS: $e';
        notifyListeners();
      },
    );
  }

  // 3. MÉTODO DE CÁLCULO E REGISTO
  void _processarPonto(Position novaPosicao, int voga, int heartRate, bool gravando) {
    final distancia = Geolocator.distanceBetween(
      ultimaPosicao!.latitude, ultimaPosicao!.longitude,
      novaPosicao.latitude, novaPosicao.longitude,
    );

    final tempoDecorrido = novaPosicao.timestamp
        .difference(ultimaPosicao!.timestamp)
        .inMilliseconds / 1000.0;

    if (tempoDecorrido <= 0) return;

    // Outlier rejection: ignore impossible distance jumps (> 25m in 1s or speed > 7 m/s)
    if (distancia > 25.0 || (distancia / tempoDecorrido) > 7.0) {
      return;
    }

    double velocidadeInstantanea = novaPosicao.speed;

    // Se o GPS reportar 0 mas nos movemos, calculamos à mão
    if (velocidadeInstantanea <= 0 && distancia > _distanciaMinima) {
      velocidadeInstantanea = distancia / tempoDecorrido;
    }

    // Barreira de segurança final (ninguém rema a mais de 7 m/s / 25 km/h)
    if (velocidadeInstantanea > 7.0) velocidadeInstantanea = 7.0;

    // Adicionar à janela deslizante (Rolling Window)
    final now = DateTime.now();
    _gpsWindow.add(_GpsSample(
      timestamp: now,
      distance: distancia > _distanciaMinima ? distancia : 0.0,
      speed: velocidadeInstantanea,
      timeDelta: tempoDecorrido,
    ));

    // Remover amostras mais antigas que _windowDurationSeconds
    _gpsWindow.removeWhere((sample) => now.difference(sample.timestamp).inSeconds > _windowDurationSeconds);

    if (velocidadeInstantanea < _velocidadeMinimaPausa) {
      _inicioVelocidadeBaixa ??= DateTime.now();
      
      final millisParado = DateTime.now().difference(_inicioVelocidadeBaixa!).inMilliseconds;
      
      if (millisParado >= _milissegundosParaPausar && !emPausaAutomatica) {
        emPausaAutomatica = true;
        debugPrint("Auto-Pause Ativado");
        notifyListeners();
      }
    } else {
      _inicioVelocidadeBaixa = null;
      if (emPausaAutomatica) {
        emPausaAutomatica = false;
        debugPrint("Auto-Pause Desativado");
        notifyListeners();
      }
    }

    // Acumula distância
    if (distancia > _distanciaMinima && distancia < 20.0) {
      distanciaTotal += distancia;
      distanciaUltimaRemada = distancia;
      _inicioSessao ??= DateTime.now();
    }

    // Registo para o Strava
    if (gravando) {
      sessaoAtual.add(
        Pontodetreino(
          tempo: DateTime.now(),
          lat: novaPosicao.latitude,
          long: novaPosicao.longitude,
          velocidade: velocidadeInstantanea,
          cadencia: voga,
          frequenciaCardiaca: heartRate,
        ),
      );
    }

    _atualizarVelocidadeMediaComJanela();
    notifyListeners();
  }

  // --- FILTRO DE JANELA DESLIZANTE & EMA ---
  void _atualizarVelocidadeMediaComJanela() {
    if (_gpsWindow.isEmpty) {
      velocidadeAtual = 0.0;
      parcialPor500m = 0.0;
      return;
    }

    double totalDist = 0.0;
    double totalTime = 0.0;
    for (var sample in _gpsWindow) {
      totalDist += sample.distance;
      totalTime += sample.timeDelta;
    }

    if (totalTime > 0) {
      double rollingSpeed = totalDist / totalTime;
      if (rollingSpeed > 7.0) rollingSpeed = 7.0;

      if (!_emaInicializada) {
        _ema1 = rollingSpeed;
        _ema2 = rollingSpeed;
        _emaInicializada = true;
      } else {
        _ema1 = _alpha1 * rollingSpeed + (1 - _alpha1) * _ema1;
        _ema2 = _alpha2 * _ema1 + (1 - _alpha2) * _ema2;
      }
      velocidadeAtual = _ema2;
    } else {
      velocidadeAtual = 0.0;
    }

    if (velocidadeAtual > 0.5) {
      parcialPor500m = 500.0 / velocidadeAtual;
    } else {
      parcialPor500m = 0.0;
    }
  }

  // --- MÉTODOS DE UTILIDADE ---

  String getParcialFormatado() {
    if (parcialPor500m <= 0 || parcialPor500m > 3600) return "--:--";
    final minutos = (parcialPor500m / 60).floor();
    final segundos = (parcialPor500m % 60).floor();
    return "$minutos:${segundos.toString().padLeft(2, '0')}";
  }

  String getAverageParcialFormatado() {
    if (_inicioSessao == null || distanciaTotal < 10) return "--:--";
    final segundosTotais =
        DateTime.now().difference(_inicioSessao!).inSeconds.toDouble();
    final averagePor500m = (segundosTotais / distanciaTotal) * 500.0;
    if (averagePor500m <= 0 || averagePor500m > 3600) return "--:--";
    final minutos = (averagePor500m / 60).floor();
    final segundos = (averagePor500m % 60).floor();
    return "$minutos:${segundos.toString().padLeft(2, '0')}";
  }

  String getQualidadeGPS() {
    if (ultimaPosicao == null) return "A procurar...";
    final precisao = ultimaPosicao!.accuracy;
    if (precisao <= 4) return "Excelente (${precisao.toStringAsFixed(1)}m)";
    if (precisao <= 15) return "Bom (${precisao.toStringAsFixed(1)}m)";
    return "Fraco (${precisao.toStringAsFixed(1)}m)";
  }

  bool get sinalPerdido {
    if (_ultimoUpdate == null) return false;
    return DateTime.now().difference(_ultimoUpdate!).inSeconds > 5;
  }

  double getVelocidadeKmh() => velocidadeAtual * 3.6;

  Future<void> pararTracking() async {
    await _posicaoSubscription?.cancel();
    _posicaoSubscription = null;
    ultimaPosicao = null;
  }

  void resetDados() {
    _inicioVelocidadeBaixa = null;
    distanciaTotal = 0.0;
    distanciaUltimaRemada = 0.0;
    velocidadeAtual = 0.0;
    parcialPor500m = 0.0;
    _ema1 = 0.0;
    _ema2 = 0.0;
    _emaInicializada = false;
    _inicioSessao = null;
    _gpsWindow.clear();
    sessaoAtual.clear();
    notifyListeners();
  }

  Future<Position> getPermissao() async {
    bool ativado = await Geolocator.isLocationServiceEnabled();
    if (!ativado) throw Exception('Localização desligada.');

    LocationPermission permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
      if (permissao == LocationPermission.denied) {
        throw Exception('Permissão negada.');
      }
    }
    return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation));
  }

  // --- EXPORTAR PARA STRAVA (TCX com StringBuffer) ---
  Future<void> exportarTreinoTCX() async {
    debugPrint("🚣 EXPORT: sessaoAtual tem ${sessaoAtual.length} pontos");
    erro = '';

    if (sessaoAtual.isEmpty) {
      erro = "Sem dados GPS para exportar. Verifica se o GPS teve sinal durante o treino.";
      notifyListeners();
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.write('''<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
  <Activities>
    <Activity Sport="Rowing">
      <Id>${sessaoAtual.first.tempo.toUtc().toIso8601String()}</Id>
      <Lap StartTime="${sessaoAtual.first.tempo.toUtc().toIso8601String()}">
        <TotalTimeSeconds>${sessaoAtual.last.tempo.difference(sessaoAtual.first.tempo).inSeconds}</TotalTimeSeconds>
        <DistanceMeters>${distanciaTotal.toStringAsFixed(1)}</DistanceMeters>
        <Intensity>Active</Intensity>
        <TriggerMethod>Manual</TriggerMethod>
        <Track>''');

      for (var ponto in sessaoAtual) {
        buffer.write('''
          <Trackpoint>
            <Time>${ponto.tempo.toUtc().toIso8601String()}</Time>
            <Position>
              <LatitudeDegrees>${ponto.lat}</LatitudeDegrees>
              <LongitudeDegrees>${ponto.long}</LongitudeDegrees>
            </Position>''');
        if (ponto.frequenciaCardiaca > 0) {
          buffer.write('''
            <HeartRateBpm>
              <Value>${ponto.frequenciaCardiaca}</Value>
            </HeartRateBpm>''');
        }
        buffer.write('''
            <Cadence>${ponto.cadencia}</Cadence>
            <Extensions>
              <TPX xmlns="http://www.garmin.com/xmlschemas/ActivityExtension/v2">
                <Speed>${ponto.velocidade}</Speed>
              </TPX>
            </Extensions>
          </Trackpoint>''');
      }

      buffer.write('''
        </Track>
      </Lap>
    </Activity>
  </Activities>
</TrainingCenterDatabase>''');

      final directory = await getTemporaryDirectory();
      final dataStr = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .split('.')
          .first;
      final file = File('${directory.path}/Treino_Rowing_$dataStr.tcx');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.garmin.tcx+xml')],
        text: 'O meu treino de Remo!',
        subject: 'Treino de Remo',
      );
    } catch (e) {
      erro = "Erro ao exportar: $e";
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _posicaoSubscription?.cancel();
    _posicaoSubscription = null;
    super.dispose();
  }
}
