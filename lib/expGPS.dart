import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'movementeanalizer.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io' show Platform;

// 1. CLASSE DE DADOS (Átomo)
class Pontodetreino {
  final DateTime tempo;
  final double lat;
  final double long;
  final double velocidade;
  final int cadencia;

  Pontodetreino({
    required this.tempo,
    required this.lat,
    required this.long,
    required this.velocidade,
    required this.cadencia,
  });
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
  static const double _velocidadeMaxima = 12.0; 

  double _emaVelocidade = 0.0;
  bool _emaInicializada = false;

  static const double _emaAlpha = 0.25;

  DateTime? _inicioSessao;

  // A LISTA PARA O STRAVA
  List<Pontodetreino> sessaoAtual = [];

  // 2. MÉTODO PARA LIGAR O TRACKING (Recebe o analyzer para saber a voga)
  void iniciarTracking(ImprovedMovementAnalyzer analyzer) {
    // 1. CRIAR AS DEFINIÇÕES BASEADAS NO SISTEMA OPERATIVO
    LocationSettings settings;

    if (Platform.isAndroid) {
      // DEFINIÇÕES COM PASSE VIP PARA ANDROID
      settings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        forceLocationManager: true, // Ajuda a manter o sinal forte
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Treino de Remo",
          notificationText: "A gravar a tua sessão...",
          enableWakeLock: true, // Não deixa o processador adormecer!
        ),
      );
    } else {
      // DEFINIÇÕES NORMAIS PARA iOS (por agora)
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
          _processarPonto(pos, analyzer.strokesPerMinute.round(), analyzer.isRecording);
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

  // 3. MÉTODO DE CÁLCULO E REGISTO (Limpo e sem erros)
  void _processarPonto(Position novaPosicao, int voga, bool gravando) {
    final distancia = Geolocator.distanceBetween(
      ultimaPosicao!.latitude, ultimaPosicao!.longitude,
      novaPosicao.latitude, novaPosicao.longitude,
    );

    final tempoDecorrido = novaPosicao.timestamp
        .difference(ultimaPosicao!.timestamp)
        .inMilliseconds / 1000.0;

    if (tempoDecorrido <= 0) return;

    double velocidadeInstantanea = novaPosicao.speed;
    
    // Se o GPS disser que a velocidade é 0, mas andámos, calculamos à mão
    if (velocidadeInstantanea <= 0 && distancia > _distanciaMinima) {
      velocidadeInstantanea = distancia / tempoDecorrido;
    }

    // ---------------------------------------------------------
    // O TEU SANITY CHECK DINÂMICO (RATE OF CHANGE FILTER)
    // ---------------------------------------------------------
    if (_emaInicializada) {
      double diferenca = velocidadeInstantanea - _emaVelocidade;
      
      double limiteAceleracao = 2.0 * tempoDecorrido;
      double limiteTravagem = 2.0 * tempoDecorrido;
      
      if (diferenca > limiteAceleracao) {
        velocidadeInstantanea = _emaVelocidade + limiteAceleracao;
      } else if (diferenca < -limiteTravagem) {
        velocidadeInstantanea = _emaVelocidade - limiteTravagem;
      }
    }

    // Barreira de segurança final (ninguém rema a mais de 25 km/h / 7 m/s)
    if (velocidadeInstantanea > 7.0) velocidadeInstantanea = 7.0; 

    if (distancia > _distanciaMinima && distancia < 20.0) { 
      distanciaTotal += distancia;
      distanciaUltimaRemada = distancia;
      _inicioSessao ??= DateTime.now(); // ← só define uma vez
    }

    // REGISTO PARA O STRAVA
    if (gravando) {
      sessaoAtual.add(
        Pontodetreino(
          tempo: DateTime.now(),
          lat: novaPosicao.latitude,
          long: novaPosicao.longitude,
          velocidade: velocidadeInstantanea,
          cadencia: voga,
        ),
      );
    }

    // Envia a velocidade limpa para a média móvel
    _atualizarVelocidadeMedia(velocidadeInstantanea);
    notifyListeners();
  }

  // A função da Média Móvel volta a ser a original, com um corte seguro
  void _atualizarVelocidadeMedia(double novaVelocidade) {
    if (!_emaInicializada) {
      _emaVelocidade = novaVelocidade;
      _emaInicializada = true;
    } else {
      _emaVelocidade = _emaAlpha * novaVelocidade + (1 - _emaAlpha) * _emaVelocidade;
    }

    velocidadeAtual = _emaVelocidade;

    if (velocidadeAtual > 0.8) {
      parcialPor500m = 500.0 / velocidadeAtual;
    } else {
      parcialPor500m = 0.0;
    }
  }

  // MÉTODOS DE UTILIDADE
  String getAverageParcialFormatado() {
      if (_inicioSessao == null || distanciaTotal < 10) return "--:--";
      
      final segundosTotais = DateTime.now().difference(_inicioSessao!).inSeconds.toDouble();
      final averagePor500m = (segundosTotais / distanciaTotal) * 500.0;
      
      if (averagePor500m <= 0 || averagePor500m > 3600) return "--:--";
      final minutos = (averagePor500m / 60).floor();
      final segundos = (averagePor500m % 60).floor();
      return "${minutos.toString().padLeft(1, '0')}:${segundos.toString().padLeft(2, '0')}";
    }

  String getParcialFormatado() {
    if (parcialPor500m <= 0 || parcialPor500m > 3600) return "--:--";
    final minutos = (parcialPor500m / 60).floor();
    final segundos = (parcialPor500m % 60).floor();
    return "${minutos.toString().padLeft(1, '0')}:${segundos.toString().padLeft(2, '0')}";
  }

  String getQualidadeGPS() {
    if (ultimaPosicao == null) return "A procurar...";
    final precisao = ultimaPosicao!.accuracy;
    if (precisao <= 4) return "Excelente (${precisao.toStringAsFixed(1)}m)";
    if (precisao <= 15) return "Bom (${precisao.toStringAsFixed(1)}m)";
    return "Fraco (${precisao.toStringAsFixed(1)}m)";
  }

  double getVelocidadeKmh() => velocidadeAtual * 3.6;

  Future<void> pararTracking() async {
    await _posicaoSubscription?.cancel();
    _posicaoSubscription = null;
    ultimaPosicao = null;
  }
  
  void resetDados() {
    distanciaTotal = 0.0;
    distanciaUltimaRemada = 0.0;
    velocidadeAtual = 0.0;
    parcialPor500m = 0.0;
    _emaVelocidade = 0.0;
    _emaInicializada = false;
    _inicioSessao = null;
    sessaoAtual.clear();
    notifyListeners();
  }

  Future<Position> getPermissao() async {
    bool ativado = await Geolocator.isLocationServiceEnabled();
    if (!ativado) throw Exception('Localização desligada.');

    LocationPermission permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
      if (permissao == LocationPermission.denied) throw Exception('Permissão negada.');
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.bestForNavigation);
  }

  // --- FUNÇÃO PARA EXPORTAR PARA STRAVA (TCX) ---
  Future<void> exportarTreinoTCX() async {
    debugPrint("🚣 EXPORT: sessaoAtual tem ${sessaoAtual.length} pontos");
    erro = '';
    
    if (sessaoAtual.isEmpty) {
      erro = "Sem dados GPS para exportar. Verifica se o GPS teve sinal durante o treino.";
      notifyListeners();
      return;
    }

    try {
      String tcx = '''<?xml version="1.0" encoding="UTF-8"?>
  <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
    <Activities>
      <Activity Sport="Rowing">
        <Id>${sessaoAtual.first.tempo.toUtc().toIso8601String()}</Id>
        <Lap StartTime="${sessaoAtual.first.tempo.toUtc().toIso8601String()}">
          <TotalTimeSeconds>${sessaoAtual.last.tempo.difference(sessaoAtual.first.tempo).inSeconds}</TotalTimeSeconds>
          <DistanceMeters>${distanciaTotal.toStringAsFixed(1)}</DistanceMeters>
          <Intensity>Active</Intensity>
          <TriggerMethod>Manual</TriggerMethod>
          <Track>''';

      for (var ponto in sessaoAtual) {
        tcx += '''
            <Trackpoint>
              <Time>${ponto.tempo.toUtc().toIso8601String()}</Time>
              <Position>
                <LatitudeDegrees>${ponto.lat}</LatitudeDegrees>
                <LongitudeDegrees>${ponto.long}</LongitudeDegrees>
              </Position>
              <Cadence>${ponto.cadencia}</Cadence>
              <Extensions>
                <TPX xmlns="http://www.garmin.com/xmlschemas/ActivityExtension/v2">
                  <Speed>${ponto.velocidade}</Speed>
                </TPX>
              </Extensions>
            </Trackpoint>''';
      }

      tcx += '''
          </Track>
        </Lap>
      </Activity>
    </Activities>
  </TrainingCenterDatabase>''';

      final directory = await getTemporaryDirectory();
      final dataStr = DateTime.now().toIso8601String().replaceAll(':', '').split('.').first;
      final file = File('${directory.path}/Treino_Rowing_$dataStr.tcx');
      await file.writeAsString(tcx);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'O meu treino de Remo!',
      );

    } catch (e) {
      erro = "Erro ao exportar: $e";
      notifyListeners();
    }
  }
}