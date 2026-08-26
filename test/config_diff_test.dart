import 'package:flutter_test/flutter_test.dart';
import 'package:security_harbor_gui/config_diff.dart';

Map<String, dynamic> cfg({
  List<Map<String, dynamic>>? policies,
  List<Map<String, dynamic>>? interfaces,
  Map<String, dynamic>? settings,
}) =>
    {
      'interfaces': interfaces ??
          [
            {'id': 'lan0', 'device': 'ens19', 'name': 'LAN', 'zone': 'LAN', 'enabled': true, 'ipv4': '10.0.0.1/24'},
          ],
      'policies': policies ??
          [
            {'id': 'p1', 'name': 'LAN till WAN', 'source_zone': 'LAN', 'dest_zone': 'WAN', 'service': 'ANY', 'action': 'accept', 'enabled': true},
          ],
      'settings': settings ?? {'hostname': 'security-harbor', 'rollback_timeout_sec': 30},
    };

void main() {
  test('identiska configar ger inga ändringar', () {
    expect(diffConfigs(cfg(), cfg()), isEmpty);
  });

  test('null-config ger inga ändringar i stället för att krascha', () {
    expect(diffConfigs(null, cfg()), isEmpty);
    expect(diffConfigs(cfg(), null), isEmpty);
  });

  test('ändrat fält rapporteras med före och efter', () {
    final after = cfg(policies: [
      {'id': 'p1', 'name': 'LAN till WAN', 'source_zone': 'LAN', 'dest_zone': 'WAN', 'service': 'HTTPS', 'action': 'accept', 'enabled': true},
    ]);
    final changes = diffConfigs(cfg(), after);
    expect(changes, hasLength(1));
    expect(changes.first.section, 'policies');
    expect(changes.first.item, 'LAN till WAN');
    expect(changes.first.field, 'service');
    expect(changes.first.before, 'ANY');
    expect(changes.first.after, 'HTTPS');
    expect(changes.first.kind, ChangeKind.modified);
  });

  test('tillagd post', () {
    final after = cfg(policies: [
      {'id': 'p1', 'name': 'LAN till WAN', 'source_zone': 'LAN', 'dest_zone': 'WAN', 'service': 'ANY', 'action': 'accept', 'enabled': true},
      {'id': 'p2', 'name': 'Blockera IoT', 'source_zone': 'IOT', 'dest_zone': 'WAN', 'service': 'ANY', 'action': 'deny', 'enabled': true},
    ]);
    final changes = diffConfigs(cfg(), after);
    expect(changes, hasLength(1));
    expect(changes.first.kind, ChangeKind.added);
    expect(changes.first.item, 'Blockera IoT');
    expect(changes.first.after, contains('action=deny'));
  });

  test('borttagen post', () {
    final changes = diffConfigs(cfg(), cfg(policies: []));
    expect(changes, hasLength(1));
    expect(changes.first.kind, ChangeKind.removed);
    expect(changes.first.item, 'LAN till WAN');
  });

  // Det här är hela poängen med att matcha på ID: en omordning ska inte
  // rapporteras som att varenda rad ändrats.
  test('omordnad lista utan innehållsändring ger inga fältändringar', () {
    final a = cfg(policies: [
      {'id': 'p1', 'name': 'A', 'service': 'ANY'},
      {'id': 'p2', 'name': 'B', 'service': 'HTTPS'},
    ]);
    final b = cfg(policies: [
      {'id': 'p2', 'name': 'B', 'service': 'HTTPS'},
      {'id': 'p1', 'name': 'A', 'service': 'ANY'},
    ]);
    expect(diffConfigs(a, b), isEmpty);
  });

  test('agentägda statusfält rapporteras inte som egna ändringar', () {
    final a = cfg();
    final b = cfg();
    (a['policies'] as List)[0]['last_updated'] = '2026-08-26T10:00:00Z';
    (b['policies'] as List)[0]['last_updated'] = '2026-08-26T11:00:00Z';
    (b['policies'] as List)[0]['entry_count'] = 42;
    expect(diffConfigs(a, b), isEmpty);
  });

  test('nästlad struktur behåller postens namn och prefixar fältet', () {
    final a = cfg(policies: [
      {'id': 'p1', 'name': 'Port forward', 'nat': {'internal_ip': '10.0.0.5', 'internal_port': 80}},
    ]);
    final b = cfg(policies: [
      {'id': 'p1', 'name': 'Port forward', 'nat': {'internal_ip': '10.0.0.6', 'internal_port': 80}},
    ]);
    final changes = diffConfigs(a, b);
    expect(changes, hasLength(1));
    expect(changes.first.item, 'Port forward');
    expect(changes.first.field, 'nat.internal_ip');
    expect(changes.first.after, '10.0.0.6');
  });

  test('lista av objekt inuti en post jämförs per post', () {
    final a = cfg(interfaces: [
      {'id': 'vlan9', 'device': 'ens19.9', 'name': 'VLAN 9', 'dhcp': {'reservations': [
        {'mac': 'aa:aa:aa:aa:aa:01', 'ip': '10.9.9.100', 'hostname': 'skrivare'},
      ]}},
    ]);
    final b = cfg(interfaces: [
      {'id': 'vlan9', 'device': 'ens19.9', 'name': 'VLAN 9', 'dhcp': {'reservations': [
        {'mac': 'aa:aa:aa:aa:aa:01', 'ip': '10.9.9.100', 'hostname': 'skrivare'},
        {'mac': 'bb:bb:bb:bb:bb:02', 'ip': '10.9.9.101', 'hostname': 'kamera'},
      ]}},
    ]);
    final changes = diffConfigs(a, b);
    expect(changes, hasLength(1));
    expect(changes.first.kind, ChangeKind.added);
    expect(changes.first.item, contains('kamera'));
  });

  test('lista av enkla värden jämförs som helhet', () {
    final a = cfg(interfaces: [
      {'id': 'lan0', 'device': 'ens19', 'name': 'LAN', 'dns_servers': ['10.0.0.1']},
    ]);
    final b = cfg(interfaces: [
      {'id': 'lan0', 'device': 'ens19', 'name': 'LAN', 'dns_servers': ['10.0.0.1', '1.1.1.1']},
    ]);
    final changes = diffConfigs(a, b);
    expect(changes, hasLength(1));
    expect(changes.first.field, 'dns_servers');
    expect(changes.first.after, '10.0.0.1, 1.1.1.1');
  });

  test('inställningar jämförs fält för fält', () {
    final changes = diffConfigs(
      cfg(),
      cfg(settings: {'hostname': 'security-harbor', 'rollback_timeout_sec': 62}),
    );
    expect(changes, hasLength(1));
    expect(changes.first.section, 'settings');
    expect(changes.first.field, 'rollback_timeout_sec');
    expect(changes.first.after, '62');
  });

  test('sektionerna kommer i den definierade ordningen', () {
    final a = cfg();
    final b = cfg(
      policies: [
        {'id': 'p1', 'name': 'LAN till WAN', 'source_zone': 'LAN', 'dest_zone': 'WAN', 'service': 'HTTPS', 'action': 'accept', 'enabled': true},
      ],
      interfaces: [
        {'id': 'lan0', 'device': 'ens19', 'name': 'LAN', 'zone': 'LAN', 'enabled': true, 'ipv4': '10.0.0.2/24'},
      ],
      settings: {'hostname': 'ny', 'rollback_timeout_sec': 30},
    );
    final sections = diffConfigs(a, b).map((c) => c.section).toList();
    expect(sections, ['interfaces', 'policies', 'settings']);
  });

  test('posten identifieras med namn, inte med ett genererat ID', () {
    final a = cfg(policies: []);
    final b = cfg(policies: [
      {'id': 'obj_auto_1787515912681', 'name': 'Gästnät', 'action': 'deny'},
    ]);
    expect(diffConfigs(a, b).first.item, 'Gästnät');
  });

  // En hot-lista kan ha över hundratusen poster. Renderas de som en
  // sammanfogad sträng låser sig "Visa ändringar" — och siffran är ändå det
  // enda intressanta (AbuseIPDB-listan, 2026-08-26).
  test('långa värdelistor sammanfattas i stället för att skrivas ut', () {
    final small = cfg(interfaces: [
      {'id': 'lan0', 'device': 'ens19', 'name': 'LAN', 'dns_servers': ['10.0.0.1']},
    ]);
    final huge = cfg(interfaces: [
      {
        'id': 'lan0', 'device': 'ens19', 'name': 'LAN',
        'dns_servers': List.generate(126616, (i) => '10.0.${i ~/ 256}.${i % 256}'),
      },
    ]);

    final changes = diffConfigs(small, huge);
    expect(changes, hasLength(1));
    final after = changes.first.after!;
    expect(after, contains('126616 poster'));
    expect(after.length, lessThan(200),
        reason: 'utskriften måste vara kort, annars låser dialogen sig');
  });

  test('korta listor skrivs fortfarande ut i sin helhet', () {
    final a = cfg(interfaces: [
      {'id': 'lan0', 'device': 'ens19', 'name': 'LAN', 'dns_servers': ['10.0.0.1']},
    ]);
    final b = cfg(interfaces: [
      {'id': 'lan0', 'device': 'ens19', 'name': 'LAN', 'dns_servers': ['10.0.0.1', '1.1.1.1']},
    ]);
    expect(diffConfigs(a, b).first.after, '10.0.0.1, 1.1.1.1');
  });
}
