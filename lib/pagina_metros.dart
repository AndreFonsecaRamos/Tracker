import 'dart:async';
import 'package:flutter/material.dart';
import 'expGPS.dart';
import 'movementeanalizer.dart';

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

class _PaginaMetrosState extends State<PaginaMetros> {
  Timer? _timer;
  double _metrosRestantes = 0;
  bool _ativo = false;

  final ImprovedMovementAnalyzer _movementAnalyzer = ImprovedMovementAnalyzer();

  // Variáveis GPS
  final gps = GPSController();
  DateTime? _ultimosalto;
  double parcialINmilisseconds = 0;

  // Cálculos do parcial
  void parcial(double distanciaUltima) {
    DateTime agora = DateTime.now();
    if (_ultimosalto != null && agora.difference(_ultimosalto!).inMilliseconds > 200) {
      int diferencaTempo = agora.difference(_ultimosalto!).inMilliseconds;

      if (distanciaUltima > 0.5) {
        parcialINmilisseconds = (500 * diferencaTempo) / distanciaUltima;
        
        if (parcialINmilisseconds < 80000 || parcialINmilisseconds > 600000) {
          parcialINmilisseconds = 0;
        }
      }
    }
    _ultimosalto = agora;
  }

  String _formatParcial(double parcialMs) {
    if (parcialMs <= 0 || parcialMs > 600000) return "--:--";

    int totalSeconds = (parcialMs / 1000).round();
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;

    return "${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    _metrosRestantes = widget.metros;

    _movementAnalyzer.startAnalysis(onStrokeDetected: () {
      setState(() {});
    });

    gps.addListener(() {
      setState(() {
        _metrosRestantes = _metrosRestantes - gps.distanciaUltimaRemada;
        
        if (gps.distanciaUltimaRemada > 0.5) {
          parcial(gps.distanciaUltimaRemada);
        }

        if (_metrosRestantes <= 0) {
          _metrosRestantes = 0;
          gps.pararTracking();
          _stop();
          _showCompletionDialog();
        }
      });
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🏆 Distância Completada!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Distância: ${widget.metros.toStringAsFixed(0)}m'),
              Text('Remadas: ${_movementAnalyzer.totalStrokes}'),
              Text('Taxa média: ${_movementAnalyzer.averageStrokeRate.toStringAsFixed(1)} spm'),
              Text('Tempo: ${_movementAnalyzer.getSessionDurationString()}'),
              if (parcialINmilisseconds > 0)
                Text('Melhor parcial: ${_formatParcial(parcialINmilisseconds)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _reset();
              },
              child: const Text('Novo Treino'),
            ),
          ],
        );
      },
    );
  }

  void _start() async {
    if (_ativo) return;

    try {
      await gps.getPermissao();
      gps.iniciarTracking();

      setState(() {
        _ativo = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    }
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _ativo = false;
    });
  }

  void _reset() {
    _stop();
    gps.pararTracking();
    setState(() {
      _metrosRestantes = widget.metros;
      parcialINmilisseconds = 0;
      _ultimosalto = null;
      _movementAnalyzer.reset();
    });
  }

  @override
  void dispose() {
    _stop();
    _movementAnalyzer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Treino por Distância"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // LAYOUT PRINCIPAL COM 3 SEÇÕES
            Column(
              children: [
                // Primeira linha: Tempo decorrido | VOGA
                SizedBox(
                  height: 60,
                  child: Row(
                    children: [
                      // Tempo decorrido
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            border: Border.all(color: Colors.grey.shade400, width: 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Tempo decorrido",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _movementAnalyzer.getSessionDurationString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // VOGA
                      Expanded(
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.grey.shade400, width: 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "VOGA",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${_movementAnalyzer.strokesPerMinute.toStringAsFixed(1)} spm",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Segunda linha: Metros restantes
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.grey.shade400, width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Metros restantes",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${_metrosRestantes.toStringAsFixed(0)} m",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                // Terceira linha: Parcial
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    border: Border.all(color: Colors.grey.shade400, width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Parcial",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${_formatParcial(parcialINmilisseconds)} /500m",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),

            // Informação adicional compacta
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      "${gps.distanciaTotal.toStringAsFixed(0)} m",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text("Percorridos", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      "${_movementAnalyzer.totalStrokes}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text("Remadas", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      "${_movementAnalyzer.averageStrokeRate.toStringAsFixed(1)}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text("Taxa Média", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Botões de controle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton.icon(
                      onPressed: _ativo ? null : _start,
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text("Start"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton.icon(
                      onPressed: _ativo ? _stop : null,
                      icon: const Icon(Icons.pause, size: 20),
                      label: const Text("Pause"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text("Reset"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Status atual
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _movementAnalyzer.getMovementStatus(),
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.w500,
                        color: _getStatusColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Dados técnicos (expansível e compacto)
            Card(
              child: ExpansionTile(
                title: const Text("Dados Técnicos", style: TextStyle(fontSize: 16)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Balanço: ${_movementAnalyzer.magnitude.toStringAsFixed(1)} m/s²"),
                            Text("GPS: ${gps.getQualidadeGPS().split(' ')[0]}"),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (gps.velocidadeAtual > 0)
                          Text("Velocidade: ${gps.getVelocidadeKmh().toStringAsFixed(1)} km/h"),
                        const SizedBox(height: 8),
                        Text(
                          "X: ${_movementAnalyzer.x.toStringAsFixed(1)} | "
                          "Y: ${_movementAnalyzer.y.toStringAsFixed(1)} | "
                          "Z: ${_movementAnalyzer.z.toStringAsFixed(1)}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (_movementAnalyzer.errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _movementAnalyzer.errorMessage,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Espaço extra para scroll
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    final status = _movementAnalyzer.getMovementStatus();
    if (status.contains("Remando")) return Icons.rowing;
    if (status.contains("movimento")) return Icons.directions_boat;
    if (status.contains("Pronto")) return Icons.check_circle;
    return Icons.error;
  }

  Color _getStatusColor() {
    final status = _movementAnalyzer.getMovementStatus();
    if (status.contains("Remando")) return Colors.green;
    if (status.contains("movimento")) return Colors.orange;
    if (status.contains("Pronto")) return Colors.blue;
    return Colors.red;
  }
}