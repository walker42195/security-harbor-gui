import 'package:flutter_test/flutter_test.dart';
import 'package:security_harbor_gui/log_filter.dart';

/// En loggrad: LAN-klienten 10.9.9.100 gör en DNS-fråga mot brandväggen,
/// tillåten av regeln "LAN till WAN".
LogRowFields row({
  String src = '10.9.9.100',
  String dst = '8.8.8.8',
  String sport = '51820',
  String dport = '53',
  String proto = 'udp',
  String action = 'accept',
  String rule = 'LAN till WAN',
  String srcName = 'Laptop',
  String dstName = '',
  String srcMac = 'aa:bb:cc:dd:ee:ff',
  String inIface = 'ens19.9',
  String outIface = 'ens18',
  String dir = 'OUT',
}) =>
    {
      'src': [src, srcName],
      'dst': [dst, dstName],
      'sport': [sport],
      'dport': [dport],
      'proto': [proto],
      'action': [action],
      'rule': [rule],
      'srcmac': [srcMac],
      'dstmac': [''],
      'in': [inIface],
      'out': [outIface],
      'dir': [dir],
    };

bool match(String expr, LogRowFields r) => LogFilter.parse(expr).matches(r);

void main() {
  group('grunder', () {
    test('tomt uttryck visar allt', () {
      expect(match('', row()), isTrue);
      expect(match('   ', row()), isTrue);
    });

    test('fält:värde', () {
      expect(match('src:10.9.9.100', row()), isTrue);
      expect(match('src:10.9.9.101', row()), isFalse);
      expect(match('dst:8.8.8.8', row()), isTrue);
    });

    test('fritext söker över alla fält', () {
      expect(match('Laptop', row()), isTrue);
      expect(match('ens18', row()), isTrue);
      expect(match('finns-inte', row()), isFalse);
    });

    test('skiftläge spelar ingen roll', () {
      expect(match('SRC:10.9.9.100', row()), isTrue);
      expect(match('rule:lan TILL wan', row()), isTrue);
      expect(match('Src:Laptop', row()), isTrue);
    });

    test('svenska fältnamn fungerar likvärdigt', () {
      expect(match('källa:10.9.9.100', row()), isTrue);
      expect(match('mål:8.8.8.8', row()), isTrue);
      expect(match('regel:LAN', row()), isTrue);
    });
  });

  group('exkludering', () {
    // Det användaren saknade helt: att kunna skriva ett undantag.
    test('not tar bort träffar', () {
      expect(match('not port:53', row()), isFalse);
      expect(match('not port:443', row()), isTrue);
    });

    test('! och - fungerar som not', () {
      expect(match('!port:53', row()), isFalse);
      expect(match('-port:53', row()), isFalse);
    });

    test('bindestreck mitt i ett värde är inte en operator', () {
      // Annars gick varken MAC-adresser eller regelnamn med bindestreck att
      // filtrera på.
      expect(match('rule:LAN-till-WAN', row(rule: 'LAN-till-WAN')), isTrue);
      expect(match('src:aa-bb-cc', row(srcName: 'aa-bb-cc')), isTrue);
    });
  });

  group('operatorer', () {
    test('and', () {
      expect(match('src:10.9.9.100 and dport:53', row()), isTrue);
      expect(match('src:10.9.9.100 and dport:443', row()), isFalse);
    });

    test('utelämnad operator betyder and, som i Check Point', () {
      expect(match('src:10.9.9.100 dport:53', row()), isTrue);
      expect(match('src:10.9.9.100 dport:443', row()), isFalse);
    });

    test('or', () {
      expect(match('dport:443 or dport:53', row()), isTrue);
      expect(match('dport:443 or dport:80', row()), isFalse);
    });

    test('and binder hårdare än or', () {
      // "a and b or c" = "(a and b) or c"
      expect(match('src:0.0.0.0 and dport:443 or proto:udp', row()), isTrue);
      expect(match('src:0.0.0.0 and dport:443 or proto:tcp', row()), isFalse);
    });

    test('parenteser styr ordningen', () {
      expect(match('(src:10.9.9.100 or src:10.9.9.101) and dport:53', row()), isTrue);
      expect(match('(src:1.1.1.1 or src:2.2.2.2) and dport:53', row()), isFalse);
    });

    test('&& och || fungerar som and/or', () {
      expect(match('src:10.9.9.100 && dport:53', row()), isTrue);
      expect(match('dport:443 || dport:53', row()), isTrue);
    });
  });

  group('sammansatta fält', () {
    test('ip träffar både källa och mål', () {
      expect(match('ip:10.9.9.100', row()), isTrue);
      expect(match('ip:8.8.8.8', row()), isTrue);
      expect(match('ip:1.2.3.4', row()), isFalse);
    });

    test('port träffar både käll- och målport', () {
      expect(match('port:51820', row()), isTrue);
      expect(match('port:53', row()), isTrue);
      expect(match('port:443', row()), isFalse);
    });

    test('iface träffar både in och ut', () {
      expect(match('iface:ens19.9', row()), isTrue);
      expect(match('iface:ens18', row()), isTrue);
    });
  });

  group('värdematchning', () {
    test('CIDR matchar nät', () {
      expect(match('src:10.9.9.0/24', row()), isTrue);
      expect(match('src:10.9.8.0/24', row()), isFalse);
      expect(match('ip:0.0.0.0/0', row()), isTrue);
    });

    test('portar matchas exakt, inte som substräng', () {
      // port:80 fick tidigare aldrig träffa 8080 — det är hela poängen med
      // att tal jämförs numeriskt.
      expect(match('dport:80', row(dport: '8080')), isFalse);
      expect(match('dport:8080', row(dport: '8080')), isTrue);
    });

    test('text matchas som substräng', () {
      expect(match('rule:till', row()), isTrue);
      expect(match('src:Lap', row()), isTrue);
    });

    test('objektnamn går att filtrera på precis som IP', () {
      expect(match('src:Laptop', row()), isTrue);
      expect(match('src:Skrivare', row()), isFalse);
    });

    test('ett tomt radfält matchar aldrig', () {
      // dstmac är tom på den här raden. (Ett tomt VÄRDE i uttrycket,
      // "dst:", är ett syntaxfel och testas i syntaxfel-gruppen.)
      expect(match('dstmac:aa', row()), isFalse);
    });
  });

  group('citattecken', () {
    test('värde med blanksteg', () {
      expect(match('rule:"LAN till WAN"', row()), isTrue);
      expect(match('rule:"LAN till LAN"', row()), isFalse);
    });

    test('citerat ord är fritext, aldrig en operator', () {
      // Annars gick en regel som faktiskt heter "not" inte att söka efter.
      expect(match('"not"', row(rule: 'not')), isTrue);
      expect(match('"and"', row(rule: 'and')), isTrue);
    });
  });

  group('syntaxfel', () {
    test('kastar med begripligt meddelande', () {
      expect(() => LogFilter.parse('src:'), throwsA(isA<LogFilterException>()));
      expect(() => LogFilter.parse('(src:1.2.3.4'), throwsA(isA<LogFilterException>()));
      expect(() => LogFilter.parse('src:1.2.3.4)'), throwsA(isA<LogFilterException>()));
      expect(() => LogFilter.parse('and'), throwsA(isA<LogFilterException>()));
      expect(() => LogFilter.parse('not'), throwsA(isA<LogFilterException>()));
      expect(() => LogFilter.parse('rule:"oavslutad'), throwsA(isA<LogFilterException>()));
    });

    test('okänt fältnamn blir fritext i stället för fel', () {
      // En IPv6-adress innehåller kolon och ska gå att söka på rakt av.
      expect(match('fe80::1', row(srcName: 'fe80::1')), isTrue);
      expect(() => LogFilter.parse('blahonga:1'), returnsNormally);
    });
  });

  group('verkliga uttryck', () {
    test('allt nekat utom DefaultDeny-bruset', () {
      final denied = row(action: 'deny', rule: 'DefaultDeny');
      final realDeny = row(action: 'deny', rule: 'Blockera IoT');
      const expr = 'action:deny and not rule:DefaultDeny';
      expect(match(expr, denied), isFalse);
      expect(match(expr, realDeny), isTrue);
    });

    test('ett nät utom en värd', () {
      const expr = 'src:10.9.9.0/24 and not src:10.9.9.100';
      expect(match(expr, row(src: '10.9.9.100')), isFalse);
      expect(match(expr, row(src: '10.9.9.101')), isTrue);
    });

    test('allt utom vanlig webbtrafik', () {
      const expr = 'not (dport:80 or dport:443)';
      expect(match(expr, row(dport: '443')), isFalse);
      expect(match(expr, row(dport: '53')), isTrue);
    });
  });

  group('hjälpdialogens exempel', () {
    // Dokumentation som visar syntax användaren inte kan skriva är värre än
    // ingen dokumentation alls. Varje exempel i hjälpen måste gå att tolka.
    test('varje exempel går att tolka', () {
      for (final expr in filterHelpExamples) {
        expect(() => LogFilter.parse(expr), returnsNormally, reason: expr);
      }
    });

    test('exemplen gör det de utger sig för', () {
      expect(match('src:10.0.0.5', row(src: '10.0.0.5')), isTrue);
      expect(match('ip:10.9.9.0/24', row()), isTrue);
      expect(match('not port:53', row()), isFalse);
      expect(match('action:deny and not rule:DefaultDeny',
          row(action: 'deny', rule: 'Blockera IoT')), isTrue);
      expect(match('src:10.9.9.0/24 and not src:10.9.9.100', row()), isFalse);
      expect(match('10.0.0.5', row(src: '10.0.0.5')), isTrue);
    });
  });
}
