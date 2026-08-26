import 'package:flutter_test/flutter_test.dart';

/// Speglar _classifyDirection i connections_screen.dart. Logiken är privat
/// där, men den är för lätt att få fel för att lämnas otestad — den
/// hårdkodade zonnamnet "LAN" och klassade all VLAN-trafik mot internet som
/// intern.
String classify(String inZone, String outZone) {
  if (inZone.toUpperCase() == 'WAN') return 'IN';
  if (outZone.toUpperCase() == 'WAN') return 'OUT';
  return 'INTERNAL';
}

void main() {
  test('trafik in från internet', () {
    expect(classify('WAN', 'LAN'), 'IN');
    expect(classify('WAN', 'VLAN 9'), 'IN');
    expect(classify('WAN', ''), 'IN');
  });

  test('trafik ut mot internet — oavsett vad den interna zonen heter', () {
    expect(classify('LAN', 'WAN'), 'OUT');
    expect(classify('VLAN 9', 'WAN'), 'OUT');
    expect(classify('VLAN 1337', 'WAN'), 'OUT');
    expect(classify('VLAN 1000 DMZ', 'WAN'), 'OUT');
  });

  test('trafik mellan interna nät', () {
    expect(classify('LAN', 'VLAN 9'), 'INTERNAL');
    expect(classify('VLAN 9', 'VLAN 8'), 'INTERNAL');
    expect(classify('LAN', ''), 'INTERNAL', reason: 'till brandväggen själv');
  });

  test('zonnamnets skiftläge spelar ingen roll', () {
    expect(classify('vlan 9', 'wan'), 'OUT');
    expect(classify('wan', 'lan'), 'IN');
  });
}
