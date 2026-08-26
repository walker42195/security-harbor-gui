import 'package:flutter_test/flutter_test.dart';
import 'package:security_harbor_gui/models/config_model.dart';
import 'package:security_harbor_gui/object_index.dart';

ObjectModel obj(String name, List<String> values, {String? sourceKind}) => ObjectModel(
      id: 'obj_$name',
      name: name,
      type: 'host',
      values: values,
      description: '',
      source: sourceKind == null ? null : ObjectSourceModel(kind: sourceKind, refreshHours: 24),
    );

void main() {
  test('exakt adress slås upp', () {
    final idx = ObjectNameIndex.build([obj('Skrivare', ['10.0.0.50'])]);
    expect(idx.lookup('10.0.0.50'), 'Skrivare');
    expect(idx.lookup('10.0.0.51'), isNull);
  });

  test('CIDR matchar adresser i nätet', () {
    final idx = ObjectNameIndex.build([obj('VLAN9', ['10.9.9.0/24'])]);
    expect(idx.lookup('10.9.9.100'), 'VLAN9');
    expect(idx.lookup('10.8.8.100'), isNull);
  });

  test('/0 matchar allt, /32 bara sig själv', () {
    expect(ObjectNameIndex.build([obj('Alla', ['0.0.0.0/0'])]).lookup('8.8.8.8'), 'Alla');
    final host = ObjectNameIndex.build([obj('En', ['10.0.0.5/32'])]);
    expect(host.lookup('10.0.0.5'), 'En');
    expect(host.lookup('10.0.0.6'), isNull);
  });

  // Kärnan i prestandaproblemet: en AbuseIPDB-lista har 126 616 poster, och
  // "den här adressen finns i AbuseIPDB" är inget läsbart enhetsnamn.
  test('hot-listor tas inte med i indexet', () {
    final idx = ObjectNameIndex.build([
      obj('AbuseIPDB', ['1.2.3.4', '5.6.7.8'], sourceKind: 'custom_url'),
      obj('Spamhaus', ['9.9.9.0/24'], sourceKind: 'spamhaus_drop'),
      obj('Skrivare', ['10.0.0.50']),
    ]);
    expect(idx.lookup('1.2.3.4'), isNull);
    expect(idx.lookup('9.9.9.9'), isNull);
    expect(idx.lookup('10.0.0.50'), 'Skrivare');
  });

  test('ogiltiga värden fäller inte indexet', () {
    final idx = ObjectNameIndex.build([obj('Trasig', ['', 'inte-en-ip', '10.0.0.0/99', '10.0.0.7'])]);
    expect(idx.lookup('10.0.0.7'), 'Trasig', reason: 'giltiga värden fungerar ändå');
    expect(idx.lookup('10.0.0.0'), isNull, reason: 'en ogiltig CIDR ska inte ge nät');
  });

  // Exakta värden jämförs som STRÄNGAR, inte som tolkade IPv4-adresser. Det
  // är avsiktligt: annars skulle IPv6-objekt sluta gå att slå upp. Priset är
  // att ett skräpvärde matchar sig självt, vilket är ofarligt — en loggrads
  // adressfält innehåller alltid en riktig adress.
  test('IPv6-värden går fortfarande att slå upp', () {
    final idx = ObjectNameIndex.build([obj('IPv6-host', ['fe80::1'])]);
    expect(idx.lookup('fe80::1'), 'IPv6-host');
  });

  test('tomt index och tom adress är ofarliga', () {
    expect(ObjectNameIndex.empty().lookup('10.0.0.1'), isNull);
    expect(ObjectNameIndex.build([]).lookup(''), isNull);
  });

  // Cachen måste komma ihåg även UTEBLIVNA träffar, annars betalas
  // nätverksgenomgången om och om igen för samma adress.
  test('upprepade uppslag är billiga', () {
    final nets = [for (var i = 0; i < 200; i++) '10.$i.0.0/16'];
    final idx = ObjectNameIndex.build([obj('Nät', nets)]);
    final sw = Stopwatch()..start();
    for (var i = 0; i < 100000; i++) {
      idx.lookup('203.0.113.9'); // träffar inget
    }
    sw.stop();
    expect(sw.elapsedMilliseconds, lessThan(200),
        reason: '100 000 uppslag tog ${sw.elapsedMilliseconds} ms — cachen fungerar inte');
  });

  test('realistisk storlek går fort att bygga och söka i', () {
    // Motsvarar installationen som låste sig: en stor hot-lista plus vanliga
    // objekt.
    final huge = [for (var i = 0; i < 126616; i++) '${1 + i % 223}.${(i ~/ 256) % 256}.${i % 256}.1'];
    final objects = [
      obj('AbuseIPDB', huge, sourceKind: 'custom_url'),
      obj('VLAN9', ['10.9.9.0/24']),
      obj('Skrivare', ['10.0.0.50']),
    ];

    final sw = Stopwatch()..start();
    final idx = ObjectNameIndex.build(objects);
    final built = sw.elapsedMilliseconds;

    sw.reset();
    for (var i = 0; i < 3000; i++) {
      idx.lookup('10.9.9.${i % 256}');
      idx.lookup('10.0.0.50');
    }
    sw.stop();

    expect(built, lessThan(500), reason: 'bygget tog $built ms');
    expect(sw.elapsedMilliseconds, lessThan(100),
        reason: '6000 uppslag tog ${sw.elapsedMilliseconds} ms');
  });
}
