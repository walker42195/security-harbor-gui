import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

const List<Map<String, String>> predefinedInterfaceZones = [
  {'label': 'LAN (Internt nätverk)', 'value': 'LAN'},
  {'label': 'WAN (Utsida / Internet)', 'value': 'WAN'},
  {'label': 'SERVERS (Serverzon)', 'value': 'SERVERS'},
  {'label': 'IOT (IoT-enheter)', 'value': 'IOT'},
  {'label': 'GUEST (Gästnätverk)', 'value': 'GUEST'},
  {'label': 'VPN (VPN-klienter)', 'value': 'VPN'},
];

class InterfacesScreen extends StatelessWidget {
  const InterfacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final cfg = provider.candidateConfig ?? provider.runningConfig;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nätverksgränssnitt & VLAN',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.alt_route),
                    label: const Text('+ Skapa VLAN'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                    onPressed: () => _showAddVLANDialog(context, provider),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (cfg != null && cfg.interfaces.isEmpty)
            const Card(
              color: Color(0xFF1E293B),
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('Inga konfigurerade gränssnitt ännu.', style: TextStyle(color: Colors.grey))),
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
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: Icon(
                      isVLAN ? Icons.alt_route : Icons.router,
                      color: isWAN ? Colors.redAccent : Colors.tealAccent,
                    ),
                    title: Text(
                      '${iface.id} (${iface.device})${isVLAN ? " [VLAN ${iface.vlanId}]" : ""}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Zon: ${iface.zone}  |  Typ: ${isStatic ? "Statisk IP (${iface.ipv4})" : "DHCP-Klient"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.cyanAccent, size: 20),
                          tooltip: 'Redigera gränssnitt',
                          onPressed: () => _showEditInterfaceDialog(context, provider, cfg, idx),
                        ),
                        Switch(
                          value: iface.enabled,
                          activeThumbColor: Colors.tealAccent,
                          onChanged: (val) {
                            _toggleInterface(provider, cfg, idx, val);
                          },
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  label: Text('Adressering: ${isStatic ? "STATISK IP" : "DHCP-KLIENT"}'),
                                  backgroundColor: isStatic ? Colors.lightBlueAccent.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2),
                                  labelStyle: TextStyle(color: isStatic ? Colors.lightBlueAccent : Colors.amber, fontWeight: FontWeight.bold),
                                ),
                                if (iface.gateway.isNotEmpty)
                                  Chip(
                                    label: Text('Gateway: ${iface.gateway}'),
                                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                    labelStyle: const TextStyle(color: Colors.white),
                                  ),
                                if (iface.dnsServers.isNotEmpty)
                                  Chip(
                                    label: Text('DNS: ${iface.dnsServers.join(", ")}'),
                                    backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                                    labelStyle: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (isWAN) ...[
                              Row(
                                children: const [
                                  Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'WAN-gränssnitt: Kan köras som DHCP-klient eller Statisk IP med valfria DNS-servrar.',
                                      style: TextStyle(color: Colors.amber),
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
                                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.settings_ethernet, size: 16),
                                    label: const Text('Konfigurera DHCP Scope'),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155), foregroundColor: Colors.white),
                                    onPressed: () => _showDHCPDialog(context, provider, cfg, idx),
                                  ),
                                ],
                              ),
                              if (iface.dhcp != null && iface.dhcp!.enabled) ...[
                                const SizedBox(height: 8),
                                Text('IP Pool: ${iface.dhcp!.rangeStart} - ${iface.dhcp!.rangeEnd}', style: const TextStyle(color: Colors.grey)),
                                Text('Klient DNS: ${iface.dhcp!.dnsServers.join(", ")}  |  Gateway: ${iface.dhcp!.gateway}', style: const TextStyle(color: Colors.grey)),
                                Text('Statiska Reservationer: ${iface.dhcp!.reservations.length} enheter', style: const TextStyle(color: Colors.grey)),
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
    );
  }

  void _showEditInterfaceDialog(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx) {
    final iface = cfg.interfaces[idx];
    String selectedType = iface.addressType;
    final ipCtrl = TextEditingController(text: iface.ipv4);
    final gwCtrl = TextEditingController(text: iface.gateway);
    final dnsCtrl = TextEditingController(text: iface.dnsServers.join(', '));
    String selectedZone = iface.zone.isEmpty ? 'LAN' : iface.zone.toUpperCase();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Redigera ${iface.id} (${iface.device})', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Adresseringstyp:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'static', label: Text('Statisk IP'), icon: Icon(Icons.pin)),
                    ButtonSegment(value: 'dhcp', label: Text('DHCP Klient'), icon: Icon(Icons.sync)),
                  ],
                  selected: {selectedType},
                  onSelectionChanged: (val) => setState(() => selectedType = val.first),
                ),
                const SizedBox(height: 16),
                if (selectedType == 'static')
                  TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'IPv4 / CIDR (t.ex. 10.0.0.163/24)')),
                TextField(controller: gwCtrl, decoration: const InputDecoration(labelText: 'Default Gateway IP (Valfri)')),
                TextField(controller: dnsCtrl, decoration: const InputDecoration(labelText: 'DNS-servrar (komma-separerade, t.ex. 1.1.1.1, 8.8.8.8)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedZone,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Tilldelad Zon'),
                  items: predefinedInterfaceZones
                      .map((z) => DropdownMenuItem(value: z['value']!, child: Text(z['label']!)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedZone = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
            ElevatedButton(
              child: const Text('Spara Ändringar'),
              onPressed: () {
                final dnsList = dnsCtrl.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();

                final updated = List<InterfaceModel>.from(cfg.interfaces);
                updated[idx] = InterfaceModel(
                  id: iface.id,
                  device: iface.device,
                  parent: iface.parent,
                  vlanId: iface.vlanId,
                  zone: selectedZone,
                  enabled: iface.enabled,
                  addressType: selectedType,
                  ipv4: selectedType == 'static' ? ipCtrl.text : '',
                  gateway: gwCtrl.text,
                  dnsServers: dnsList,
                  mtu: iface.mtu,
                  dhcp: iface.dhcp,
                );
                provider.updateCandidate(ConfigModel(
                  version: cfg.version,
                  revision: cfg.revision,
                  updatedAt: cfg.updatedAt,
                  interfaces: updated,
                  zones: cfg.zones,
                  objects: cfg.objects,
                  services: cfg.services,
                  policies: cfg.policies,
                  settings: cfg.settings,
                ));
                Navigator.pop(ctx);
              },
            ),
          ],
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
    provider.updateCandidate(ConfigModel(
      version: cfg.version,
      revision: cfg.revision,
      updatedAt: cfg.updatedAt,
      interfaces: updatedIfaces,
      zones: cfg.zones,
      objects: cfg.objects,
      services: cfg.services,
      policies: cfg.policies,
      settings: cfg.settings,
    ));
  }

  void _showAddVLANDialog(BuildContext context, ConfigProvider provider) {
    final parentCtrl = TextEditingController(text: 'ens19');
    final vlanIdCtrl = TextEditingController(text: '10');
    String selectedZone = 'SERVERS';
    final ipCtrl = TextEditingController(text: '192.168.10.1/24');
    final dnsCtrl = TextEditingController(text: '1.1.1.1, 8.8.8.8');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Skapa nytt Linux VLAN', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: parentCtrl, decoration: const InputDecoration(labelText: 'Föräldra-interface (Parent)')),
                TextField(controller: vlanIdCtrl, decoration: const InputDecoration(labelText: 'VLAN ID (1-4094)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedZone,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Tilldelad Zon'),
                  items: predefinedInterfaceZones
                      .map((z) => DropdownMenuItem(value: z['value']!, child: Text(z['label']!)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedZone = val);
                  },
                ),
                TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'Statisk IPv4/CIDR (t.ex. 192.168.10.1/24)')),
                TextField(controller: dnsCtrl, decoration: const InputDecoration(labelText: 'DNS Servrar (t.ex. 1.1.1.1, 8.8.8.8)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
            ElevatedButton(
              child: const Text('Skapa VLAN'),
              onPressed: () {
                final cfg = provider.candidateConfig ?? provider.runningConfig;
                if (cfg != null) {
                  final vlanId = int.tryParse(vlanIdCtrl.text) ?? 10;
                  final dev = '${parentCtrl.text}.$vlanId';
                  final dnsList = dnsCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  final newIface = InterfaceModel(
                    id: 'vlan$vlanId',
                    device: dev,
                    parent: parentCtrl.text,
                    vlanId: vlanId,
                    zone: selectedZone,
                    enabled: true,
                    addressType: 'static',
                    ipv4: ipCtrl.text,
                    dnsServers: dnsList,
                  );
                  final updated = List<InterfaceModel>.from(cfg.interfaces)..add(newIface);
                  provider.updateCandidate(ConfigModel(
                    version: cfg.version,
                    revision: cfg.revision,
                    updatedAt: cfg.updatedAt,
                    interfaces: updated,
                    zones: cfg.zones,
                    objects: cfg.objects,
                    services: cfg.services,
                    policies: cfg.policies,
                    settings: cfg.settings,
                  ));
                }
                Navigator.pop(ctx);
              },
            ),
          ],
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('DHCP-inställningar för ${iface.id}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start IP Pool')),
            TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'Slut IP Pool')),
            TextField(controller: gwCtrl, decoration: const InputDecoration(labelText: 'Standard Gateway')),
            TextField(controller: dnsCtrl, decoration: const InputDecoration(labelText: 'DNS Server (komma-separerade)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
          ElevatedButton(
            child: const Text('Spara DHCP Scope'),
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
              provider.updateCandidate(ConfigModel(
                version: cfg.version,
                revision: cfg.revision,
                updatedAt: cfg.updatedAt,
                interfaces: updated,
                zones: cfg.zones,
                objects: cfg.objects,
                services: cfg.services,
                policies: cfg.policies,
                settings: cfg.settings,
              ));
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
