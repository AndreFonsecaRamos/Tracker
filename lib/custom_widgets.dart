import 'package:flutter/material.dart';
import 'dart:ui'; // Obrigatório para o FontFeature.tabularFigures()

/// 1. CARTÃO DE ESTATÍSTICA (Efeito PM5 - Grande e Legível para os ecrãs normais)
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color baseColor;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.baseColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: baseColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: baseColor.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32, 
              fontWeight: FontWeight.bold,
              color: baseColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. BARRA DE BOTÕES DE CONTROLO
class ControlButtons extends StatelessWidget {
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onReset;

  const ControlButtons({
    super.key,
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildButton(Icons.play_arrow, 'Start', Colors.green, onStart),
        _buildButton(Icons.pause, 'Stop', Colors.orange, onStop),
        _buildButton(Icons.refresh, 'Reset', Colors.red, onReset),
      ],
    );
  }

  Widget _buildButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: Text(label, style: const TextStyle(fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// 3. O MODO PM5 (O Monitor Gigante para o modo Horizontal)
class PM5Monitor extends StatelessWidget {
  final String tempo;
  final String spm;
  final String parcial;
  final String distancia;
  final int serieAtual;
  final String averageParcial;

  const PM5Monitor({
    super.key,
    required this.tempo,
    required this.spm,
    required this.parcial,
    required this.distancia,
    this.serieAtual = 1,
    this.averageParcial = "--:--",
  });

  @override
  Widget build(BuildContext context) {
    // Fundo cinza claro com letras pretas é o melhor para ler ao sol
    return Container(
      color: const Color(0xFFE0E0E0),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // ---------------------------------------------------------
          // LINHA SUPERIOR: Tempo e Voga
          // ---------------------------------------------------------
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(child: _buildPM5Block("TIME", tempo, isGiant: false)),
                Container(width: 4, color: Colors.black), // Divisória Vertical
                Expanded(child: _buildPM5Block("S/M", spm, isGiant: false)),
              ],
            ),
          ),
          
          Container(height: 4, color: Colors.black), // Divisória Horizontal
          
          // ---------------------------------------------------------
          // MEIO: Parcial /500m (O mais importante, gigante no meio)
          // ---------------------------------------------------------
          Expanded(
            flex: 3,
            child: _buildPM5Block("/500m", parcial, isGiant: true, forceCenter: true),
          ),
          
          Container(height: 4, color: Colors.black), // Divisória Horizontal
          
          // ---------------------------------------------------------
          // LINHA INFERIOR: Distância e Average Pace
          // ---------------------------------------------------------
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(child: _buildPM5Block("METERS", distancia, isGiant: false)),
                Container(width: 4, color: Colors.black),
                Expanded(child: _buildPM5Block("SÉRIE", serieAtual.toString(), isGiant: false)),
                Container(width: 4, color: Colors.black),
                Expanded(child: _buildPM5Block("AVE /500m", averageParcial, isGiant: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // A "Fábrica" de blocos do PM5
  Widget _buildPM5Block(String label, String value, {bool isGiant = false, bool forceCenter = false}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // O Rótulo fica à esquerda
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          
          // O Valor estica-se
          Expanded(
            child: Container(
              width: double.infinity, 
              alignment: Alignment.center, 
              child: FittedBox(
                fit: BoxFit.scaleDown, 
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isGiant ? 90 : 60, 
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}