import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kategorierna som backend (pkg/traffic/classify.go, AllCategories) kan
/// returnera. Läggs en kategori till där måste den få både etikett och
/// hjälptext på BÅDA språken, annars visar GUI:t engelska eller den råa
/// nyckeln.
const _categories = [
  'streaming', 'social', 'messaging', 'gaming', 'work',
  'cloud', 'updates', 'smarthome', 'ads', 'web', 'other',
];

/// Läser källfilen och delar den i de två språkkartorna.
///
/// tr() faller tillbaka på engelska när en svensk nyckel saknas, vilket är
/// rätt i drift men gör att ett vanligt anrop aldrig kan avslöja en tappad
/// översättning. Därför granskas kartorna var för sig — samma grepp som
/// no_hardcoded_colors_test använder.
(String sv, String en) _languageBlocks() {
  final src = File('lib/localization.dart').readAsStringSync();
  final svStart = src.indexOf('const Map<String, String> _sv = {');
  final enStart = src.indexOf('const Map<String, String> _en = {');
  expect(svStart, greaterThan(-1), reason: 'hittade inte _sv-kartan');
  expect(enStart, greaterThan(svStart), reason: 'hittade inte _en-kartan efter _sv');
  return (src.substring(svStart, enStart), src.substring(enStart));
}

void main() {
  group('kategoritexter', () {
    late String sv;
    late String en;

    setUpAll(() {
      final blocks = _languageBlocks();
      sv = blocks.$1;
      en = blocks.$2;
    });

    test('varje kategori har etikett på båda språken', () {
      for (final c in _categories) {
        expect(sv, contains("'traftype.cat_$c':"), reason: 'svensk etikett saknas för $c');
        expect(en, contains("'traftype.cat_$c':"), reason: 'engelsk etikett saknas för $c');
      }
    });

    test('varje kategori har hjälptext på båda språken', () {
      for (final c in _categories) {
        expect(sv, contains("'traftype.help_$c':"), reason: 'svensk hjälptext saknas för $c');
        expect(en, contains("'traftype.help_$c':"), reason: 'engelsk hjälptext saknas för $c');
      }
    });

    test('hjälprutans inledning och avslutning finns på båda språken', () {
      for (final k in ['traftype.hjalp_titel', 'traftype.hjalp_metod', 'traftype.hjalp_okand']) {
        expect(sv, contains("'$k':"), reason: '$k saknas på svenska');
        expect(en, contains("'$k':"), reason: '$k saknas på engelska');
      }
    });
  });
}
