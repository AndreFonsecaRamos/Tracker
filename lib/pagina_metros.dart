import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'expGPS.dart';
import 'movementeanalizer.dart';
import 'custom_widgets.dart';

class PaginaMetros extends StatefulWidget {
  final double metros;
  final Duration intervalo;

  const PaginaMetros({
    super.key,
    required this.metros,
    required this.intervalo,
  });

  @override
  State<PaginaMetros> createState() => _PaginaMetrosState();
}

class _PaginaMetrosState extends State<PaginaMetros> with WidgetsBindingObserver {
  int comeco = 3;
  Timer? _timer;
  bool _concluido = false;

  DateTime? _horaQueComecou;
  Duration _tempoAcumuladoAntesDaPausa = Duration.zero;
  Duration _tempoAtual = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    WakelockPlus.enable(); 
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_horaQueComecou != null) {
        _stopTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Treino em pausa (App em segundo plano)')),
        );
      }
    }
  }

  void _showCompletionDialog(ImprovedMovementAnalyzer analyzer, String tempoFinal) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🏆 Distância Completada!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Distância: ${widget.metros.toStringAsFixed(0)}m'),
              Text('Remadas: ${analyzer.totalStrokes}'),
              Text('Taxa média: ${analyzer.averageStrokeRate.toStringAsFixed(1)} spm'),
              Text('Tempo: $tempoFinal'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetCounters();
              },
              child: const Text('Novo Treino'),
            ),
          ],
        );
      },
    );
  }

  void _resetCounters() {
    _stopTimer();
    context.read<GPSController>().resetDados();
    context.read<ImprovedMovementAnalyzer>().reset();

    setState(() {
      _concluido = false;
      _horaQueComecou = null;
      _tempoAcumuladoAntesDaPausa = Duration.zero;
      _tempoAtual = Duration.zero;
      comeco = 3;
    });
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;

    _horaQueComecou = DateTime.now();

    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final currentGps = context.read<GPSController>();
      
      setState(() {
        _tempoAtual = _tempoAcumuladoAntesDaPausa + DateTime.now().difference(_horaQueComecou!);
      });

      if (currentGps.distanciaTotal >= widget.metros && !_concluido) {
         _concluido = true;
         _stopTimer();
         
         final minutos = _tempoAtual.inMinutes;
         final segundos = _tempoAtual.inSeconds % 60;
         final tempoFinalStr = "${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}";
         
         _showCompletionDialog(context.read<ImprovedMovementAnalyzer>(), tempoFinalStr);
      }
    });
  }

  void _startWork() async {
    if (_timer != null && _timer!.isActive) return;

    final gps = context.read<GPSController>();
    try {
      await gps.getPermissao();
      gps.iniciarTracking();

      if (comeco > 0) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }

          if (comeco > 1) {
            setState(() { comeco--; });
          } else {
            timer.cancel();
            setState(() { comeco = 0; });
            _startTimer();
          }
        });
      } else {
        _startTimer();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  void _stopTimer() {
    if (_horaQueComecou != null) {
      _tempoAcumuladoAntesDaPausa += DateTime.now().difference(_horaQueComecou!);
      _horaQueComecou = null; 
    }
    _timer?.cancel();
    _timer = null;
    context.read<GPSController>().pararTracking();
  }

  @override
  void dispose() {
    _stopTimer();
    WidgetsBinding.instance.removeObserver(this); 
    WakelockPlus.disable(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gps = context.watch<GPSController>();
    final analyzer = context.watch<ImprovedMovementAnalyzer>();

    double metrosRestantes = math.max(0, widget.metros - gps.distanciaTotal);
    
    // FORMATAÇÃO DO TEMPO (Igual ao Just Row)
    final minutos = _tempoAtual.inMinutes;
    final segundos = _tempoAtual.inSeconds % 60;
    final stringTempo = comeco > 0 
        ? comeco.toString() 
        : "${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}";

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return Scaffold(
        body: SafeArea(
          child: PM5Monitor(
            tempo: stringTempo,
            spm: analyzer.strokesPerMinute > 0 ? analyzer.strokesPerMinute.toStringAsFixed(0) : "0",
            parcial: gps.getParcialFormatado(),
            distancia: metrosRestantes.toStringAsFixed(0),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Treino por Distância"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 10),
            
            // Text do Tempo por cima igual ao Just Row
            Text(
              stringTempo,
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: comeco > 0 ? Colors.red : Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            const Text(
              "METROS RESTANTES",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Text(
              metrosRestantes.toStringAsFixed(0),
              style: const TextStyle(
                fontSize: 72, 
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ControlButtons(
              onStart: _startWork,
              onStop: _stopTimer,
              onReset: _resetCounters,
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, 
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2, 
              children: [
                StatCard(
                  title: "Parcial 500m",
                  value: gps.getParcialFormatado(),
                  baseColor: Colors.blue,
                ),
                StatCard(
                  title: "Voga Atual",
                  value: "${analyzer.strokesPerMinute.toStringAsFixed(1)}",
                  baseColor: Colors.green,
                ),
                StatCard(
                  title: "Tempo",
                  value: stringTempo, // Agora usa o tempo formatado correto!
                  baseColor: Colors.purple,
                ),
                StatCard(
                  title: "Remadas",
                  value: "${analyzer.totalStrokes}",
                  baseColor: Colors.teal,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                analyzer.getMovementStatus(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}