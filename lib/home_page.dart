import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'segunda_pagina.dart';
import 'pagina_metros.dart';
import 'just_row.dart';
import 'expGPS.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final gps = GPSController();

  @override
  void initState() {
    super.initState();
    _pedirPermissao();
  }

  Future<void> _pedirPermissao() async {
    try {
      final posicao = await gps.getPermissao();
      print("Lat: ${posicao.latitude}, Long: ${posicao.longitude}");
    } catch (e) {
      print("Erro: $e");
    }
  }

  final _formKey = GlobalKey<FormState>();
  Duration? _tempo;
  double? _metros;
  Duration? _intervalo;

  // Controladores para poder limpar os campos
  final _metrosController = TextEditingController();
  final _tempoController = GlobalKey<_DurationFormFieldState>();
  final _intervaloController = GlobalKey<_DurationFormFieldState>();

  void _limparCampos() {
    setState(() {
      _tempo = null;
      _metros = null;
      _intervalo = null;
    });
    _metrosController.clear();
    _tempoController.currentState?.clear();
    _intervaloController.currentState?.clear();
  }

  @override
  void dispose() {
    _metrosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Tempo
              DurationFormField(
                key: _tempoController,
                label: 'Tempo',
                onSaved: (d) => _tempo = d,
              ),
              const SizedBox(height: 20),

              // Metros
              TextFormField(
                controller: _metrosController,
                decoration: const InputDecoration(
                  labelText: 'Distância (m)',
                  helperText: 'Deixar vazio se usar modo tempo',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSaved: (String? value) {
                  if (value != null && value.isNotEmpty) {
                    _metros = double.tryParse(value);
                  } else {
                    _metros = null; // Importante: definir como null se vazio
                  }
                },
                validator: (String? value) {
                  if (value != null && value.isNotEmpty) {
                    final metros = double.tryParse(value);
                    if (metros == null || metros <= 0) {
                      return 'Valor inválido';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Intervalo
              DurationFormField(
                key: _intervaloController,
                label: 'Intervalo (opcional)',
                onSaved: (d) => _intervalo = d,
              ),
              const SizedBox(height: 20),

              // Botão para limpar campos
              OutlinedButton.icon(
                onPressed: _limparCampos,
                icon: const Icon(Icons.clear_all),
                label: const Text('Limpar Campos'),
              ),
              const SizedBox(height: 10),

              FilledButton(
                onPressed: () {
                  final ok = _formKey.currentState!.validate();
                  if (!ok) return;

                  _formKey.currentState!.save();

                  final temTempo = _tempo != null && _tempo!.inSeconds > 0;
                  final temMetros = _metros != null && _metros! > 0;

                  print("Debug - Tempo: $_tempo, Metros: $_metros");
                  print("Debug - temTempo: $temTempo, temMetros: $temMetros");

                  if (!temTempo && !temMetros) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Indica tempo OU distância')),
                    );
                    return;
                  }
                  if (temTempo && temMetros) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Escolhe só uma opção: tempo OU distância')),
                    );
                    return;
                  }

                  if (temTempo) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SegundaPagina(
                          tempo: _tempo!,
                          intervalo: _intervalo ?? Duration.zero,
                        ),
                      ),
                    );
                  } else if (temMetros) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaginaMetros(
                          metros: _metros!,
                          intervalo: _intervalo ?? Duration.zero,
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Start')
              ),

              const SizedBox(height: 10),

              FilledButton(
                onPressed: (){
                  Navigator.push(context,
                  MaterialPageRoute(builder:(context) => JustRow())
                  );
                },
                child: const Text('Just Row'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo composto (Min + Seg) que valida e devolve um Duration
class DurationFormField extends StatefulWidget {
  final String label;
  final AutovalidateMode autovalidateMode;
  final void Function(Duration?)? onSaved;
  final void Function(Duration?)? onChanged;

  const DurationFormField({
    super.key,
    required this.label,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.onSaved,
    this.onChanged,
  });

  @override
  State<DurationFormField> createState() => _DurationFormFieldState();
}

class _DurationFormFieldState extends State<DurationFormField> {
  final _minCtrl = TextEditingController();
  final _secCtrl = TextEditingController();

  // Método para limpar os campos
  void clear() {
    _minCtrl.clear();
    _secCtrl.clear();
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _secCtrl.dispose();
    super.dispose();
  }

  Duration _parse() {
    final m = int.tryParse(_minCtrl.text) ?? 0;
    final s = int.tryParse(_secCtrl.text) ?? 0;
    return Duration(minutes: m, seconds: s);
  }
  
  String? _validate({bool required = true}) {
    // Se não for obrigatório e o campo está vazio, retorna null
    if (!required && _minCtrl.text.isEmpty && _secCtrl.text.isEmpty) {
      return null;
    }

    if ((_minCtrl.text.isEmpty) && (_secCtrl.text.isEmpty)) {
      return null; // Permitir campos vazios
    }
    final sec = int.tryParse(_secCtrl.text.isEmpty ? '0' : _secCtrl.text);
    if (sec == null) return 'Segundos inválidos';
    if (sec < 0 || sec > 59) return 'Segundos de 0 a 59';

    final min = int.tryParse(_minCtrl.text.isEmpty ? '0' : _minCtrl.text);
    if (min == null || min < 0) return 'Minutos inválidos';

    return null;
  }
  
  @override
  Widget build(BuildContext context) {
    return FormField<Duration>(
      autovalidateMode: widget.autovalidateMode,
      validator: (_) => _validate(required: false),
      onSaved: (_) {
        final duration = _parse();
        // Só salvar se tiver valor maior que 0
        widget.onSaved?.call(duration.inSeconds > 0 ? duration : null);
      },
      builder: (state) {
        void handleChange(String _) {
          final dur = _parse();
          state.didChange(dur);
          widget.onChanged?.call(dur.inSeconds > 0 ? dur : null);
          setState(() {});
        }

        final error = state.errorText;

        InputDecoration deco(String label) => InputDecoration(
              labelText: label,
              counterText: '',
              errorText: null,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: TextField(
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    maxLength: 3,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: deco('Min'),
                    onChanged: handleChange,
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: TextField(
                    controller: _secCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 2,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: deco('Seg'),
                    onChanged: handleChange,
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 4),
              Text(
                error,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}