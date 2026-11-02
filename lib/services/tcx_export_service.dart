import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../exp_gps.dart';

class TcxExportService {
  static Future<String?> exportarTreinoTCX({
    required List<Pontodetreino> sessaoAtual,
    required double distanciaTotal,
  }) async {
    debugPrint("🚣 EXPORT SERVICE: sessaoAtual tem ${sessaoAtual.length} pontos");

    if (sessaoAtual.isEmpty) {
      return "Sem dados GPS para exportar. Verifica se o GPS teve sinal durante o treino.";
    }

    try {
      final buffer = StringBuffer();
      buffer.write('''<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
  <Activities>
    <Activity Sport="Rowing">
      <Id>${sessaoAtual.first.tempo.toUtc().toIso8601String()}</Id>
      <Lap StartTime="${sessaoAtual.first.tempo.toUtc().toIso8601String()}">
        <TotalTimeSeconds>${sessaoAtual.last.tempo.difference(sessaoAtual.first.tempo).inSeconds}</TotalTimeSeconds>
        <DistanceMeters>${distanciaTotal.toStringAsFixed(1)}</DistanceMeters>
        <Intensity>Active</Intensity>
        <TriggerMethod>Manual</TriggerMethod>
        <Track>''');

      for (var ponto in sessaoAtual) {
        buffer.write('''
          <Trackpoint>
            <Time>${ponto.tempo.toUtc().toIso8601String()}</Time>
            <Position>
              <LatitudeDegrees>${ponto.lat}</LatitudeDegrees>
              <LongitudeDegrees>${ponto.long}</LongitudeDegrees>
            </Position>''');
        if (ponto.frequenciaCardiaca > 0) {
          buffer.write('''
            <HeartRateBpm>
              <Value>${ponto.frequenciaCardiaca}</Value>
            </HeartRateBpm>''');
        }
        buffer.write('''
            <Cadence>${ponto.cadencia}</Cadence>
            <Extensions>
              <TPX xmlns="http://www.garmin.com/xmlschemas/ActivityExtension/v2">
                <Speed>${ponto.velocidade}</Speed>
              </TPX>
            </Extensions>
          </Trackpoint>''');
      }

      buffer.write('''
        </Track>
      </Lap>
    </Activity>
  </Activities>
</TrainingCenterDatabase>''');

      final directory = await getTemporaryDirectory();
      final dataStr = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '')
          .split('.')
          .first;
      final file = File('${directory.path}/Treino_Rowing_$dataStr.tcx');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/vnd.garmin.tcx+xml')],
        text: 'O meu treino de Remo!',
        subject: 'Treino de Remo',
      );
      
      return null; // Sucesso
    } catch (e) {
      return "Erro ao exportar: $e";
    }
  }
}
