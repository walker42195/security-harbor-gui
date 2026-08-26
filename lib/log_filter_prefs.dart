/// Sparade filterinställningar för loggningsvyn.
///
/// Filtren nollställdes varje gång man lämnade sidan. Ett uttryck som
/// `accept and not port 53 and not port 123` är omständligt att skriva, och
/// man skriver det just för att kunna gå fram och tillbaka mellan loggen och
/// reglerna medan man felsöker — precis det arbetssättet som tvingade fram en
/// omskrivning varje gång.
///
/// Tidsfönstret sparas också: hämtningen styrs av det, och den som ställt in
/// "24 timmar" för att titta på något som hände i går vill inte hitta "15 min"
/// nästa gång.
///
/// Pausläget sparas däremot INTE. Att pausa är en tillfällig åtgärd — en vy
/// som öppnas fryst utan att man bett om det ser ut som att loggningen slutat
/// fungera.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Alla filterval i loggningsvyn, i en form som går att spara och läsa.
class LogFilterPrefs {
  const LogFilterPrefs({
    this.expression = '',
    this.ip = '',
    this.mac = '',
    this.name = '',
    this.directionField = 'ANY',
    this.trafficDirection = 'ALL',
    this.action = 'ALL',
    this.ipVersion = 'IPV4',
    this.window = '15m',
    this.hideDefaultDeny = false,
  });

  final String expression;
  final String ip;
  final String mac;
  final String name;
  final String directionField;
  final String trafficDirection;
  final String action;
  final String ipVersion;
  final String window;
  final bool hideDefaultDeny;

  /// Standardläget — samma värden som vyn hade innan något sparats, och det
  /// "Rensa filter" återställer till.
  static const defaults = LogFilterPrefs();

  /// Tillåtna värden per fält. Ett sparat värde som inte finns med förkastas
  /// och ersätts av standardvärdet.
  ///
  /// Det är inte teoretiskt: dropdown-widgetarna kastar undantag om `value`
  /// inte finns bland `items`, så ett kvarglömt värde från en äldre version
  /// (eller manipulerad lagring) skulle göra hela sidan omöjlig att öppna —
  /// och den enda vägen ur det vore att rensa appens lagring.
  static const allowed = <String, List<String>>{
    'directionField': ['ANY', 'FROM', 'TO'],
    'trafficDirection': ['ALL', 'IN', 'OUT', 'INTERNAL'],
    'action': ['ALL', 'ACCEPT', 'DENY'],
    'ipVersion': ['ALL', 'IPV4', 'IPV6'],
    'window': ['5m', '15m', '1h', '6h', '24h', '7d'],
  };

  /// Längdtak på fritextfälten. Ett uttryck är i praktiken en rad text; att
  /// spara godtyckligt mycket i SharedPreferences vore onödigt.
  static const maxTextLength = 512;

  Map<String, Object> toMap() => {
        'expression': expression,
        'ip': ip,
        'mac': mac,
        'name': name,
        'directionField': directionField,
        'trafficDirection': trafficDirection,
        'action': action,
        'ipVersion': ipVersion,
        'window': window,
        'hideDefaultDeny': hideDefaultDeny,
      };

  /// Läser en sparad karta. Varje fält valideras för sig: ett trasigt fält
  /// faller tillbaka på sitt standardvärde i stället för att förkasta hela
  /// den sparade uppsättningen.
  static LogFilterPrefs fromMap(Map<String, Object?> map) {
    String text(String key) {
      final v = map[key];
      if (v is! String) return '';
      return v.length > maxTextLength ? v.substring(0, maxTextLength) : v;
    }

    String choice(String key, String fallback) {
      final v = map[key];
      return v is String && (allowed[key] ?? const []).contains(v) ? v : fallback;
    }

    return LogFilterPrefs(
      expression: text('expression'),
      ip: text('ip'),
      mac: text('mac'),
      name: text('name'),
      directionField: choice('directionField', defaults.directionField),
      trafficDirection: choice('trafficDirection', defaults.trafficDirection),
      action: choice('action', defaults.action),
      ipVersion: choice('ipVersion', defaults.ipVersion),
      window: choice('window', defaults.window),
      hideDefaultDeny: map['hideDefaultDeny'] == true,
    );
  }

  /// True när ingenting avviker från standard. Används för att slippa skriva
  /// till lagringen när man just rensat filtret.
  bool get isDefault {
    final a = toMap(), b = defaults.toMap();
    return a.keys.every((k) => a[k] == b[k]);
  }

  static const _prefsKey = 'log_filter_prefs_v1';

  /// Läser sparade filter. Fel (ingen lagring tillgänglig, trasig data) ger
  /// standardläget — loggvyn ska alltid gå att öppna.
  static Future<LogFilterPrefs> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefsKey);
      if (raw == null) return defaults;
      return fromMap(_decode(raw));
    } catch (_) {
      return defaults;
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isDefault) {
        await prefs.remove(_prefsKey);
        return;
      }
      await prefs.setStringList(_prefsKey, _encode(toMap()));
    } catch (_) {
      // Filtret gäller ändå för den här sessionen.
    }
  }

  /// Lagras som en lista av "nyckel=värde" i stället för JSON. Anledningen är
  /// att ett filteruttryck fritt får innehålla citattecken och snedstreck;
  /// med en lista slipper värdena escapas alls, eftersom varje post är sitt
  /// eget element. Endast det FÖRSTA likhetstecknet delar posten.
  static List<String> _encode(Map<String, Object> map) =>
      map.entries.map((e) => '${e.key}=${e.value}').toList();

  static Map<String, Object?> _decode(List<String> raw) {
    final out = <String, Object?>{};
    for (final line in raw) {
      final i = line.indexOf('=');
      if (i <= 0) continue;
      final key = line.substring(0, i);
      final value = line.substring(i + 1);
      out[key] = key == 'hideDefaultDeny' ? value == 'true' : value;
    }
    return out;
  }
}
