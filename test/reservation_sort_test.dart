import 'package:flutter_test/flutter_test.dart';
import 'package:security_harbor_gui/models/config_model.dart';
import 'package:security_harbor_gui/screens/dhcp_screen.dart';

({String device, DHCPReservationModel res}) row(
  String hostname,
  String ip,
  String mac, {
  String device = 'ens19.9',
}) =>
    (device: device, res: DHCPReservationModel(hostname: hostname, mac: mac, ip: ip));

List<String> ipsOf(List<({String device, DHCPReservationModel res})> rows) =>
    rows.map((e) => e.res.ip).toList();

bool never(DHCPReservationModel _) => false;

void main() {
  group('ipSortKey', () {
    test('sorterar numeriskt, inte som text', () {
      // Kärnan: en textjämförelse hade gett .10 före .2.
      expect(ipSortKey('10.9.9.2') < ipSortKey('10.9.9.10'), isTrue);
      expect(ipSortKey('10.9.9.99') < ipSortKey('10.9.9.100'), isTrue);
      expect(ipSortKey('10.8.8.1') < ipSortKey('10.9.9.1'), isTrue);
    });

    test('ogiltiga adresser ger 0 i stället för att krascha', () {
      expect(ipSortKey(''), 0);
      expect(ipSortKey('inte-en-ip'), 0);
      expect(ipSortKey('10.9.9'), 0);
      expect(ipSortKey('10.9.9.999'), 0);
    });
  });

  group('sortReservations', () {
    final rows = [
      row('skrivare', '10.9.9.10', 'bb:bb:bb:bb:bb:02'),
      row('Kamera', '10.9.9.2', 'aa:aa:aa:aa:aa:01'),
      row('nas', '10.9.9.100', 'cc:cc:cc:cc:cc:03', device: 'ens19.8'),
    ];

    test('IP sorteras numeriskt', () {
      expect(ipsOf(sortReservations(rows, 1, true, never)),
          ['10.9.9.2', '10.9.9.10', '10.9.9.100']);
    });

    test('fallande ordning vänder listan', () {
      expect(ipsOf(sortReservations(rows, 1, false, never)),
          ['10.9.9.100', '10.9.9.10', '10.9.9.2']);
    });

    test('namn sorteras skiftlägesokänsligt', () {
      final sorted = sortReservations(rows, 0, true, never);
      expect(sorted.map((e) => e.res.hostname).toList(), ['Kamera', 'nas', 'skrivare']);
    });

    test('MAC och gränssnitt går att sortera på', () {
      expect(ipsOf(sortReservations(rows, 2, true, never)).first, '10.9.9.2');
      expect(sortReservations(rows, 3, true, never).first.device, 'ens19.8');
    });

    test('status: utan aktiv utlåning först vid stigande', () {
      bool hasLease(DHCPReservationModel r) => r.ip == '10.9.9.10';
      final sorted = sortReservations(rows, 4, true, hasLease);
      expect(sorted.last.res.ip, '10.9.9.10');
    });

    // Utan en stabil tie-break hoppar rader runt mellan omritningar när flera
    // delar sorteringsnyckel — listan uppdateras var tionde sekund.
    test('lika sorteringsnyckel faller tillbaka på IP', () {
      final same = [
        row('samma', '10.9.9.20', 'aa:aa:aa:aa:aa:aa'),
        row('samma', '10.9.9.3', 'bb:bb:bb:bb:bb:bb'),
      ];
      expect(ipsOf(sortReservations(same, 0, true, never)), ['10.9.9.3', '10.9.9.20']);
    });

    test('originallistan lämnas orörd', () {
      final original = List.of(rows);
      sortReservations(rows, 1, true, never);
      expect(ipsOf(rows), ipsOf(original));
    });
  });
}
