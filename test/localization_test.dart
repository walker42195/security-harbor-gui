import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Vaktar SV/EN-språksystemet mot de två sätt det gick sönder på.
///
/// 1. En nyckel som bara finns i en av kartorna. `tr()` faller tillbaka på
///    den engelska kartan och till slut på nyckeln själv, så en saknad
///    EN-nyckel visar SVENSK text i det engelska gränssnittet utan att något
///    kraschar (så gjorde 'objects.inga_traffar' fram till 2026-08-31).
/// 2. Text som aldrig gick genom `tr()`. Taktiska HUD:en var byggd av
///    hårdkodade engelska strängar med svenska rader inblandade — samma vy
///    kunde visa "SCANNING SECTORS..." bredvid "AVSTÄNGD", oavsett vilket
///    språk användaren valt.
void main() {
  final source = File('lib/localization.dart').readAsStringSync();

  /// Nycklarna i en av språkkartorna, i filordning.
  List<String> keysOf(String mapName) {
    final start = source.indexOf('_$mapName = {');
    expect(start, isNot(-1), reason: 'hittar inte kartan _$mapName');
    final end = source.indexOf('\n};', start);
    final body = source.substring(start, end);
    return RegExp(r"^\s*'([^']+)':", multiLine: true)
        .allMatches(body)
        .map((m) => m.group(1)!)
        .toList();
  }

  test('SV och EN har exakt samma nycklar', () {
    final sv = keysOf('sv');
    final en = keysOf('en');

    expect(sv.toSet().difference(en.toSet()), isEmpty,
        reason: 'nycklar som saknas i EN visar svensk text i engelskt UI');
    expect(en.toSet().difference(sv.toSet()), isEmpty,
        reason: 'nycklar som saknas i SV visar engelsk text i svenskt UI');
  });

  test('inga dubblettnycklar i språkkartorna', () {
    for (final map in ['sv', 'en']) {
      final keys = keysOf(map);
      final seen = <String>{};
      final dupes = keys.where((k) => !seen.add(k)).toList();
      expect(dupes, isEmpty, reason: 'dubbletter i _$map (sista vinner tyst)');
    }
  });

  test('taktiska HUD:en har ingen text utanför tr()', () {
    final hud = File('lib/screens/tactical_hud_screen.dart').readAsLinesSync();

    // Text för användaren är i praktiken alltid minst två ord. Tekniska
    // literaler ('deny', 'monospace', ' GB') är ett ord och fälls inte.
    final twoWords = RegExp(r"'[^']*[A-Za-zÅÄÖåäö]{2,}\s+[A-Za-zÅÄÖåäö]{2,}[^']*'");

    final offenders = <String>[];
    for (var i = 0; i < hud.length; i++) {
      final line = hud[i];
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
      // Raden slår upp en nyckel — literalen ÄR nyckeln.
      if (trimmed.contains("tr('") || trimmed.contains("trp('")) continue;
      // SI-enheter skrivs likadant på båda språken och ska INTE översättas;
      // "1,2 Mbit/s" heter så i både svenskt och engelskt UI.
      if (line.contains('bit/s')) continue;
      if (twoWords.hasMatch(line)) {
        offenders.add('tactical_hud_screen.dart:${i + 1}\n    ${line.trim()}');
      }
    }

    expect(offenders, isEmpty,
        reason: 'hårdkodad text i HUD:en — lägg den i localization.dart '
            'och slå upp med tr()/trp():\n${offenders.join("\n")}');
  });
}
