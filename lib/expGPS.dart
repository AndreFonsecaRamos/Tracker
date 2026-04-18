import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

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

  // MÉDIA MÓVEL DE 10 SEGUNDOS (Estabilidade PM5)
  final List<double> _historicoVelocidades = [];
  static const int _tamanhoMediaMovel = 10; 

  void iniciarTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0, // Atualiza todos os segundos sem hesitar
    );

    _posicaoSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        if (pos.accuracy > _precisaoMinima) return;

        lat = pos.latitude;
        long = pos.longitude;

        if (ultimaPosicao != null) {
          _calcularMovimento(pos);
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

  void _calcularMovimento(Position novaPosicao) {
    final distancia = Geolocator.distanceBetween(
      ultimaPosicao!.latitude,
      ultimaPosicao!.longitude,
      novaPosicao.latitude,
      novaPosicao.longitude,
    );

    final tempoDecorrido = novaPosicao.timestamp
        .difference(ultimaPosicao!.timestamp)
        .inMilliseconds / 1000.0;

    if (tempoDecorrido <= 0) return;

    // VELOCIDADE DOPPLER DIRETA DO CHIP
    double velocidadeInstantanea = novaPosicao.speed;

    if (velocidadeInstantanea <= 0 && distancia > _distanciaMinima) {
      velocidadeInstantanea = distancia / tempoDecorrido;
    }

    if (velocidadeInstantanea > _velocidadeMaxima) return; 

    if (distancia < _distanciaMinima && velocidadeInstantanea < 0.5) {
      _atualizarVelocidadeMedia(0.0);
      return;
    }

    if (distancia < 20.0) { 
      distanciaTotal += distancia;
      distanciaUltimaRemada = distancia;
    }

    _atualizarVelocidadeMedia(velocidadeInstantanea);
  }

  void _atualizarVelocidadeMedia(double novaVelocidade) {
    _historicoVelocidades.add(novaVelocidade);
    
    if (_historicoVelocidades.length > _tamanhoMediaMovel) {
      _historicoVelocidades.removeAt(0);
    }

    velocidadeAtual = _historicoVelocidades.reduce((a, b) => a + b) / _historicoVelocidades.length;

    if (velocidadeAtual > 0.5) { 
      parcialPor500m = 500.0 / velocidadeAtual;
    } else {
      parcialPor500m = 0.0; 
    }
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
    if (precisao <= 8) return "Muito bom (${precisao.toStringAsFixed(1)}m)";
    if (precisao <= 15) return "Bom (${precisao.toStringAsFixed(1)}m)";
    return "Fraco (${precisao.toStringAsFixed(1)}m)";
  }

  double getVelocidadeKmh() {
    return velocidadeAtual * 3.6;
  }

  Future<void> pararTracking() async {
    await _posicaoSubscription?.cancel();
    _posicaoSubscription = null;
    ultimaPosicao = null;
    _ultimoUpdate = null;
    _historicoVelocidades.clear();
  }
  
  void resetDados() {
    distanciaTotal = 0.0;
    distanciaUltimaRemada = 0.0;
    velocidadeAtual = 0.0;
    parcialPor500m = 0.0;
    _historicoVelocidades.clear();
    notifyListeners();
  }

  Future<Position> getPermissao() async {
    try {
      LocationPermission permissao;

      bool ativado = await Geolocator.isLocationServiceEnabled();
      if (!ativado) throw Exception('Localização desligada.');

      permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
        if (permissao == LocationPermission.denied) throw Exception('Permissão negada.');
      }

      if (permissao == LocationPermission.deniedForever) {
        throw Exception('Permissão permanentemente negada.');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      lat = pos.latitude;
      long = pos.longitude;
      notifyListeners();
      return pos;
    } catch (e) {
      erro = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}