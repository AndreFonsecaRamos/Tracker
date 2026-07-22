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
  
  bool _isDescanso = false;
  Duration _tempoRestanteDescanso = Duration.zero;

  DateTime? _horaQueComecou;
  Duration _tempoAcumuladoAntesDaPausa = Duration.zero;
  Duration _tempoAtual = Duration.zero;

  int _serieAtual = 1;

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
      _isDescanso = false;
      _horaQueComecou = null;
      _tempoAcumuladoAntesDaPausa = Duration.zero;
      _tempoAtual = Duration.zero;
      comeco = 3;
      _serieAtual = 1;
    });
  }

  // --- GATILHO AUTOMÁTICO: DISTÂNCIA ---
  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;

    _horaQueComecou = DateTime.now();
    context.read<ImprovedMovementAnalyzer>().startRecording();

    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final currentGps = context.read<GPSController>();
      final agora = DateTime.now();

      if (!_isDescanso) {
        // TRABALHO: Contar o tempo normalmente
        setState(() {
          _tempoAtual = _tempoAcumuladoAntesDaPausa + agora.difference(_horaQueComecou!);
        });

        // GATILHO 1: Atingiu os metros alvo?
        if (currentGps.distanciaTotal >= widget.metros) {
           setState(() {
             _isDescanso = true; 
             _tempoRestanteDescanso = widget.intervalo; 
             _horaQueComecou = agora; // Reinicia o relógio interno para o descanso
             _tempoAcumuladoAntesDaPausa = _tempoAtual; // Guarda o tempo decorrido
           });
        }
      } else {
        // DESCANSO: Contagem decrescente
        final tempoPassado = agora.difference(_horaQueComecou!);
        final tempoAmostrar = _tempoRestanteDescanso - tempoPassado;

        if (tempoAmostrar.inSeconds <= 0) {
          // GATILHO 2: O descanso terminou
          setState(() {
            _isDescanso = false; 
            _horaQueComecou = agora;
            _serieAtual++; // ← ADICIONA AQUI
          });
          currentGps.resetDados(); 
        } else {
          setState(() {
            _tempoAtual = tempoAmostrar;
          });
        }
      }
    });
  }

  void _startWork() async {
    if (_timer != null && _timer!.isActive) return;

    final gps = context.read<GPSController>();
    final analyzer = context.read<ImprovedMovementAnalyzer>();

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
            gps.resetDados();
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

  // --- JANELA DE FIM E EXPORTAÇÃO ---
  void _showCompletionDialog() {
    final analyzer = context.read<ImprovedMovementAnalyzer>();
    final gps = context.read<GPSController>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🏆 Treino Concluído!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Distância Alvo: ${widget.metros.toStringAsFixed(0)}m'),
              Text('Remadas: ${analyzer.totalStrokes}'),
              Text('Voga média: ${analyzer.averageStrokeRate.toStringAsFixed(1)} spm'),
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

  @override
  Widget build(BuildContext context) {
    final gps = context.watch<GPSController>();
    final analyzer = context.watch<ImprovedMovementAnalyzer>();

    double metrosRestantes = math.max(0, widget.metros - gps.distanciaTotal);
    
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
            serieAtual: _serieAtual, 
            averageParcial: gps.getAverageParcialFormatado(),
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
            // CABEÇALHO DO ESTADO (DESCANSO/TREINO)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _isDescanso ? Colors.orange.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isDescanso ? "DESCANSO" : "TREINO",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: _isDescanso ? Colors.orange.shade800 : Colors.green.shade800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              stringTempo,
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: comeco > 0 ? Colors.red : (_isDescanso ? Colors.orange : Colors.green),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            if (!_isDescanso) ...[
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
            ],
            const SizedBox(height: 20),
            ControlButtons(
              onStart: _startWork,
              onStop: _stopTimer,
              onReset: _resetCounters,
            ),
            // --- BOTÃO DE FINALIZAÇÃO MANUAL ---
            if (comeco == 0 && _timer == null)
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
                  value: "${analyzer.strokesPerMinute.toStringAsFixed(1)}",
                  baseColor: Colors.green,
                ),
                StatCard(
                  title: "Tempo",
                  value: stringTempo, 
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