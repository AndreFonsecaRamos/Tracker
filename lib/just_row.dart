import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'exp_gps.dart';
import 'movement_analyzer.dart';
import 'heart_rate_controller.dart';
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
      if (_horaQueComecou != null && mounted) {
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
    final hr = context.read<HeartRateController>();
    
    try {
      await gps.getPermissao();
      if (!mounted) return;
      gps.iniciarTracking(analyzer, hrController: hr);

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
            gps.resetDados(); 
            _startTimer();
          }
        });
      } else {
        _startTimer();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro GPS: $e')));
    }
  }

  void _stopTimer() {
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final minutos = _tempoAtual.inMinutes;
    final segundos = _tempoAtual.inSeconds % 60;
    final stringTempo = comeco > 0 
        ? comeco.toString() 
        : "${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}";

    if (isLandscape) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: PM5Monitor(
                  tempo: stringTempo,
                  spm: context.select<ImprovedMovementAnalyzer, String>((a) => a.strokesPerMinute > 0 ? a.strokesPerMinute.toStringAsFixed(0) : "0"),
                  parcial: context.select<GPSController, String>((g) => g.getParcialFormatado()),
                  distancia: context.select<GPSController, String>((g) => g.distanciaTotal.toStringAsFixed(0)),
                  averageParcial: context.select<GPSController, String>((g) => g.getAverageParcialFormatado()),
                  heartRate: context.select<HeartRateController, int>((hr) => hr.heartRate),
                ),
              ),
            ],
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
                Selector<GPSController, String>(
                  selector: (_, gps) => gps.getParcialFormatado(),
                  builder: (_, parcial, __) => StatCard(
                    title: "Parcial 500m",
                    value: parcial,
                    baseColor: Colors.blue,
                  ),
                ),
                Selector<ImprovedMovementAnalyzer, String>(
                  selector: (_, analyzer) => analyzer.strokesPerMinute.toStringAsFixed(1),
                  builder: (_, spm, __) => StatCard(
                    title: "Voga Atual",
                    value: spm,
                    baseColor: Colors.green,
                  ),
                ),
                Selector<GPSController, String>(
                  selector: (_, gps) => "${gps.distanciaTotal.toStringAsFixed(0)}m",
                  builder: (_, distancia, __) => StatCard(
                    title: "Distância",
                    value: distancia,
                    baseColor: Colors.orange,
                  ),
                ),
                Selector<ImprovedMovementAnalyzer, int>(
                  selector: (_, analyzer) => analyzer.totalStrokes,
                  builder: (_, strokes, __) => StatCard(
                    title: "Remadas",
                    value: "$strokes",
                    baseColor: Colors.purple,
                  ),
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
              child: Selector<ImprovedMovementAnalyzer, String>(
                selector: (_, a) => a.getMovementStatus(),
                builder: (_, status, __) => Column(
                  children: [
                    Text(
                      status,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    Consumer<ImprovedMovementAnalyzer>(
                      builder: (_, analyzer, __) {
                        if (analyzer.lastStrokeInterval == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "Último intervalo: ${(analyzer.lastStrokeInterval!.inMilliseconds / 1000).toStringAsFixed(1)}s",
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                          ),
                        );
                      },
                    ),
                  ],
                ),
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
                      Consumer<ImprovedMovementAnalyzer>(
                        builder: (_, analyzer, __) => Text("Aceleração: ${analyzer.magnitude.toStringAsFixed(1)} m/s²"),
                      ),
                      Consumer<ImprovedMovementAnalyzer>(
                        builder: (_, analyzer, __) => Text("X: ${analyzer.x.toStringAsFixed(1)} | Y: ${analyzer.y.toStringAsFixed(1)} | Z: ${analyzer.z.toStringAsFixed(1)}", style: const TextStyle(fontFamily: 'monospace')),
                      ),
                      const Divider(),
                      Consumer<GPSController>(
                        builder: (_, gps, __) => Text("Sinal GPS: ${gps.getQualidadeGPS()}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                      Consumer<GPSController>(
                        builder: (_, gps, __) {
                          if (gps.velocidadeAtual <= 0) return const SizedBox.shrink();
                          return Text("Velocidade pura: ${gps.getVelocidadeKmh().toStringAsFixed(1)} km/h");
                        },
                      ),
                      Consumer<ImprovedMovementAnalyzer>(
                        builder: (_, analyzer, __) {
                          if (analyzer.errorMessage.isEmpty) return const SizedBox.shrink();
                          return Text(analyzer.errorMessage, style: const TextStyle(color: Colors.red));
                        },
                      ),
                      Consumer<GPSController>(
                        builder: (_, gps, __) {
                          if (gps.erro.isEmpty) return const SizedBox.shrink();
                          return Text(gps.erro, style: const TextStyle(color: Colors.red));
                        },
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          final log = context.read<ImprovedMovementAnalyzer>().logPicos.join('\n');
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Log de Picos'),
                              content: SizedBox(
                                width: double.maxFinite,
                                height: 400,
                                child: SingleChildScrollView(
                                  reverse: true,
                                  child: Text(
                                    log.isEmpty ? 'Sem dados ainda.' : log,
                                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    context.read<ImprovedMovementAnalyzer>().logPicos.clear();
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Limpar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Fechar'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.bug_report, size: 16),
                        label: const Text('Ver log de picos'),
                      ),
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
