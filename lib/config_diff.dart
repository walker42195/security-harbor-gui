/// Jämför den körande konfigurationen med kandidaten, så administratören kan
/// se VAD som kommer att appliceras innan hen trycker Applicera.
///
/// Att applicera en brandväggskonfiguration är en handling med konsekvenser —
/// en bortglömd ändring i en policy eller ett gränssnitt kan stänga ute en
/// själv (jämför rollback-timeouten, som finns just därför). Fram tills nu
/// visade GUI:t bara ATT det fanns oapplicerade ändringar, aldrig vilka.
///
/// Jämförelsen görs på configens JSON-representation i stället för fält för
/// fält på modellklasserna. Det är medvetet: ett nytt fält i modellen dyker
/// då upp i diffen automatiskt, i stället för att tyst saknas tills någon
/// kommer ihåg att uppdatera en parallell lista. Priset är att fältnamnen är
/// JSON-nycklar, vilket vi kompenserar med [fieldLabels].
library;

/// Vad som hänt med en post.
enum ChangeKind { added, removed, modified }

/// En ändring, redo att visas.
///
/// [section] är configens toppnivånyckel ("policies", "interfaces", ...),
/// [item] identifierar posten inom sektionen (en policys namn, ett
/// gränssnitts enhet) och [field] det enskilda fältet — tomt när hela posten
/// lagts till eller tagits bort.
class ConfigChange {
  final String section;
  final String item;
  final String field;
  final ChangeKind kind;
  final String? before;
  final String? after;

  const ConfigChange({
    required this.section,
    required this.item,
    required this.kind,
    this.field = '',
    this.before,
    this.after,
  });

  @override
  String toString() => '$section/$item${field.isEmpty ? '' : '.$field'} '
      '${kind.name}: $before -> $after';
}

/// Nycklar som identifierar en post i en lista, i prioritetsordning.
///
/// Att matcha listor på ID i stället för på position är hela skillnaden
/// mellan en användbar och en oläslig diff: flyttar man en policy ett steg
/// upp skulle en positionsbaserad jämförelse rapportera att varenda rad
/// därunder ändrats.
/// `mac` och `ip` finns med för poster som saknar egen nyckel — en
/// DHCP-reservation identifieras av sin MAC-adress, inte av ett ID.
const List<String> _identityKeys = ['id', 'name', 'device', 'mac', 'ip'];

/// Fält vi medvetet inte rapporterar.
///
/// Agenten äger de här och skriver dem utanför Safe Apply (hot-listornas
/// uppdateringsstatus, antal poster). De ändras av sig själva och är inte
/// något administratören "gjort" — att visa dem i listan över egna ändringar
/// vore direkt missvisande.
const Set<String> _ignoredFields = {
  'last_updated',
  'last_error',
  'entry_count',
};

/// Sektioner i den ordning de visas. Det viktigaste först: gränssnitt och
/// policyer styr trafiken, resten är stödfunktioner.
const List<String> sectionOrder = [
  'interfaces',
  'policies',
  'objects',
  'zones',
  'static_routes',
  'nat',
  'sni_routes',
  'dns',
  'openvpn',
  'wireguard',
  'ids',
  'syslog',
  'settings',
];

/// Jämför två configar och returnerar ändringarna, sektionsvis i
/// [sectionOrder].
List<ConfigChange> diffConfigs(
  Map<String, dynamic>? running,
  Map<String, dynamic>? candidate,
) {
  if (running == null || candidate == null) return const [];

  final sections = <String>{...running.keys, ...candidate.keys}.toList()
    ..sort((a, b) {
      final ia = sectionOrder.indexOf(a);
      final ib = sectionOrder.indexOf(b);
      if (ia == -1 && ib == -1) return a.compareTo(b);
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });

  final changes = <ConfigChange>[];
  for (final section in sections) {
    _diffValue(changes, section, '', '', running[section], candidate[section]);
  }
  return changes;
}

void _diffValue(
  List<ConfigChange> out,
  String section,
  String item,
  String field,
  dynamic before,
  dynamic after,
) {
  if (_equal(before, after)) return;

  if (before is List && after is List) {
    _diffList(out, section, before, after);
    return;
  }
  if (before is Map && after is Map) {
    _diffMap(out, section, item, before.cast<String, dynamic>(),
        after.cast<String, dynamic>());
    return;
  }

  out.add(ConfigChange(
    section: section,
    item: item,
    field: field,
    kind: ChangeKind.modified,
    before: _render(before),
    after: _render(after),
  ));
}

void _diffList(List<ConfigChange> out, String section, List before, List after) {
  final key = _identityKeyFor(before) ?? _identityKeyFor(after);
  if (key == null) {
    // Lista av enkla värden (t.ex. DNS-servrar): jämför som helhet. Att peka
    // ut vilket element som ändrats ger inget — man läser ändå hela listan.
    out.add(ConfigChange(
      section: section,
      item: '',
      kind: ChangeKind.modified,
      before: _render(before),
      after: _render(after),
    ));
    return;
  }

  final beforeById = _byIdentity(before, key);
  final afterById = _byIdentity(after, key);

  for (final id in afterById.keys) {
    if (!beforeById.containsKey(id)) {
      out.add(ConfigChange(
        section: section,
        item: _label(afterById[id]!, id),
        kind: ChangeKind.added,
        after: _summary(afterById[id]!),
      ));
    }
  }
  for (final id in beforeById.keys) {
    if (!afterById.containsKey(id)) {
      out.add(ConfigChange(
        section: section,
        item: _label(beforeById[id]!, id),
        kind: ChangeKind.removed,
        before: _summary(beforeById[id]!),
      ));
      continue;
    }
    _diffMap(out, section, _label(afterById[id]!, id), beforeById[id]!,
        afterById[id]!);
  }
}

void _diffMap(
  List<ConfigChange> out,
  String section,
  String item,
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  final keys = <String>{...before.keys, ...after.keys}.toList()..sort();
  for (final key in keys) {
    if (_ignoredFields.contains(key)) continue;
    final b = before[key];
    final a = after[key];
    if (_equal(b, a)) continue;

    if (b is Map && a is Map) {
      // Nästlad struktur (t.ex. en policys nat-block): behåll postens namn
      // som item och prefixa fältet, så raden fortfarande går att placera.
      final nested = <ConfigChange>[];
      _diffMap(nested, section, item, b.cast<String, dynamic>(),
          a.cast<String, dynamic>());
      for (final c in nested) {
        out.add(ConfigChange(
          section: c.section,
          item: c.item,
          field: c.field.isEmpty ? key : '$key.${c.field}',
          kind: c.kind,
          before: c.before,
          after: c.after,
        ));
      }
      continue;
    }
    if (b is List && a is List) {
      final key0 = _identityKeyFor(b) ?? _identityKeyFor(a);
      if (key0 != null) {
        // Lista av objekt inuti en post (t.ex. DHCP-reservationer på ett
        // gränssnitt) — jämför per post i stället för som en textklump.
        final nested = <ConfigChange>[];
        _diffList(nested, section, b, a);
        for (final c in nested) {
          out.add(ConfigChange(
            section: c.section,
            item: item.isEmpty ? c.item : '$item › ${c.item}',
            field: c.field,
            kind: c.kind,
            before: c.before,
            after: c.after,
          ));
        }
        continue;
      }
    }

    out.add(ConfigChange(
      section: section,
      item: item,
      field: key,
      kind: ChangeKind.modified,
      before: _render(b),
      after: _render(a),
    ));
  }
}

String? _identityKeyFor(List list) {
  if (list.isEmpty) return null;
  for (final key in _identityKeys) {
    if (list.every((e) => e is Map && e[key] != null && '${e[key]}'.isNotEmpty)) {
      return key;
    }
  }
  return null;
}

Map<String, Map<String, dynamic>> _byIdentity(List list, String key) {
  final out = <String, Map<String, dynamic>>{};
  for (final e in list) {
    if (e is! Map) continue;
    out['${e[key]}'] = e.cast<String, dynamic>();
  }
  return out;
}

/// Läsbar etikett för en post: namnet om det finns, annars enheten, annars
/// identiteten. Ett ID som "obj_auto_1787..." säger ingenting för den som
/// läser listan.
String _label(Map<String, dynamic> item, String fallback) {
  for (final key in ['name', 'hostname', 'device', 'network', 'ip']) {
    final v = item[key];
    if (v != null && '$v'.isNotEmpty) return '$v';
  }
  return fallback;
}

/// Kort sammanfattning av en tillagd/borttagen post — de fält som säger mest
/// om vad posten ÄR, inte hela JSON-dumpen.
String _summary(Map<String, dynamic> item) {
  const interesting = [
    'action', 'source_zone', 'dest_zone', 'service', 'zone', 'ipv4',
    'address_type', 'type', 'values', 'network', 'gateway', 'ip', 'mac',
    'enabled',
  ];
  final parts = <String>[];
  for (final key in interesting) {
    final v = item[key];
    if (v == null) continue;
    final rendered = _render(v);
    if (rendered.isEmpty) continue;
    parts.add('$key=$rendered');
  }
  return parts.join(', ');
}

String _render(dynamic value) {
  if (value == null) return '';
  if (value is List) {
    if (value.isEmpty) return '[]';
    return value.map(_render).join(', ');
  }
  if (value is Map) {
    return value.entries
        .where((e) => !_ignoredFields.contains(e.key))
        .map((e) => '${e.key}=${_render(e.value)}')
        .join(', ');
  }
  return '$value';
}

bool _equal(dynamic a, dynamic b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    final keys = <String>{...a.keys.cast<String>(), ...b.keys.cast<String>()};
    for (final k in keys) {
      if (_ignoredFields.contains(k)) continue;
      if (!_equal(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_equal(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Läsbara etiketter för sektionsnamnen. Saknas en nyckel visas den råa
/// JSON-nyckeln — bättre en teknisk rubrik än en utelämnad ändring.
const Map<String, String> sectionLabels = {
  'interfaces': 'Gränssnitt',
  'policies': 'Policyer',
  'objects': 'Objekt',
  'zones': 'Zoner',
  'static_routes': 'Statiska rutter',
  'nat': 'NAT',
  'sni_routes': 'SNI-routning',
  'dns': 'DNS',
  'openvpn': 'OpenVPN',
  'wireguard': 'WireGuard',
  'ids': 'IDS',
  'syslog': 'Syslog',
  'settings': 'Inställningar',
};

/// Läsbara etiketter för de vanligaste fältnamnen.
const Map<String, String> fieldLabels = {
  'enabled': 'aktiverad',
  'ipv4': 'IP-adress',
  'address_type': 'adresstyp',
  'zone': 'zon',
  'source_zone': 'från',
  'dest_zone': 'till',
  'service': 'tjänst',
  'action': 'åtgärd',
  'gateway': 'gateway',
  'dns_servers': 'DNS-servrar',
  'mtu': 'MTU',
  'mac_address': 'MAC-adress',
  'timezone': 'tidszon',
  'rollback_timeout_sec': 'rollback-timeout',
  'values': 'värden',
  'reservations': 'reservationer',
};
