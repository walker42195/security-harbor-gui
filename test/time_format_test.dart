import 'package:flutter_test/flutter_test.dart';
import 'package:security_harbor_gui/time_format.dart';

void main() {
  test('UTC-stämpel omvandlas till lokal tid', () {
    // Det var precis det här som visade fel tid under "Tidigare versioner":
    // index.json skrivs med `date -u`, och GUI:t skrev ut den råa Z-strängen.
    final utc = DateTime.utc(2026, 8, 26, 6, 57, 29);
    final expectedLocal = utc.toLocal();
    final formatted = formatServerTime('2026-08-26T06:57:29Z');

    expect(formatted, startsWith('${expectedLocal.year}-'));
    expect(formatted, contains(expectedLocal.hour.toString().padLeft(2, '0')));
    expect(formatted, equals(
      '${expectedLocal.year.toString().padLeft(4, '0')}-'
      '${expectedLocal.month.toString().padLeft(2, '0')}-'
      '${expectedLocal.day.toString().padLeft(2, '0')} '
      '${expectedLocal.hour.toString().padLeft(2, '0')}:'
      '${expectedLocal.minute.toString().padLeft(2, '0')}:'
      '${expectedLocal.second.toString().padLeft(2, '0')}',
    ));
  });

  test('journalds short-iso med kompakt offset går att tolka', () {
    // DateTime.parse klarar INTE "+0200" utan kolon — utan normaliseringen
    // hade varje loggrad fallit tillbaka på råtext.
    final parsed = parseServerTime('2026-08-26T08:57:29+0200');
    expect(parsed, isNotNull);
    expect(parsed!.toUtc(), DateTime.utc(2026, 8, 26, 6, 57, 29));
  });

  test('offset med kolon fungerar också', () {
    final parsed = parseServerTime('2026-08-26T08:57:29+02:00');
    expect(parsed!.toUtc(), DateTime.utc(2026, 8, 26, 6, 57, 29));
  });

  test('två stämplar för samma ögonblick visas identiskt', () {
    // Kärnan i felet: UTC och lokal-med-offset är SAMMA tid, och ska därför
    // se likadana ut i GUI:t.
    expect(formatServerTime('2026-08-26T06:57:29Z'),
        formatServerTime('2026-08-26T08:57:29+0200'));
  });

  test('otolkbar sträng visas oförändrad', () {
    expect(formatServerTime('aldrig'), 'aldrig');
    expect(formatServerTime(''), '');
    expect(formatServerTime(null), '');
  });

  test('sekunder kan utelämnas', () {
    expect(formatServerTime('2026-08-26T06:57:29Z', withSeconds: false).length, 16);
  });
}
