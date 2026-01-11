import 'package:flutter/material.dart';
import 'dart:async';
import 'expGPS.dart';
import 'movementeanalizer.dart';

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

class _SegundaPaginaState extends State<SegundaPagina> {
  int comeco = 3;
  Timer? _timer;
  late Duration _tempoAtual;
  bool _isDescanso = false;

  // Analisador de movimento
  final ImprovedMovementAnalyzer _movementAnalyzer = ImprovedMovementAnalyzer();

  // Variáveis GPS
  final gps = GPSController();

  @override
  void initState() {
    super.initState();
    _tempoAtual = widget.tempo;
    
    // Inicializar análise de movimento
    _movementAnalyzer.startAnalysis(onStrokeDetected: () {
      if (mounted) setState(() {});
    });
  }

  void _resetCounters() {
    setState(() {
      _movementAnalyzer.reset();
      gps.distanciaTotal = 0.0;
      gps.distanciaUltimaRemada = 0.0;
      gps.parcialPor500m = 0.0;
    });
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_tempoAtual.inSeconds <= 0) {
        setState(() {
          _isDescanso = !_isDescanso;
          _tempoAtual = _isDescanso ? widget.intervalo : widget.tempo;
        });
      } else {
        setState(() {
          _tempoAtual = _tempoAtual - const Duration(seconds: 1);
        });
      }
    });
  }

  void _startWork() {
    if (_timer != null && _timer!.isActive) return;

    setState(() {
      comeco = 3;
    });

    gps.iniciarTracking();
    gps.addListener(() {
      if (mounted) setState(() {});
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (comeco > 1) {
        setState(() {
          comeco--;
        });
      } else {
        timer.cancel();
        setState(() {
          comeco = 0;
        });
        _startTimer();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    gps.pararTracking();
    gps.removeListener(() {});
    _movementAnalyzer.dispose();
    super.dispose();
  }

  // Método auxiliar movido para dentro da classe
  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutos = _tempoAtual.inMinutes;
    final segundos = _tempoAtual.inSeconds % 60;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Treino por Tempo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 20),

            // Indicador de fase melhorado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isDescanso ? Colors.orange.shade100 : Colors.green.shade100,
                border: Border.all(
                  color: _isDescanso ? Colors.orange : Colors.green,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isDescanso ? "DESCANSO" : "TREINO",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: _isDescanso ? Colors.orange.shade800 : Colors.green.shade800,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Display do tempo
            Text(
              comeco > 0 
                ? comeco.toString()
                : "${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}",
              style: TextStyle(
                fontSize: comeco > 0 ? 72 : 48,
                fontWeight: FontWeight.bold,
                color: comeco > 0 ? Colors.red : (_isDescanso ? Colors.orange : Colors.green),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            // NOVO: Display do parcial 500m
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200, width: 1),
              ),
              child: Column(
                children: [
                  Text(
                    "Parcial 500m",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gps.getParcialFormatado(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  if (gps.velocidadeAtual > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Velocidade: ${gps.getVelocidadeKmh().toStringAsFixed(1)} km/h",
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Botões de controle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _startWork,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _stopTimer,
                  icon: const Icon(Icons.pause),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _resetCounters,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Secção de análise de movimento
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.rowing, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          "Análise de Remada",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Divider(),
                    
                    // Display das remadas
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "${_movementAnalyzer.totalStrokes}",
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const Text(
                            "REMADAS",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Grid de estatísticas
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: [
                        _buildStatItem("Taxa Atual", "${_movementAnalyzer.strokesPerMinute.toStringAsFixed(1)} spm"),
                        _buildStatItem("Taxa Média", "${_movementAnalyzer.averageStrokeRate.toStringAsFixed(1)} spm"),
                        _buildStatItem("Tempo Sessão", _movementAnalyzer.getSessionDurationString()),
                        _buildStatItem("Distância", "${gps.distanciaTotal.toStringAsFixed(0)}m"),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Status do movimento
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _movementAnalyzer.getMovementStatus(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          if (_movementAnalyzer.lastStrokeInterval != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Último intervalo: ${(_movementAnalyzer.lastStrokeInterval!.inMilliseconds / 1000).toStringAsFixed(1)}s",
                              style: const TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Dados técnicos expansíveis
                    ExpansionTile(
                      title: const Text("Dados Técnicos"),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(
                                "Balanço: ${_movementAnalyzer.magnitude.toStringAsFixed(1)} m/s²",
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "X: ${_movementAnalyzer.x.toStringAsFixed(1)} | "
                                "Y: ${_movementAnalyzer.y.toStringAsFixed(1)} | "
                                "Z: ${_movementAnalyzer.z.toStringAsFixed(1)}",
                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                              ),
                              if (_movementAnalyzer.errorMessage.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _movementAnalyzer.errorMessage,
                                  style: const TextStyle(fontSize: 12, color: Colors.red),
                                ),
                              ],
                              // NOVO: Informações GPS
                              const SizedBox(height: 8),
                              Text(
                                "GPS: ${gps.getQualidadeGPS()}",
                                style: const TextStyle(fontSize: 12, color: Colors.green),
                              ),
                              if (gps.erro.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "Erro GPS: ${gps.erro}",
                                  style: const TextStyle(fontSize: 12, color: Colors.red),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}