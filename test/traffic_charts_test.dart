import 'dart:ui';

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
      // Enheten skrivs likadant på alla steg — 'bit/s', aldrig 'bps'.
      expect(formatBps(0), '0 bit/s');
    });
  });

  group('sliceIndexAt', () {
    // Fyra lika stora skivor: uppe till höger, nere till höger, nere till
    // vänster, uppe till vänster — i den ordningen, medurs från klockan tolv.
    final quarters = [
      const PieSlice('a', 25, Color(0xFF000001)),
      const PieSlice('b', 25, Color(0xFF000002)),
      const PieSlice('c', 25, Color(0xFF000003)),
      const PieSlice('d', 25, Color(0xFF000004)),
    ];
    const size = 100.0;
    const c = 50.0;

    test('börjar i klockan tolv, inte klockan tre', () {
      // Rakt uppåt från mitten, ute i ringen.
      expect(sliceIndexAt(quarters, const Offset(c, 5), size), 0);
      // Rakt åt höger = andra skivan när man börjar i tolv.
      expect(sliceIndexAt(quarters, const Offset(95, c), size), 1);
      expect(sliceIndexAt(quarters, const Offset(c, 95), size), 2);
      expect(sliceIndexAt(quarters, const Offset(5, c), size), 3);
    });

    test('mitthålet är inte träffbart', () {
      expect(sliceIndexAt(quarters, const Offset(c, c), size), -1);
    });

    test('utanför cirkeln är inte träffbart', () {
      // Hörnet ligger innanför widgetens kvadrat men utanför ringen.
      expect(sliceIndexAt(quarters, const Offset(0, 0), size), -1);
    });

    test('tomt diagram ger -1', () {
      expect(sliceIndexAt([], const Offset(c, 5), size), -1);
      expect(sliceIndexAt([const PieSlice('x', 0, Color(0xFF000005))], const Offset(c, 5), size), -1);
    });

    test('olika stora skivor delas i rätt proportion', () {
      final uneven = [
        const PieSlice('stor', 75, Color(0xFF000001)),
        const PieSlice('liten', 25, Color(0xFF000002)),
      ];
      // Tre fjärdedelar medurs från tolv: uppe, höger och nere tillhör den stora.
      expect(sliceIndexAt(uneven, const Offset(c, 5), size), 0);
      expect(sliceIndexAt(uneven, const Offset(95, c), size), 0);
      expect(sliceIndexAt(uneven, const Offset(c, 95), size), 0);
      // Vänstra kvarten är den lilla.
      expect(sliceIndexAt(uneven, const Offset(5, c), size), 1);
    });
  });
}
