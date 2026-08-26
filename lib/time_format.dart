/// Formatering av tidsstämplar som kommer från brandväggen.
///
/// Bakgrunden (rapporterad 2026-08-26): "Tidigare versioner" i Inställningar
/// visade en tid som låg två timmar fel, medan trafikloggen visade rätt tid.
/// Båda skrevs ut som RÅ STRÄNG, rakt av — skillnaden satt i källformatet:
///
///   versions/index.json   `date -u +%Y-%m-%dT%H:%M:%SZ`  → UTC ("...Z")
///   trafikloggen          journalctl -o short-iso        → lokal tid + offset
///
/// Loggen såg alltså rätt ut av en slump: serverns lokala tid råkade vara
/// samma som administratörens. UTC-stämpeln gjorde det inte.
///
/// Lösningen är att ALDRIG visa en tidsstämpel oomvandlad. Allt som kommer
/// från servern tolkas här och visas i betraktarens lokala tid, oavsett vilken
/// tidszon servern står i.
library;

/// Formaterar en ISO-8601-tidsstämpel från servern som lokal tid,
/// `2026-08-26 08:57:29`.
///
/// Returnerar strängen oförändrad om den inte går att tolka — en oväntad
/// stämpel ska visas som den är, inte försvinna.
String formatServerTime(String? raw, {bool withSeconds = true}) {
  if (raw == null) return '';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';

  final parsed = parseServerTime(trimmed);
  if (parsed == null) return trimmed;

  final local = parsed.toLocal();
  final date = '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
  final time = '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}'
      '${withSeconds ? ':${local.second.toString().padLeft(2, '0')}' : ''}';
  return '$date $time';
}

/// Tolkar de tidsstämpelformat brandväggen faktiskt skickar.
///
/// `DateTime.parse` klarar `2026-08-26T06:57:29Z` och `...+02:00`, men INTE
/// journalds `short-iso`, som skriver offseten utan kolon (`+0200`). Utan den
/// normaliseringen hade varje loggrad fallit tillbaka på råtext.
DateTime? parseServerTime(String raw) {
  final normalized = _normalizeOffset(raw.trim());
  return DateTime.tryParse(normalized);
}

final RegExp _compactOffset = RegExp(r'([+-])(\d{2})(\d{2})$');

String _normalizeOffset(String value) =>
    value.replaceFirstMapped(_compactOffset, (m) => '${m[1]}${m[2]}:${m[3]}');
