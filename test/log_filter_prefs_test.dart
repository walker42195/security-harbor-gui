import 'package:flutter_test/flutter_test.dart';
import 'package:security_harbor_gui/log_filter_prefs.dart';

void main() {
  group('serialisering', () {
    test('tur och retur bevarar alla fält', () {
      const prefs = LogFilterPrefs(
        expression: 'deny and not port 53',
        ip: '10.9.9.100',
        mac: '94:45:60:57:27:ab',
        name: 'DefaultDeny',
        directionField: 'FROM',
        trafficDirection: 'OUT',
        action: 'DENY',
        ipVersion: 'ALL',
        window: '24h',
        hideDefaultDeny: true,
      );
      final back = LogFilterPrefs.fromMap(prefs.toMap());
      expect(back.toMap(), prefs.toMap());
    });

    // Ett filteruttryck innehåller ofta likhetstecken, citattecken och
    // snedstreck. Delas posten på FEL likhetstecken kapas uttrycket.
    test('uttryck med likhetstecken och citattecken överlever', () {
      const expr = 'name="LAN => WAN" and not net 10.0.0.0/24';
      final back = LogFilterPrefs.fromMap(
        const LogFilterPrefs(expression: expr).toMap(),
      );
      expect(back.expression, expr);
    });

    test('tomt uttryck ger tomt uttryck, inte null', () {
      expect(LogFilterPrefs.fromMap(const {}).expression, '');
    });
  });

  group('validering av sparade värden', () {
    // Dropdown kastar undantag om värdet inte finns bland alternativen. Ett
    // kvarglömt värde från en äldre version får inte kunna låsa hela sidan.
    test('okänt dropdown-värde faller tillbaka på standard', () {
      final back = LogFilterPrefs.fromMap({
        'window': 'för alltid',
        'action': 'KANSKE',
        'ipVersion': 'IPV9',
        'trafficDirection': 'SIDLEDES',
        'directionField': 'BAKÅT',
      });
      expect(back.window, LogFilterPrefs.defaults.window);
      expect(back.action, LogFilterPrefs.defaults.action);
      expect(back.ipVersion, LogFilterPrefs.defaults.ipVersion);
      expect(back.trafficDirection, LogFilterPrefs.defaults.trafficDirection);
      expect(back.directionField, LogFilterPrefs.defaults.directionField);
    });

    test('varje tillåtet värde accepteras', () {
      for (final entry in LogFilterPrefs.allowed.entries) {
        for (final value in entry.value) {
          final back = LogFilterPrefs.fromMap({entry.key: value});
          expect(back.toMap()[entry.key], value,
              reason: '${entry.key}=$value förkastades');
        }
      }
    });

    test('fel typ i lagringen ger standard, inte krasch', () {
      final back = LogFilterPrefs.fromMap({
        'expression': 42,
        'hideDefaultDeny': 'nej',
        'window': 7,
      });
      expect(back.expression, '');
      expect(back.hideDefaultDeny, isFalse);
      expect(back.window, LogFilterPrefs.defaults.window);
    });

    test('orimligt långt uttryck kapas', () {
      final long = 'a' * (LogFilterPrefs.maxTextLength + 100);
      expect(LogFilterPrefs.fromMap({'expression': long}).expression.length,
          LogFilterPrefs.maxTextLength);
    });
  });

  group('isDefault', () {
    test('standardläget är standard', () {
      expect(LogFilterPrefs.defaults.isDefault, isTrue);
    });

    // Varje enskilt fält måste räknas — annars sparas inte en ändring som
    // bara rör det fältet, eller så rensas inte lagringen när man nollar det.
    test('en ändring i vilket fält som helst bryter standardläget', () {
      final changed = <LogFilterPrefs>[
        const LogFilterPrefs(expression: 'x'),
        const LogFilterPrefs(ip: '10.0.0.1'),
        const LogFilterPrefs(mac: 'aa:bb'),
        const LogFilterPrefs(name: 'r'),
        const LogFilterPrefs(directionField: 'TO'),
        const LogFilterPrefs(trafficDirection: 'IN'),
        const LogFilterPrefs(action: 'DENY'),
        const LogFilterPrefs(ipVersion: 'ALL'),
        const LogFilterPrefs(window: '7d'),
        const LogFilterPrefs(hideDefaultDeny: true),
      ];
      expect(changed.length, LogFilterPrefs.defaults.toMap().length,
          reason: 'ett fält saknar täckning i testet');
      for (final p in changed) {
        expect(p.isDefault, isFalse, reason: '${p.toMap()} lästes som standard');
      }
    });
  });

  // Vyn öppnas fritt, aldrig fryst: en logg som står stilla utan att man bett
  // om det ser ut som att loggningen slutat fungera.
  test('pausläget sparas inte', () {
    expect(LogFilterPrefs.defaults.toMap().containsKey('paused'), isFalse);
  });
}
