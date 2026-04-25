import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'segunda_pagina.dart';
import 'pagina_metros.dart';
import 'just_row.dart';
import 'movementeanalizer.dart';
import 'package:provider/provider.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // As 3 abas: Just Row, Tempo, Distância
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.rowing), text: "Just Row"),
              Tab(icon: Icon(Icons.timer), text: "Tempo"),
              Tab(icon: Icon(Icons.straighten), text: "Distância"),
              Tab(icon: Icon(Icons.tune), text: "Defenições"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            JustRowMenu(),
            IntervaloTempoMenu(),
            IntervaloDistanciaMenu(),
            CalibracaoMenu(),
          ],
        ),
      ),
    );
  }
}

//menu de calibração
class CalibracaoMenu extends StatelessWidget {
  const CalibracaoMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final analyzer = context.watch<ImprovedMovementAnalyzer>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Text("CALIBRAÇÃO DE SENSIBILIDADE", 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 30),
          
          // MOSTRADOR EM TEMPO REAL
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: analyzer.magnitude > analyzer.driveThreshold ? Colors.green : Colors.grey),
            ),
            child: Column(
              children: [
                const Text("Aceleração Atual:"),
                Text(analyzer.magnitude.toStringAsFixed(2), 
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          Text("Limiar de Remada (Threshold): ${analyzer.driveThreshold.toStringAsFixed(2)}"),
          
          // O SLIDER PARA AJUSTAR
          Slider(
            value: analyzer.driveThreshold,
            min: 0.1,
            max: 1.5,
            divisions: 14,
            label: analyzer.driveThreshold.toStringAsFixed(2),
            onChanged: (double value) {
              analyzer.updateThreshold(value);
            },
          ),
          
          const SizedBox(height: 20),
          const Text(
            "Dica: Se a app contar remadas a mais (falsos positivos), aumenta o valor. Se não detetar as tuas remadas, diminui o valor.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// --- ABA 1: JUST ROW ---
class JustRowMenu extends StatelessWidget {
  const JustRowMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_outline, size: 100, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            "MODO LIVRE",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("Rema sem limites de tempo ou distância.", textAlign: TextAlign.center),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const JustRow()));
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text("START JUST ROW", style: TextStyle(fontSize: 18)),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
          ),
        ],
      ),
    );
  }
}

// --- ABA 2: INTERVALOS TEMPO (CORRIGIDA COM SCROLL) ---
class IntervaloTempoMenu extends StatefulWidget {
  const IntervaloTempoMenu({super.key});

  @override
  State<IntervaloTempoMenu> createState() => _IntervaloTempoMenuState();
}

class _IntervaloTempoMenuState extends State<IntervaloTempoMenu> {
  Duration _tempoSerie = Duration.zero;
  Duration _tempoIntervalo = Duration.zero;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text("CONFIGURAR INTERVALOS DE TEMPO", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            DurationFormField(
              label: "Tempo de Série (Trabalho)",
              onChanged: (d) => _tempoSerie = d ?? Duration.zero,
            ),
            const SizedBox(height: 20),
            DurationFormField(
              label: "Tempo de Descanso (Intervalo)",
              onChanged: (d) => _tempoIntervalo = d ?? Duration.zero,
            ),
            // 2. Trocámos o Spacer() por um SizedBox fixo, porque dentro de um scroll
            // o Spacer() não funciona (o scroll não tem altura definida).
            const SizedBox(height: 40), 
            FilledButton(
              onPressed: () {
                if (_tempoSerie.inSeconds > 0) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => SegundaPagina(
                    tempo: _tempoSerie,
                    intervalo: _tempoIntervalo,
                  )));
                }
              },
              child: const Text("COMEÇAR SÉRIES DE TEMPO"),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// --- ABA 3: INTERVALOS DISTÂNCIA (CORRIGIDA COM SCROLL) ---
class IntervaloDistanciaMenu extends StatefulWidget {
  const IntervaloDistanciaMenu({super.key});

  @override
  State<IntervaloDistanciaMenu> createState() => _IntervaloDistanciaMenuState();
}

class _IntervaloDistanciaMenuState extends State<IntervaloDistanciaMenu> {
  final _distanciaController = TextEditingController();
  Duration _tempoIntervalo = Duration.zero;

  @override
  Widget build(BuildContext context) {
    // 1. SingleChildScrollView adicionado aqui também.
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text("CONFIGURAR INTERVALOS DE DISTÂNCIA", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            TextField(
              controller: _distanciaController,
              decoration: const InputDecoration(labelText: "Distância do Puxão (metros)", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 20),
            DurationFormField(
              label: "Tempo de Descanso (Intervalo)",
              onChanged: (d) => _tempoIntervalo = d ?? Duration.zero,
            ),
            // 2. Trocámos o Spacer() por um SizedBox fixo.
            const SizedBox(height: 40), 
            FilledButton(
              onPressed: () {
                double? m = double.tryParse(_distanciaController.text);
                if (m != null && m > 0) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => PaginaMetros(
                    metros: m,
                    intervalo: _tempoIntervalo,
                  )));
                }
              },
              child: const Text("COMEÇAR SÉRIES DE METROS"),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET AUXILIAR: DurationFormField ---
class DurationFormField extends StatefulWidget {
  final String label;
  final Function(Duration?) onChanged;

  const DurationFormField({super.key, required this.label, required this.onChanged});

  @override
  State<DurationFormField> createState() => _DurationFormFieldState();
}

class _DurationFormFieldState extends State<DurationFormField> {
  final _min = TextEditingController();
  final _sec = TextEditingController();

  void _update() {
    final m = int.tryParse(_min.text) ?? 0;
    final s = int.tryParse(_sec.text) ?? 0;
    widget.onChanged(Duration(minutes: m, seconds: s));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: TextField(
              controller: _min, 
              decoration: const InputDecoration(labelText: "Min", border: OutlineInputBorder()), 
              keyboardType: TextInputType.number, 
              onChanged: (_) => _update()
            )),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _sec, 
              decoration: const InputDecoration(labelText: "Seg", border: OutlineInputBorder()), 
              keyboardType: TextInputType.number, 
              onChanged: (_) => _update()
            )),
          ],
        ),
      ],
    );
  }
}