import 'package:flutter_test/flutter_test.dart';
import 'package:security_harbor_gui/models/config_model.dart';
import 'package:security_harbor_gui/object_filter.dart';

ObjectModel obj(
  String name, {
  String type = 'host',
  List<String> values = const [],
  String description = '',
  String? sourceKind,
  String id = '',
}) =>
    ObjectModel(
      id: id.isEmpty ? 'obj_$name' : id,
      name: name,
      type: type,
      values: values,
      description: description,
      source: sourceKind == null
          ? null
          : ObjectSourceModel(kind: sourceKind, refreshHours: 24),
    );

List<String> names(List<ObjectModel> list) => list.map((o) => o.name).toList();

void main() {
  group('kategorisering', () {
    test('grupp är alltid grupp', () {
      expect(objectCategoryOf(obj('G', type: 'group', values: ['a', 'b'])),
          ObjectCategory.group);
    });

    // Kärnan: GUI:t hårdkodade type='host' för allt, så en installation har
    // nät lagrade som host. Filtret måste ändå hitta dem.
    test('CIDR lagrad som host räknas som nät', () {
      expect(objectCategoryOf(obj('VLAN1', values: ['10.0.0.0/24'])),
          ObjectCategory.network);
    });

    test('bar adress är en värd', () {
      expect(objectCategoryOf(obj('Skrivare', values: ['10.0.0.50'])),
          ObjectCategory.host);
    });

    test('blandat innehåll räknas som värd', () {
      expect(objectCategoryOf(obj('Mix', values: ['10.0.0.50', '10.9.9.0/24'])),
          ObjectCategory.host);
    });

    test('uttalad network-typ respekteras', () {
      expect(objectCategoryOf(obj('N', type: 'network', values: [])),
          ObjectCategory.network);
    });

    test('automatiska källor väger tyngre än värdena', () {
      expect(objectCategoryOf(obj('Spamhaus', values: ['1.2.3.0/24'], sourceKind: 'spamhaus_drop')),
          ObjectCategory.threatFeed);
      expect(objectCategoryOf(obj('Tor', values: ['1.2.3.4'], sourceKind: 'tor_exit_nodes')),
          ObjectCategory.threatFeed);
      expect(objectCategoryOf(obj('Sverige', values: ['1.2.3.0/24'], sourceKind: 'geoip_country')),
          ObjectCategory.geoip);
    });

    test('tomt objekt är en värd, inte ett nät', () {
      expect(objectCategoryOf(obj('Tom')), ObjectCategory.host);
    });
  });

  group('isCidr', () {
    test('godtar riktiga CIDR', () {
      expect(isCidr('10.0.0.0/24'), isTrue);
      expect(isCidr('0.0.0.0/0'), isTrue);
    });
    test('avvisar allt annat', () {
      for (final v in ['10.0.0.1', '', '/24', '10.0.0.0/', '10.0.0.0/abc']) {
        expect(isCidr(v), isFalse, reason: v);
      }
    });
  });

  group('inferObjectType', () {
    test('bara CIDR ger network', () {
      expect(inferObjectType(['10.0.0.0/24', '10.9.9.0/24']), 'network');
    });
    test('minst en bar adress ger host', () {
      expect(inferObjectType(['10.0.0.0/24', '10.0.0.5']), 'host');
    });
    test('tom lista behåller angiven fallback', () {
      expect(inferObjectType([], fallback: 'group'), 'group');
    });
  });

  group('sökning och sortering', () {
    final objects = [
      obj('Skrivare', values: ['10.0.0.50'], description: 'kontoret'),
      obj('anka', values: ['10.0.0.51']),
      obj('VLAN9', values: ['10.9.9.0/24']),
      obj('Gäster', type: 'group', values: ['obj_VLAN9']),
      obj('Spamhaus', sourceKind: 'spamhaus_drop', values: ['203.0.113.0/24']),
    ];

    test('sorteras på namn som standard, skiftlägesokänsligt', () {
      expect(names(filterAndSortObjects(objects)),
          ['anka', 'Gäster', 'Skrivare', 'Spamhaus', 'VLAN9']);
    });

    test('söker på namn', () {
      expect(names(filterAndSortObjects(objects, query: 'skriv')), ['Skrivare']);
    });

    // En grupps värden är objekt-ID:n. Att söka i dem hade matchat interna
    // identifierare; medlemmarnas namn är det man faktiskt letar efter.
    test('en grupp hittas på sina medlemmars namn', () {
      expect(names(filterAndSortObjects(objects, query: 'vlan')), ['Gäster', 'VLAN9']);
    });

    test('gruppens råa ID-värden matchar inte', () {
      final grupp = obj('Team', type: 'group', values: ['obj_1787570910581'], id: 'g1');
      final medlem = obj('Laptop', values: ['10.0.0.9'], id: 'obj_1787570910581');
      expect(names(filterAndSortObjects([grupp, medlem], query: '1787570910581')), isEmpty);
      expect(names(filterAndSortObjects([grupp, medlem], query: 'laptop')), ['Laptop', 'Team']);
    });

    test('söker på värden — man letar ofta efter en adress', () {
      expect(names(filterAndSortObjects(objects, query: '10.0.0.51')), ['anka']);
    });

    test('söker på beskrivning', () {
      expect(names(filterAndSortObjects(objects, query: 'kontoret')), ['Skrivare']);
    });

    // En Spamhaus-lista har tusentals poster; att söka i dem hade gett träff
    // på nästan vad som helst och gjort varje tangenttryck långsamt.
    test('hot-listors värden söks inte', () {
      expect(names(filterAndSortObjects(objects, query: '203.0.113.0/24')), isEmpty);
      expect(names(filterAndSortObjects(objects, query: 'spamhaus')), ['Spamhaus']);
    });

    test('filtrerar på kategori', () {
      expect(names(filterAndSortObjects(objects, category: ObjectCategory.network)), ['VLAN9']);
      expect(names(filterAndSortObjects(objects, category: ObjectCategory.group)), ['Gäster']);
      expect(names(filterAndSortObjects(objects, category: ObjectCategory.threatFeed)), ['Spamhaus']);
      expect(names(filterAndSortObjects(objects, category: ObjectCategory.host)),
          ['anka', 'Skrivare']);
    });

    test('sökning och kategori kombineras', () {
      expect(names(filterAndSortObjects(objects, query: 'a', category: ObjectCategory.host)),
          ['anka', 'Skrivare']);
      expect(names(filterAndSortObjects(objects, query: 'skriv', category: ObjectCategory.network)),
          isEmpty);
    });

    test('originallistan lämnas orörd', () {
      final before = names(objects);
      filterAndSortObjects(objects);
      expect(names(objects), before);
    });
  });

  test('räknare per kategori', () {
    final counts = countByCategory([
      obj('a', values: ['10.0.0.1']),
      obj('b', values: ['10.0.0.2']),
      obj('c', values: ['10.9.9.0/24']),
      obj('d', type: 'group'),
    ]);
    expect(counts[ObjectCategory.host], 2);
    expect(counts[ObjectCategory.network], 1);
    expect(counts[ObjectCategory.group], 1);
    expect(counts[ObjectCategory.geoip], isNull);
  });
}
