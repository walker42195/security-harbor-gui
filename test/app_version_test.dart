import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:security_harbor_gui/app_version.dart';

// kGuiVersion var tidigare handunderhållen och skulle "hållas i synk med
// pubspec.yaml". Den invarianten höll inte: konstanten bumpades senast för
// 2.2.0 och följde aldrig med till 2.3.0/2.3.1, som bara ändrade pubspec.
// Desktop-appen rapporterade därför 2.2.0 hur många gånger den än
// uppdaterades — självuppdateringen installerade rätt bunt, men
// versionspanelen erbjöd samma uppdatering i all oändlighet (2026-08-26).
//
// Filen genereras numera av sync_app_version.sh vid varje release. Det här
// testet fångar drift även om någon bygger utanför byggskriptet.
void main() {
  test('kGuiVersion matchar pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'hittade ingen version: i pubspec.yaml');

    expect(
      kGuiVersion,
      match!.group(1),
      reason: 'lib/app_version.dart är ur synk med pubspec.yaml — '
          'kör ./sync_app_version.sh',
    );
  });
}
