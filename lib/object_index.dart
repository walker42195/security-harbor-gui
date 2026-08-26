/// Snabb uppslagning av objektnamn för en IP-adress.
///
/// Loggvyn slog tidigare upp namnet med en LINJÄR genomsökning av varje
/// objekt och varje värde, och gjorde det upp till sex gånger per rad (två i
/// namnfiltret, två i uttrycksfiltret, två vid rendering).
///
/// Det gick an när objekten innehöll en handfull adresser. När en
/// AbuseIPDB-lista med 126 616 poster lades till blev samma kod
/// 500 rader × 6 uppslag × 130 000 värden ≈ 390 miljoner varv — per
/// tangenttryck, eftersom filtret bygger om vyn vid varje ändring. Det låste
/// hela datorn (rapporterat 2026-08-26).
library;

import 'models/config_model.dart';

class ObjectNameIndex {
  /// Exakta adresser → objektnamn. Uppslag i konstant tid.
  final Map<String, String> _exact;

  /// CIDR-poster, som måste jämföras en och en. Hålls kort genom att
  /// hot-listor utelämnas (se [ObjectNameIndex.build]).
  final List<({int base, int mask, String name})> _networks;

  /// Cache för adresser som redan slagits upp, inklusive de som INTE gav
  /// träff — annars betalar man nätverksgenomgången om och om igen för
  /// samma adress.
  final Map<String, String?> _cache = {};

  ObjectNameIndex._(this._exact, this._networks);

  /// Tomt index, för när ingen konfiguration hunnit laddas.
  factory ObjectNameIndex.empty() => ObjectNameIndex._(const {}, const []);

  /// Bygger indexet en gång per konfiguration.
  ///
  /// Hot-listor (objekt med en automatisk källa) UTELÄMNAS medvetet. Att en
  /// adress finns i Spamhaus eller AbuseIPDB är inget läsbart namn på en
  /// enhet — Källa-kolumnen ska visa "Skrivare", inte "AbuseIPDB". Det är
  /// dessutom exakt de objekten som är enorma.
  factory ObjectNameIndex.build(List<ObjectModel> objects) {
    final exact = <String, String>{};
    final networks = <({int base, int mask, String name})>[];

    for (final obj in objects) {
      if ((obj.source?.kind ?? '').isNotEmpty) continue;
      for (final value in obj.values) {
        final v = value.trim();
        if (v.isEmpty) continue;
        if (!v.contains('/')) {
          exact.putIfAbsent(v, () => obj.name);
          continue;
        }
        final net = _parseCidr(v);
        if (net != null) {
          networks.add((base: net.$1, mask: net.$2, name: obj.name));
        }
      }
    }
    return ObjectNameIndex._(exact, networks);
  }

  /// Namnet på det objekt [ip] tillhör, eller null.
  String? lookup(String ip) {
    if (ip.isEmpty) return null;
    if (_cache.containsKey(ip)) return _cache[ip];

    String? result = _exact[ip];
    if (result == null) {
      final addr = ipToInt(ip);
      if (addr != null) {
        for (final n in _networks) {
          if ((addr & n.mask) == (n.base & n.mask)) {
            result = n.name;
            break;
          }
        }
      }
    }
    _cache[ip] = result;
    return result;
  }
}

/// (nätadress, mask) för en CIDR, eller null om den inte går att tolka.
(int, int)? _parseCidr(String cidr) {
  final parts = cidr.split('/');
  if (parts.length != 2) return null;
  final base = ipToInt(parts[0]);
  final prefix = int.tryParse(parts[1]);
  if (base == null || prefix == null || prefix < 0 || prefix > 32) return null;
  final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  return (base, mask);
}

/// IPv4 som heltal, eller null. IPv6 stöds inte — objekten i den här vyn är
/// IPv4, och en IPv6-adress ger helt enkelt ingen namnträff.
int? ipToInt(String ip) {
  final octets = ip.split('.');
  if (octets.length != 4) return null;
  var result = 0;
  for (final o in octets) {
    final v = int.tryParse(o);
    if (v == null || v < 0 || v > 255) return null;
    result = (result << 8) | v;
  }
  return result;
}
