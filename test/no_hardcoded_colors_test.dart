import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Vaktar mot hårdkodade färger utanför lib/theme.dart.
///
/// Det ljusa temat gick sönder TVÅ gånger av exakt samma orsak: en mekanisk
/// omskrivning missade en form av färgangivelse, och felet upptäcktes först
/// när någon såg skärmen. Först var det Materials *Accent-nyanser, sedan
/// `color: Colors.white)` — mitt regex hade ett lookahead som uteslöt just
/// den vanligaste formen, så 47 textfält behöll vit text på vit bakgrund.
///
/// Det här testet gör att nästa sådan miss fälls direkt i stället för att
/// upptäckas i drift.
void main() {
  // Färgnamn som ALDRIG får stå hårdkodade: de är ljusa nyanser gjorda för
  // mörk bakgrund, eller ren vit/svart text.
  const forbiddenNames = [
    'Colors.white', 'Colors.cyanAccent', 'Colors.tealAccent',
    'Colors.greenAccent', 'Colors.amberAccent', 'Colors.amber',
    'Colors.orangeAccent', 'Colors.redAccent', 'Colors.lightBlueAccent',
    'Colors.grey',
  ];

  /// Rader där en hårdkodad färg är RÄTT, med skälet angivet.
  bool isAllowed(String line) {
    // Vit text på en mörk statusfärgad knapp — korrekt i båda temana.
    if (line.contains('foregroundColor: Colors.white')) return true;
    // QR-koden måste ha vit botten för att kunna läsas av.
    if (line.contains('QrImageView') || line.contains('backgroundColor: Colors.white')) {
      return true;
    }
    // Nätmaskaritmetik, inte färger.
    if (line.contains('0xFFFFFFFF')) return true;
    return false;
  }

  test('inga hårdkodade färger utanför theme.dart', () {
    final offenders = <String>[];
    final hexColor = RegExp(r'Color\(0x[0-9A-Fa-f]{8}\)');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('theme.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//') || line.trimLeft().startsWith('///')) {
          continue;
        }
        if (isAllowed(line)) continue;

        final hit = forbiddenNames.where(line.contains).toList();
        if (hexColor.hasMatch(line)) hit.add('Color(0x…)');
        if (hit.isNotEmpty) {
          offenders.add('${entity.path}:${i + 1}  ${hit.join(", ")}\n    ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Hårdkodade färger hittade — använd AppColors i stället, annars '
          'följer de inte temat:\n\n${offenders.join("\n")}',
    );
  });
}
