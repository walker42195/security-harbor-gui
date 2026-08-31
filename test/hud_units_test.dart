import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Taktiska HUD:en ska inte formatera bandbredd själv.
///
/// Agentens `rx_bps`/`tx_bps` är BYTE per sekund trots namnet (se
/// pkg/traffic/collector.go). HUD:en hade en egen `_formatBps` som delade
/// värdet med en miljon och skrev "Mbit/s" på resultatet — den visade alltså
/// MB/s med bit-etikett och underskattade linjen med en faktor 8
/// (rapporterat 2026-08-31). Den delade `formatBps` i
/// widgets/traffic_charts.dart gör rätt; testet vaktar att HUD:en fortsätter
/// använda den i stället för att skaffa en egen kopia igen.
void main() {
  test('HUD:en formaterar inte bandbredd på egen hand', () {
    final src = File('lib/screens/tactical_hud_screen.dart').readAsStringSync();
    final lines = src.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;

      expect(line.contains('Mbit/s') || line.contains('kbit/s') || line.contains('Gbit/s'),
          isFalse,
          reason: 'tactical_hud_screen.dart:${i + 1} formaterar bandbredd själv — '
              'använd formatBps() från widgets/traffic_charts.dart:\n    ${line.trim()}');
    }

    expect(src.contains('formatBps('), isTrue,
        reason: 'HUD:en visar hastigheter men anropar inte den delade formatBps()');
  });
}
