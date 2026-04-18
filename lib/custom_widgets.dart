import 'package:flutter/material.dart';

/// 1. CARTÃO DE ESTATÍSTICA (Efeito PM5 - Grande e Legível)
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
              fontSize: 32, // Letra bem grande para veres no barco!
              fontWeight: FontWeight.bold,
              color: baseColor,
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

/// --- O MODO PM5 (Apenas para modo Horizontal) ---
class PM5Monitor extends StatelessWidget {
  final String tempo;
  final String spm;
  final String parcial;
  final String distancia;

  const PM5Monitor({
    super.key,
    required this.tempo,
    required this.spm,
    required this.parcial,
    required this.distancia,
  });

  @override
  Widget build(BuildContext context) {
    // Fundo cinza claro com letras pretas é o melhor para ler ao sol
    return Container(
      color: const Color(0xFFE0E0E0), // Cinza tipo ecrã LCD
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // LINHA DE CIMA: Tempo e Voga
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _buildPM5Block("TIME", tempo, isGiant: true),
                Container(width: 4, color: Colors.black), // Divisória
                _buildPM5Block("S/M", spm, isGiant: true),
              ],
            ),
          ),
          Container(height: 4, color: Colors.black), // Divisória horizontal
          
          // MEIO: Parcial /500m (O mais importante, gigante no meio)
          Expanded(
            flex: 3,
            child: _buildPM5Block("/500m", parcial, isGiant: true, forceCenter: true),
          ),
          Container(height: 4, color: Colors.black), // Divisória horizontal
          
          // LINHA DE BAIXO: Distância e um espaço vazio (ou média no futuro)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _buildPM5Block("METERS", distancia, isGiant: false),
                Container(width: 4, color: Colors.black), // Divisória
                // Espaço reservado para Average Pace ou Heart Rate futuro
                _buildPM5Block("AVE /500m", "--:--", isGiant: false), 
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPM5Block(String label, String value, {required bool isGiant, bool forceCenter = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Column(
          crossAxisAlignment: forceCenter ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: Colors.black54,
              ),
            ),
            
            Expanded(
              child: FittedBox(
                fit: BoxFit.contain, // Ajusta a fonte para caber no limite
                alignment: forceCenter ? Alignment.center : Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    color: Colors.black,
                    height: 1.0, 
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}