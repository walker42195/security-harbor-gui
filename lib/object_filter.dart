/// Sökning, kategorisering och sortering av nätverksobjekt.
///
/// Objektsidan listade tidigare allt i konfigurationsordning, utan sökfält och
/// utan möjlighet att skilja grupper från värdar från hot-listor. Med några
/// hundra objekt — och en Spamhaus-lista bland dem — blir den listan obrukbar.
library;

import 'models/config_model.dart';

/// De kategorier ett objekt kan tillhöra i objektvyn.
enum ObjectCategory { group, network, host, geoip, threatFeed }

/// Kategorin för ett objekt.
///
/// Kategorin HÄRLEDS ur innehållet i stället för att bara läsa `type`-fältet.
/// Anledningen är att GUI:t fram till 2026-08-26 hårdkodade `type: 'host'` för
/// varje objekt det skapade — även när värdena var CIDR-nät. En installation
/// har därför objekt som "VLAN1 = 10.0.0.0/24" lagrade som *host*. Ett filter
/// som bara läste `type` hade visat en tom "Nät"-kategori på just den data
/// användaren faktiskt har.
///
/// Ordningen är medveten: en grupp är alltid en grupp oavsett innehåll, och en
/// automatisk källa (Spamhaus, Tor, GeoIP) väger tyngre än värdena den råkar
/// ha hämtat just nu.
ObjectCategory objectCategoryOf(ObjectModel obj) {
  if (obj.type == 'group') return ObjectCategory.group;

  final kind = obj.source?.kind;
  if (kind != null && kind.isNotEmpty) {
    return kind == 'geoip_country' ? ObjectCategory.geoip : ObjectCategory.threatFeed;
  }

  if (obj.type == 'network') return ObjectCategory.network;

  // Inget uttalat: låt värdena avgöra. Ett objekt vars samtliga värden är
  // CIDR är ett nät, vad `type` än påstår.
  final values = obj.values.where((v) => v.trim().isNotEmpty).toList();
  if (values.isNotEmpty && values.every(isCidr)) return ObjectCategory.network;

  return ObjectCategory.host;
}

/// True för ett CIDR-värde ("10.0.0.0/24"). En bar adress är inte ett nät.
bool isCidr(String value) {
  final trimmed = value.trim();
  final slash = trimmed.indexOf('/');
  if (slash <= 0 || slash == trimmed.length - 1) return false;
  return int.tryParse(trimmed.substring(slash + 1)) != null;
}

/// Den typ ett objekt BÖR sparas som, utifrån sina värden.
///
/// Används när ett objekt sparas i GUI:t, så att nyskapade och redigerade
/// objekt får ett korrekt `type`-fält i stället för att alltid bli "host".
/// Befintliga objekt rättas därmed efterhand, utan migrering.
String inferObjectType(List<String> values, {String fallback = 'host'}) {
  final cleaned = values.where((v) => v.trim().isNotEmpty).toList();
  if (cleaned.isEmpty) return fallback;
  return cleaned.every(isCidr) ? 'network' : 'host';
}

/// Filtrerar på fritext och kategori, och sorterar på namn.
///
/// [category] null betyder alla kategorier. Sökningen träffar namn, värden och
/// beskrivning — värdena är viktiga, eftersom man ofta letar efter "vilket
/// objekt innehåller 10.9.9.50?" snarare än efter ett namn man minns.
///
/// För en GRUPP söks medlemmarnas NAMN, inte deras värden. En grupps värden
/// är objekt-ID:n ("obj_1787570910581") — att söka i dem hade matchat interna
/// identifierare, vilket är obegripligt. Med namnuppslagning blir "vilken
/// grupp innehåller VLAN9?" i stället en fråga man kan ställa.
///
/// Hot-listeobjekt söks INTE på sina värden: en Spamhaus-lista har tusentals
/// poster, och att söka i dem hade dels gjort varje tangenttryck långsamt,
/// dels gett träff på nästan vad som helst.
List<ObjectModel> filterAndSortObjects(
  List<ObjectModel> objects, {
  String query = '',
  ObjectCategory? category,
}) {
  final q = query.trim().toLowerCase();

  final byId = {for (final o in objects) o.id: o};

  final filtered = objects.where((obj) {
    if (category != null && objectCategoryOf(obj) != category) return false;
    if (q.isEmpty) return true;

    if (obj.name.toLowerCase().contains(q)) return true;
    if (obj.description.toLowerCase().contains(q)) return true;

    if (obj.type == 'group') {
      return _memberNames(obj, byId, <String>{}).any((n) => n.contains(q));
    }

    final isFeed = (obj.source?.kind ?? '').isNotEmpty;
    return !isFeed && obj.values.any((v) => v.toLowerCase().contains(q));
  }).toList();

  // Namnsortering som standard, skiftlägesokänsligt. Lika namn faller tillbaka
  // på ID så ordningen är stabil mellan omritningar.
  filtered.sort((a, b) {
    final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return filtered;
}

/// Antal objekt per kategori, för räknarna i filterknapparna. Räknas på den
/// SÖKFILTRERADE listan, så siffrorna speglar vad ett kategoribyte faktiskt
/// skulle visa.
Map<ObjectCategory, int> countByCategory(List<ObjectModel> objects) {
  final counts = <ObjectCategory, int>{};
  for (final obj in objects) {
    final cat = objectCategoryOf(obj);
    counts[cat] = (counts[cat] ?? 0) + 1;
  }
  return counts;
}

/// Namnen på en grupps medlemmar, rekursivt. [seen] bryter cykler — en grupp
/// som (direkt eller indirekt) innehåller sig själv skulle annars ge oändlig
/// rekursion vid varje tangenttryck i sökfältet.
List<String> _memberNames(
  ObjectModel group,
  Map<String, ObjectModel> byId,
  Set<String> seen,
) {
  if (!seen.add(group.id)) return const [];
  final names = <String>[];
  for (final value in group.values) {
    final member = byId[value];
    if (member == null) continue;
    names.add(member.name.toLowerCase());
    if (member.type == 'group') {
      names.addAll(_memberNames(member, byId, seen));
    }
  }
  return names;
}
