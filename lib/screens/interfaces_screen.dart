import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../widgets/dialog_helpers.dart';

class InterfacesScreen extends StatelessWidget {
  const InterfacesScreen({super.key});

  List<DropdownMenuItem<String>> _getZoneDropdownItems(ConfigModel? cfg) {
    final Map<String, String> itemsMap = {
      'LAN': 'LAN (Internt nätverk)',
      'WAN': 'WAN (Utsida / Internet)',
      'SERVERS': 'SERVERS (Serverzon)',
      'IOT': 'IOT (IoT-enheter)',
      'GUEST': 'Gästnätverk (GUEST)',
      'VPN': 'VPN (VPN-klienter)',
    };

    if (cfg != null) {
      for (final z in cfg.zones) {
        final name = z.name.toUpperCase();
        if (!itemsMap.containsKey(name)) {
          itemsMap[name] = '$name (Egen zon)';
        }
      }
      for (final i in cfg.interfaces) {
        if (i.zone.isNotEmpty) {
          final name = i.zone.toUpperCase();
          if (!itemsMap.containsKey(name)) {
            itemsMap[name] = '$name (Aktiv zon)';
          }
        }
      }
    }

    final list = itemsMap.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList();

    list.add(const DropdownMenuItem(
      value: 'CUSTOM',
      child: Text('+ Skapa ny / Anpassad zon...', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
    ));

    return list;
  }

  bool _zoneExistsInMenu(String zone, ConfigModel? cfg) {
    if (['LAN', 'WAN', 'SERVERS', 'IOT', 'GUEST', 'VPN'].contains(zone)) return true;
    if (cfg != null) {
      if (cfg.zones.any((z) => z.name.toUpperCase() == zone)) return true;
      if (cfg.interfaces.any((i) => i.zone.toUpperCase() == zone)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final cfg = provider.candidateConfig ?? provider.runningConfig;

    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nätverksgränssnitt & VLAN',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.alt_route, size: 14),
                  label: const Text('+ Skapa VLAN', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => _showAddVLANDialog(context, provider),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (cfg != null && cfg.interfaces.isEmpty)
              const Card(
                color: Color(0xFF1E293B),
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('Inga konfigurerade gränssnitt ännu.', style: TextStyle(color: Colors.grey, fontSize: 11))),
                ),
              )
            else if (cfg != null)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cfg.interfaces.length,
                itemBuilder: (context, idx) {
                  final iface = cfg.interfaces[idx];
                  final isVLAN = iface.vlanId > 0;
                  final isWAN = iface.zone == 'WAN';
                  final isStatic = iface.addressType == 'static';

                  return Card(
                    color: const Color(0xFF1E293B),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      dense: true,
                      leading: Icon(
                        isVLAN ? Icons.alt_route : Icons.router,
                        size: 18,
                        color: isWAN ? Colors.redAccent : Colors.tealAccent,
                      ),
                      title: Text(
                        '${iface.id} (${iface.device})${isVLAN ? " [VLAN ${iface.vlanId}]" : ""}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Zon: ${iface.zone}  |  Typ: ${isStatic ? "Statisk IP (${iface.ipv4})" : "DHCP-Klient${iface.ipv4.isNotEmpty ? " (${iface.ipv4})" : ""}"}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.cyanAccent, size: 16),
                            tooltip: 'Redigera gränssnitt',
                            onPressed: () => _showEditInterfaceDialog(context, provider, cfg, idx),
                          ),
                          Switch(
                            value: iface.enabled,
                            activeThumbColor: Colors.tealAccent,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) {
                              _toggleInterface(provider, cfg, idx, val);
                            },
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  Chip(
                                    label: Text('Adressering: ${isStatic ? "STATISK IP" : "DHCP-KLIENT"}', style: TextStyle(color: isStatic ? Colors.lightBlueAccent : Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                    backgroundColor: isStatic ? Colors.lightBlueAccent.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (iface.ipv4.isNotEmpty)
                                    Chip(
                                      label: Text('${isWAN ? "Extern IP" : "IP"}: ${_cidrAddress(iface.ipv4)}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (iface.ipv4.contains('/'))
                                    Chip(
                                      label: Text('Subnät: ${iface.ipv4} (${_cidrNetmask(iface.ipv4)})', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (iface.gateway.isNotEmpty)
                                    Chip(
                                      label: Text('Gateway: ${iface.gateway}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (iface.dnsServers.isNotEmpty)
                                    Chip(
                                      label: Text('DNS: ${iface.dnsServers.join(", ")}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      backgroundColor: Colors.cyanAccent.withValues(alpha: 0.15),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (isWAN) ...[
                                Row(
                                  children: const [
                                    Icon(Icons.shield_outlined, color: Colors.amber, size: 16),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'WAN-gränssnitt: Kan köras som DHCP-klient eller Statisk IP med valfria DNS-servrar.',
                                        style: TextStyle(color: Colors.amber, fontSize: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'DHCP Server: ${iface.dhcp != null && iface.dhcp!.enabled ? "AKTIV" : "AVSTÄNGD"}',
                                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.settings_ethernet, size: 14),
                                      label: const Text('Konfigurera DHCP Scope', style: TextStyle(fontSize: 10)),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                      onPressed: () => _showDHCPDialog(context, provider, cfg, idx),
                                    ),
                                  ],
                                ),
                                if (iface.dhcp != null && iface.dhcp!.enabled) ...[
                                  const SizedBox(height: 4),
                                  Text('IP Pool: ${iface.dhcp!.rangeStart} - ${iface.dhcp!.rangeEnd}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                  Text('Klient DNS: ${iface.dhcp!.dnsServers.join(", ")}  |  Gateway: ${iface.dhcp!.gateway}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEditInterfaceDialog(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx) {
    final iface = cfg.interfaces[idx];
    String selectedType = iface.addressType;
    final ipCtrl = TextEditingController(text: iface.ipv4);
    final gwCtrl = TextEditingController(text: iface.gateway);
    final dnsCtrl = TextEditingController(text: iface.dnsServers.join(', '));
    
    String selectedZonePreset = iface.zone.isEmpty ? 'LAN' : iface.zone.toUpperCase();
    final customZoneCtrl = TextEditingController(text: _zoneExistsInMenu(selectedZonePreset, cfg) ? '' : iface.zone);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  dialogTitleRow(context, 'Redigera ${iface.id} (${iface.device})', () => Navigator.pop(ctx)),
                  const SizedBox(height: 12),

                  dialogSection(title: 'ADRESSERINGSTYP', children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'static', label: Text('Statisk IP', style: TextStyle(fontSize: 11)), icon: Icon(Icons.pin, size: 14)),
                        ButtonSegment(value: 'dhcp', label: Text('DHCP Klient', style: TextStyle(fontSize: 11)), icon: Icon(Icons.sync, size: 14)),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (val) => setState(() => selectedType = val.first),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  dialogSection(title: 'NÄTVERK', children: [
                    if (selectedType == 'static') ...[
                      dialogField(ipCtrl, 'IPv4 / CIDR', hint: 't.ex. 10.0.0.163/24'),
                      const SizedBox(height: 12),
                    ],
                    dialogField(gwCtrl, 'Default Gateway IP (Valfri)'),
                    const SizedBox(height: 12),
                    dialogField(dnsCtrl, 'DNS-servrar', hint: 't.ex. 1.1.1.1, 8.8.8.8'),
                  ]),
                  const SizedBox(height: 12),

                  dialogSection(title: 'ZON', children: [
                    DropdownButtonFormField<String>(
                      initialValue: _zoneExistsInMenu(selectedZonePreset, cfg) ? selectedZonePreset : 'CUSTOM',
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Tilldelad Zon',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      items: _getZoneDropdownItems(cfg),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedZonePreset = val);
                      },
                    ),
                    if (selectedZonePreset == 'CUSTOM') ...[
                      const SizedBox(height: 12),
                      dialogField(customZoneCtrl, 'Ange nytt Zon-namn', hint: 't.ex. DMZ, MANAGEMENT, CAMERAS'),
                    ],
                  ]),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        child: const Text('Spara Ändringar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                final dnsList = dnsCtrl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                final finalZone = selectedZonePreset == 'CUSTOM'
                    ? customZoneCtrl.text.trim().toUpperCase()
                    : selectedZonePreset;

                final updatedZones = List<ZoneModel>.from(cfg.zones);
                if (finalZone.isNotEmpty && !updatedZones.any((z) => z.name.toUpperCase() == finalZone)) {
                  updatedZones.add(ZoneModel(
                    name: finalZone,
                    description: 'Egen skapad zon',
                  ));
                }

                final updated = List<InterfaceModel>.from(cfg.interfaces);
                updated[idx] = InterfaceModel(
                  id: iface.id,
                  device: iface.device,
                  parent: iface.parent,
                  vlanId: iface.vlanId,
                  zone: finalZone,
                  enabled: iface.enabled,
                  addressType: selectedType,
                  ipv4: selectedType == 'static' ? ipCtrl.text : '',
                  gateway: gwCtrl.text,
                  dnsServers: dnsList,
                  mtu: iface.mtu,
                  dhcp: iface.dhcp,
                );
                provider.updateCandidate(cfg.copyWith(
                  interfaces: updated,
                  zones: updatedZones,
                ));
                Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleInterface(ConfigProvider provider, ConfigModel cfg, int idx, bool enabled) {
    final updatedIfaces = List<InterfaceModel>.from(cfg.interfaces);
    final cur = updatedIfaces[idx];
    updatedIfaces[idx] = InterfaceModel(
      id: cur.id,
      device: cur.device,
      parent: cur.parent,
      vlanId: cur.vlanId,
      zone: cur.zone,
      enabled: enabled,
      addressType: cur.addressType,
      ipv4: cur.ipv4,
      gateway: cur.gateway,
      dnsServers: cur.dnsServers,
      mtu: cur.mtu,
      dhcp: cur.dhcp,
    );
    provider.updateCandidate(cfg.copyWith(
      interfaces: updatedIfaces,
    ));
  }

  void _showAddVLANDialog(BuildContext context, ConfigProvider provider) {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    final parentCtrl = TextEditingController(text: 'ens19');
    final vlanIdCtrl = TextEditingController(text: '10');
    String selectedZonePreset = 'SERVERS';
    final customZoneCtrl = TextEditingController(text: '');
    final ipCtrl = TextEditingController(text: '192.168.10.1/24');
    final dnsCtrl = TextEditingController(text: '1.1.1.1, 8.8.8.8');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Skapa nytt Linux VLAN', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  dialogSection(title: 'GRUNDUPPGIFTER', children: [
                    dialogField(parentCtrl, 'Föräldra-interface (parent)'),
                    const SizedBox(height: 12),
                    dialogField(vlanIdCtrl, 'VLAN ID (1-4094)'),
                  ]),
                  const SizedBox(height: 12),

                  dialogSection(title: 'ZON', children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedZonePreset,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Tilldelad zon',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                      items: _getZoneDropdownItems(cfg),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedZonePreset = val);
                      },
                    ),
                    if (selectedZonePreset == 'CUSTOM') ...[
                      const SizedBox(height: 12),
                      dialogField(customZoneCtrl, 'Ange nytt zon-namn', hint: 't.ex. DMZ, MANAGEMENT, CAMERAS'),
                    ],
                  ]),
                  const SizedBox(height: 12),

                  dialogSection(title: 'NÄTVERK', children: [
                    dialogField(ipCtrl, 'Statisk IPv4/CIDR', hint: 't.ex. 192.168.10.1/24'),
                    const SizedBox(height: 12),
                    dialogField(dnsCtrl, 'DNS-servrar', hint: 't.ex. 1.1.1.1, 8.8.8.8'),
                  ]),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        child: const Text('Skapa VLAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                if (cfg != null) {
                  final vlanId = int.tryParse(vlanIdCtrl.text) ?? 10;
                  final dev = '${parentCtrl.text}.$vlanId';
                  final dnsList = dnsCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  final finalZone = selectedZonePreset == 'CUSTOM'
                      ? customZoneCtrl.text.trim().toUpperCase()
                      : selectedZonePreset;

                  final updatedZones = List<ZoneModel>.from(cfg.zones);
                  if (finalZone.isNotEmpty && !updatedZones.any((z) => z.name.toUpperCase() == finalZone)) {
                    updatedZones.add(ZoneModel(
                      name: finalZone,
                      description: 'Egen skapad zon',
                    ));
                  }

                  final newIface = InterfaceModel(
                    id: 'vlan$vlanId',
                    device: dev,
                    parent: parentCtrl.text,
                    vlanId: vlanId,
                    zone: finalZone,
                    enabled: true,
                    addressType: 'static',
                    ipv4: ipCtrl.text,
                    dnsServers: dnsList,
                  );
                  final updated = List<InterfaceModel>.from(cfg.interfaces)..add(newIface);
                  provider.updateCandidate(cfg.copyWith(
                    interfaces: updated,
                    zones: updatedZones,
                  ));
                }
                Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDHCPDialog(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx) {
    final iface = cfg.interfaces[idx];
    final dhcp = iface.dhcp;

    final startCtrl = TextEditingController(text: dhcp?.rangeStart ?? '192.168.10.100');
    final endCtrl = TextEditingController(text: dhcp?.rangeEnd ?? '192.168.10.200');
    final gwCtrl = TextEditingController(text: dhcp?.gateway ?? '192.168.10.1');
    final dnsCtrl = TextEditingController(text: dhcp != null && dhcp.dnsServers.isNotEmpty ? dhcp.dnsServers.join(', ') : '192.168.10.1, 1.1.1.1');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('DHCP-inställningar för ${iface.id}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              dialogSection(title: 'IP-POOL', children: [
                dialogField(startCtrl, 'Start IP pool'),
                const SizedBox(height: 12),
                dialogField(endCtrl, 'Slut IP pool'),
              ]),
              const SizedBox(height: 12),

              dialogSection(title: 'NÄTVERK', children: [
                dialogField(gwCtrl, 'Standard gateway'),
                const SizedBox(height: 12),
                dialogField(dnsCtrl, 'DNS-servrar', hint: 'komma-separerade'),
              ]),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    child: const Text('Spara DHCP Scope', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
              final newDHCP = DHCPConfigModel(
                enabled: true,
                rangeStart: startCtrl.text,
                rangeEnd: endCtrl.text,
                gateway: gwCtrl.text,
                dnsServers: dnsCtrl.text.split(',').map((e) => e.trim()).toList(),
                reservations: dhcp?.reservations ?? [],
              );
              final updated = List<InterfaceModel>.from(cfg.interfaces);
              updated[idx] = InterfaceModel(
                id: iface.id,
                device: iface.device,
                parent: iface.parent,
                vlanId: iface.vlanId,
                zone: iface.zone,
                enabled: iface.enabled,
                addressType: iface.addressType,
                ipv4: iface.ipv4,
                gateway: iface.gateway,
                dnsServers: iface.dnsServers,
                mtu: iface.mtu,
                dhcp: newDHCP,
              );
              provider.updateCandidate(cfg.copyWith(
                interfaces: updated,
              ));
              Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Adressen ur ett "x.x.x.x/yy"-CIDR-uttryck, utan prefixlängden.
  String _cidrAddress(String cidr) => cidr.split('/').first;

  /// Nätmasken (t.ex. "255.255.255.0") som motsvarar CIDR-prefixlängden
  /// i ett "x.x.x.x/yy"-uttryck. Returnerar tom sträng om formatet inte
  /// kan tolkas.
  String _cidrNetmask(String cidr) {
    final parts = cidr.split('/');
    if (parts.length != 2) return '';
    final prefix = int.tryParse(parts[1]);
    if (prefix == null || prefix < 0 || prefix > 32) return '';
    final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    return [24, 16, 8, 0].map((shift) => (mask >> shift) & 0xFF).join('.');
  }
}
