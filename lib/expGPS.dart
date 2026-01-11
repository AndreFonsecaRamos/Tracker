import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class GPSController extends ChangeNotifier {
  double lat = 0.0;
  double long = 0.0;
  String erro = '';
  double distanciaTotal = 0.0;
  double distanciaUltimaRemada = 0.0;
  double velocidadeAtual = 0.0; // m/s
  double parcialPor500m = 0.0; // tempo estimado para 500m

  Position? ultimaPosicao;
  StreamSubscription<Position>? _posicaoSubscription;
  DateTime? _ultimoUpdate;

  // Configurações
  static const double _precisaoMinima = 10.0; // metros
  static const double _distanciaMinima = 1.0; // metros
  static const double _distanciaMaxima = 25.0; // metros
  static const double _velocidadeMaxima = 15.0; // m/s (~54 km/h)

  void iniciarTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1, // captura movimento fino
    );

    _posicaoSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        if (pos.accuracy > _precisaoMinima) return; // ignora leituras ruins

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

    if (distancia < _distanciaMinima || distancia > _distanciaMaxima) return;

    final tempoDecorrido = novaPosicao.timestamp
        .difference(ultimaPosicao!.timestamp)
        .inMilliseconds /
        1000.0;

    if (tempoDecorrido <= 0) return;

    final velocidade = distancia / tempoDecorrido;
    if (velocidade > _velocidadeMaxima) return;

    // Atualiza dados
    distanciaTotal += distancia;
    distanciaUltimaRemada = distancia;
    velocidadeAtual = velocidade;

    if (velocidadeAtual > 0) {
      parcialPor500m = 500.0 / velocidadeAtual;
    }
  }

  String getParcialFormatado() {
    if (parcialPor500m <= 0 || parcialPor500m > 3600) return "--:--";
    final minutos = (parcialPor500m / 60).floor();
    final segundos = (parcialPor500m % 60).floor();
    return "${minutos.toString().padLeft(1, '0')}:${segundos.toString().padLeft(2, '0')}";
  }

  String getQualidadeGPS() {
    if (ultimaPosicao == null) return "Sem sinal";
    final precisao = ultimaPosicao!.accuracy;
    if (precisao <= 3) return "Excelente (${precisao.toStringAsFixed(1)}m)";
    if (precisao <= 5) return "Muito bom (${precisao.toStringAsFixed(1)}m)";
    if (precisao <= 10) return "Bom (${precisao.toStringAsFixed(1)}m)";
    if (precisao <= 20) return "Razoável (${precisao.toStringAsFixed(1)}m)";
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
  }

  Future<Position> getPermissao() async {
    try {
      LocationPermission permissao;

      bool ativado = await Geolocator.isLocationServiceEnabled();
      if (!ativado) {
        throw Exception('Por favor, habilite a localização no smartphone');
      }

      permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
        if (permissao == LocationPermission.denied) {
          throw Exception('Você precisa autorizar o acesso à localização');
        }
      }

      if (permissao == LocationPermission.deniedForever) {
        throw Exception('Você precisa autorizar o acesso à localização');
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
