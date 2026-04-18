import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'expGPS.dart';
import 'movementeanalizer.dart';
import 'custom_widgets.dart';

class SegundaPagina extends StatefulWidget {
  final Duration tempo;
  final Duration intervalo;

  const SegundaPagina({
    super.key,
    required this.tempo,
    required this.intervalo,
  });

  @override
  State<SegundaPagina> createState() => _SegundaPaginaState();
}

class _SegundaPaginaState extends State<SegundaPagina> with WidgetsBindingObserver {
  int comeco = 3;
  Timer? _timer;
  
  bool _isDescanso = false;
  Duration _tempoAtual = Duration.zero;
  
  Duration _tempoRestanteFase = Duration.zero;
  DateTime? _horaUltimoResume;

  @override
  void initState() {
    super.initState();
    _tempoRestanteFase = widget.tempo;
    _tempoAtual = widget.tempo;
    
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
      if (_horaUltimoResume != null) {
        _stopTimer();
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
      comeco = 3;
      _tempoRestanteFase = widget.tempo;
      _tempoAtual = widget.tempo;
      _horaUltimoResume = null;
    });
  }

  // --- GATILHO AUTOMÁTICO: TEMPO ---
  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;

    _horaUltimoResume = DateTime.now();
    context.read<ImprovedMovementAnalyzer>().startRecording();

    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final agora = DateTime.now();
      final tempoPassado = agora.difference(_horaUltimoResume!);
      final tempoAmostrar = _tempoRestanteFase - tempoPassado;

      if (tempoAmostrar.inSeconds <= 0) {
        if (!_isDescanso) {
          // Terminou o Trabalho, vai para Descanso
          setState(() {
            _isDescanso = true; 
            _tempoRestanteFase = widget.intervalo; 
            _horaUltimoResume = DateTime.now(); 
            _tempoAtual = _tempoRestanteFase;
          });
        } else {
          // Terminou o Descanso, vai para Trabalho
          setState(() {
            _isDescanso = false; 
            _tempoRestanteFase = widget.tempo; 
            _horaUltimoResume = DateTime.now(); 
            _tempoAtual = _tempoRestanteFase;
          });
          
          context.read<GPSController>().resetDados(); 
        }
      } else {
        setState(() {
          _tempoAtual = tempoAmostrar;
        });
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro GPS: $e')));
    }
  }

  void _stopTimer() {
    // AVISAR O ECRÃ PARA ATUALIZAR (Mostrar o botão)
    setState(() {
      if (_horaUltimoResume != null) {
        _tempoRestanteFase = _tempoRestanteFase - DateTime.now().difference(_horaUltimoResume!);
        _horaUltimoResume = null;
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
          title: const Text('🏁 Treino Concluído!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Distância Total: ${gps.distanciaTotal.toStringAsFixed(0)}m'),
              Text('Remadas: ${analyzer.totalStrokes}'),
              Text('Voga Média: ${analyzer.averageStrokeRate.toStringAsFixed(1)} spm'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                context.read<GPSController>().exportarTreinoTCX();
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
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Treino por Tempo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 10),
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