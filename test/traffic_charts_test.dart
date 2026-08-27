import 'package:flutter_test/flutter_test.dart';
import 'package:security_harbor_gui/widgets/traffic_charts.dart';

void main() {
  group('buildSlices', () {
    test('slår ihop allt bortom topp N till Övriga', () {
      // 15 enheter, topp 10 ska visas var för sig och de 5 sista slås ihop.
      final items = List.generate(15, (i) => (label: 'dev$i', value: (15 - i) * 10));
      final slices = buildSlices(items, otherLabel: 'Övriga');

      expect(slices.length, 11, reason: '10 enheter + en Övriga-skiva');
      expect(slices.last.label, 'Övriga');
      // De fem sista: 5*10 + 4*10 + 3*10 + 2*10 + 1*10 = 150
      expect(slices.last.value, 150);
      expect(slices.last.color, kPieOtherColor,
          reason: 'Övriga ska ha egen färg så den inte förväxlas med en enhet');
    });

    test('sorterar störst först oavsett inordning', () {
      final slices = buildSlices([
        (label: 'liten', value: 1),
        (label: 'stor', value: 100),
        (label: 'mellan', value: 50),
      ]);
      expect(slices.map((s) => s.label).toList(), ['stor', 'mellan', 'liten']);
    });

    test('utelämnar enheter utan trafik', () {
      // En enhet som inte skickat något ska inte ta plats i legenden.
      final slices = buildSlices([
        (label: 'aktiv', value: 10),
        (label: 'tyst', value: 0),
      ]);
      expect(slices.length, 1);
      expect(slices.first.label, 'aktiv');
    });

    test('ingen Övriga-skiva när allt får plats', () {
      final slices = buildSlices([(label: 'a', value: 5), (label: 'b', value: 3)]);
      expect(slices.length, 2);
      expect(slices.any((s) => s.label == 'Övriga'), isFalse);
    });

    test('tom lista ger inga skivor', () {
      expect(buildSlices([]), isEmpty);
    });
  });

  group('formatering', () {
    test('byte skalas binärt', () {
      expect(formatBytes(512), '512 B');
      expect(formatBytes(2048), '2.0 kB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes(3 * 1024 * 1024 * 1024), '3.0 GB');
    });

    test('bandbredd anges i bit per sekund, inte byte', () {
      // Detta är den klassiska faktor-8-förväxlingen: anslutningar säljs i
      // bit/s medan räknarna är i byte.
      expect(formatBps(125), '1.0 kbit/s');
      expect(formatBps(1250000), '10.0 Mbit/s');
      expect(formatBps(0), '0 bps');
    });
  });
}
