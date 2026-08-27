import 'package:flutter_test/flutter_test.dart';
import 'package:security_harbor_gui/models/config_model.dart';

void main() {
  group('DeviceStatModel.displayName', () {
    test('använder DNS-namnet när det finns', () {
      final d = DeviceStatModel(ip: '10.0.0.5', hostname: 'skrivare', vendor: 'HP Inc.');
      expect(d.displayName, 'skrivare');
    });

    test('faller tillbaka på IP, ALDRIG på tillverkaren', () {
      // Tillverkaren har en egen kolumn. Används den som reserv i namnet ser
      // fyra olika Proxmox-maskiner identiska ut i både tabell och diagram.
      final d = DeviceStatModel(ip: '10.13.13.14', vendor: 'Proxmox Server Solutions GmbH');
      expect(d.displayName, '10.13.13.14');
      expect(d.displayName, isNot(contains('Proxmox')));
    });

    test('två enheter från samma tillverkare får skilda namn', () {
      final a = DeviceStatModel(ip: '10.13.13.14', vendor: 'Proxmox Server Solutions GmbH');
      final b = DeviceStatModel(ip: '10.0.0.45', vendor: 'Proxmox Server Solutions GmbH');
      expect(a.displayName, isNot(b.displayName));
    });

    test('utan både namn och tillverkare blir det IP', () {
      expect(DeviceStatModel(ip: '10.0.0.9').displayName, '10.0.0.9');
    });
  });
}
