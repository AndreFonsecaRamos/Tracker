import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'expGPS.dart';
import 'movementeanalizer.dart';
import 'custom_widgets.dart';

class JustRow extends StatefulWidget { 
  const JustRow({super.key});

  @override
  State<JustRow> createState() => _JustRowState();
}

class _JustRowState extends State<JustRow> with WidgetsBindingObserver {
  int comeco = 3;
  Timer? _timer;
  
  DateTime? _horaQueComecou;
  Duration _tempoAcumuladoAntesDaPausa = Duration.zero;
  Duration _tempoAtual = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable(); 

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GPSController>().resetDados();
        context.read<ImprovedMovementAnalyzer>().reset();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_horaQueComecou != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Treino em pausa (App em segundo plano)')),
        );
      }
    }
  }

  void _resetCounters() {
    _stopTimer(); 
    context.read<GPSController>().resetDados();
    context.read<ImprovedMovementAnalyzer>().reset();
    
    setState(() {
      _horaQueComecou = null;
      _tempoAcumuladoAntesDaPausa = Duration.zero;
      _tempoAtual = Duration.zero;
      comeco = 3;
    }); 
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;

    _horaQueComecou = DateTime.now();
    // ABRIR O CADEADO DO ACELERÓMETRO
    context.read<ImprovedMovementAnalyzer>().startRecording();

    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _tempoAtual = _tempoAcumuladoAntesDaPausa + DateTime.now().difference(_horaQueComecou!);
      });
    });
  }

  void _startWork() async {
    if (_timer != null && _timer!.isActive) return; 
    final analyzer = context.read<ImprovedMovementAnalyzer>();

    final gps = context.read<GPSController>();
    
    try {
      await gps.getPermissao();
      gps.iniciarTracking(analyzer);

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
            // LIMPAR DADOS SUJOS DO GPS DURANTE A CONTAGEM
            gps.resetDados(); 
            _startTimer();
          }
        });
      } else {
        _startTimer();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro GPS: $e')));
    }
  }

  void _stopTimer() {
    // AVISAR O ECRÃ PARA ATUALIZAR (Mostrar o botão)
    setState(() { 
      if (_horaQueComecou != null) {
        _tempoAcumuladoAntesDaPausa += DateTime.now().difference(_horaQueComecou!);
        _horaQueComecou = null; 
      }
      _timer?.cancel();
      _timer = null;
    });
    
    context.read<ImprovedMovementAnalyzer>().stopRecording();
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
            distancia: gps.distanciaTotal.toStringAsFixed(0),
            averageParcial: gps.getAverageParcialFormatado(),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Just Row'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 10),
            Text(
              stringTempo,
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: comeco > 0 ? Colors.red : Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ControlButtons(
              onStart: _startWork,
              onStop: _stopTimer,
              onReset: _resetCounters,
            ),

            if (_timer == null && _tempoAtual.inSeconds > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: FilledButton.icon(
                  onPressed: _showCompletionDialog,
                  icon: const Icon(Icons.save),
                  label: const Text("FINALIZAR E EXPORTAR"),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
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
                  value: analyzer.strokesPerMinute.toStringAsFixed(1),
                  baseColor: Colors.green,
                ),
                StatCard(
                  title: "Distância",
                  value: "${gps.distanciaTotal.toStringAsFixed(0)}m",
                  baseColor: Colors.orange,
                ),
                StatCard(
                  title: "Remadas",
                  value: "${analyzer.totalStrokes}",
                  baseColor: Colors.purple,
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
              child: Column(
                children: [
                  Text(
                    analyzer.getMovementStatus(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  if (analyzer.lastStrokeInterval != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Último intervalo: ${(analyzer.lastStrokeInterval!.inMilliseconds / 1000).toStringAsFixed(1)}s",
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text("Dados Técnicos & GPS"),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text("Aceleração: ${analyzer.magnitude.toStringAsFixed(1)} m/s²"),
                      Text("X: ${analyzer.x.toStringAsFixed(1)} | Y: ${analyzer.y.toStringAsFixed(1)} | Z: ${analyzer.z.toStringAsFixed(1)}", style: const TextStyle(fontFamily: 'monospace')),
                      const Divider(),
                      Text("Sinal GPS: ${gps.getQualidadeGPS()}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      if (gps.velocidadeAtual > 0)
                        Text("Velocidade pura: ${gps.getVelocidadeKmh().toStringAsFixed(1)} km/h"),
                      if (analyzer.errorMessage.isNotEmpty) 
                        Text(analyzer.errorMessage, style: const TextStyle(color: Colors.red)),
                      if (gps.erro.isNotEmpty) 
                        Text(gps.erro, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCompletionDialog() {
    final analyzer = context.read<ImprovedMovementAnalyzer>();
    final minutos = _tempoAtual.inMinutes;
    final segundos = _tempoAtual.inSeconds % 60;
    final tempoFinalStr = "${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🏁 Treino Concluído!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Distância: ${context.read<GPSController>().distanciaTotal.toStringAsFixed(0)}m'),
              Text('Remadas: ${analyzer.totalStrokes}'),
              Text('Tempo: $tempoFinalStr'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                final gps = context.read<GPSController>();
                nav.pop();
                
                await gps.exportarTreinoTCX();
                
                // Se houve erro, mostra ao utilizador
                if (gps.erro.isNotEmpty && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(gps.erro),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Exportar (Strava)', style: TextStyle(color: Colors.orange)),
            ),
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
}