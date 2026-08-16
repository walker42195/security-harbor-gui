import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

const List<Map<String, String>> predefinedServices = [
  {'label': 'Alla Tjänster (ANY)', 'value': 'ANY'},
  {'label': 'HTTP (TCP 80)', 'value': 'HTTP'},
  {'label': 'HTTPS (TCP 443)', 'value': 'HTTPS'},
  {'label': 'SSH (TCP 22)', 'value': 'SSH'},
  {'label': 'DNS (UDP 53)', 'value': 'DNS'},
  {'label': 'RDP (TCP 3389)', 'value': 'RDP'},
  {'label': 'ICMP (Ping / Traceroute)', 'value': 'ICMP'},
  {'label': 'Anpassad Port / Tjänst', 'value': 'CUSTOM'},
];

class PoliciesScreen extends StatelessWidget {
  const PoliciesScreen({super.key});

  List<DropdownMenuItem<String>> _getZoneDropdownItems(ConfigModel? cfg) {
    final Map<String, String> itemsMap = {
      'ANY': 'Alla Zoner (ANY)',
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
    if (['ANY', 'LAN', 'WAN', 'SERVERS', 'IOT', 'GUEST', 'VPN'].contains(zone)) return true;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Brandväggspolicyer & NAT-regler',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.input),
                    label: const Text('+ Port Forwarding (DNAT)'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155), foregroundColor: Colors.white),
                    onPressed: () => _showAddDNATDialog(context, provider),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('+ Ny Regel'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                    onPressed: () => _showAddPolicyDialog(context, provider),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (cfg != null && cfg.policies.isEmpty)
            const Card(
              color: Color(0xFF1E293B),
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'Inga brandväggsregler konfigurerade ännu. Default Deny gäller mellan zoner.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else if (cfg != null)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cfg.policies.length,
              itemBuilder: (context, idx) {
                final pol = cfg.policies[idx];
                final isDNAT = pol.action == 'dnat';
                final isAllow = pol.action == 'accept';

                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDNAT
                          ? Colors.lightBlueAccent.withValues(alpha: 0.2)
                          : isAllow
                              ? Colors.tealAccent.withValues(alpha: 0.2)
                              : Colors.redAccent.withValues(alpha: 0.2),
                      child: Icon(
                        isDNAT
                            ? Icons.input
                            : isAllow
                                ? Icons.check_circle
                                : Icons.block,
                        color: isDNAT
                            ? Colors.lightBlueAccent
                            : isAllow
                                ? Colors.tealAccent
                                : Colors.redAccent,
                      ),
                    ),
                    title: Text(
                      pol.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(isDNAT && pol.nat != null
                        ? 'DNAT: WAN Port ${pol.nat!.externalPort}  ➔  ${pol.nat!.internalIp}:${pol.nat!.internalPort} (${pol.nat!.protocol.toUpperCase()})'
                        : 'Från: ${pol.sourceZone}  ➔  Till: ${pol.destZone}  |  Tjänst: ${pol.service}  |  Åtgärd: ${pol.action.toUpperCase()}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.cyanAccent, size: 20),
                          tooltip: 'Redigera Policy',
                          onPressed: () => _showEditPolicyDialog(context, provider, cfg, idx),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          tooltip: 'Ta bort Policy',
                          onPressed: () => _deletePolicy(provider, cfg, idx),
                        ),
                        Switch(
                          value: pol.enabled,
                          activeThumbColor: Colors.tealAccent,
                          onChanged: (val) {
                            _togglePolicy(provider, cfg, idx, val);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _deletePolicy(ConfigProvider provider, ConfigModel cfg, int idx) {
    final updatedPolicies = List<PolicyModel>.from(cfg.policies)..removeAt(idx);
    provider.updateCandidate(ConfigModel(
      version: cfg.version,
      revision: cfg.revision,
      updatedAt: cfg.updatedAt,
      interfaces: cfg.interfaces,
      zones: cfg.zones,
      objects: cfg.objects,
      services: cfg.services,
      policies: updatedPolicies,
      settings: cfg.settings,
    ));
  }

  void _togglePolicy(ConfigProvider provider, ConfigModel cfg, int idx, bool enabled) {
    final updatedPolicies = List<PolicyModel>.from(cfg.policies);
    final cur = updatedPolicies[idx];
    updatedPolicies[idx] = PolicyModel(
      id: cur.id,
      name: cur.name,
      enabled: enabled,
      priority: cur.priority,
      sourceZone: cur.sourceZone,
      destZone: cur.destZone,
      sourceObj: cur.sourceObj,
      destObj: cur.destObj,
      service: cur.service,
      action: cur.action,
      nat: cur.nat,
      logging: cur.logging,
      description: cur.description,
    );
    provider.updateCandidate(ConfigModel(
      version: cfg.version,
      revision: cfg.revision,
      updatedAt: cfg.updatedAt,
      interfaces: cfg.interfaces,
      zones: cfg.zones,
      objects: cfg.objects,
      services: cfg.services,
      policies: updatedPolicies,
      settings: cfg.settings,
    ));
  }

  void _showEditPolicyDialog(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx) {
    final pol = cfg.policies[idx];

    final nameCtrl = TextEditingController(text: pol.name);
    
    String selectedSrcZonePreset = pol.sourceZone.isEmpty ? 'ANY' : pol.sourceZone.toUpperCase();
    final customSrcZoneCtrl = TextEditingController(text: pol.sourceZone);

    String selectedDstZonePreset = pol.destZone.isEmpty ? 'ANY' : pol.destZone.toUpperCase();
    final customDstZoneCtrl = TextEditingController(text: pol.destZone);

    // Tjänste-hantering
    String selectedServicePreset = 'ANY';
    final customServiceCtrl = TextEditingController(text: pol.service);
    
    if (['ANY', 'HTTP', 'HTTPS', 'SSH', 'DNS', 'RDP', 'ICMP'].contains(pol.service.toUpperCase())) {
      selectedServicePreset = pol.service.toUpperCase();
    } else {
      selectedServicePreset = 'CUSTOM';
    }

    String selectedAction = pol.action;

    // DNAT parametrar
    final extPortCtrl = TextEditingController(text: pol.nat?.externalPort.toString() ?? '443');
    final intIpCtrl = TextEditingController(text: pol.nat?.internalIp ?? '192.168.10.10');
    final intPortCtrl = TextEditingController(text: pol.nat?.internalPort.toString() ?? '443');
    final protoCtrl = TextEditingController(text: pol.nat?.protocol ?? 'tcp');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Redigera Policy: ${pol.name}', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Policynamn')),
                const SizedBox(height: 12),
                const Text('Åtgärd (Action):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'accept', label: Text('Tillåt'), icon: Icon(Icons.check_circle, color: Colors.tealAccent)),
                    ButtonSegment(value: 'drop', label: Text('Neka'), icon: Icon(Icons.block, color: Colors.redAccent)),
                    ButtonSegment(value: 'dnat', label: Text('DNAT'), icon: Icon(Icons.input, color: Colors.lightBlueAccent)),
                  ],
                  selected: {selectedAction},
                  onSelectionChanged: (val) => setState(() => selectedAction = val.first),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _zoneExistsInMenu(selectedSrcZonePreset, cfg) ? selectedSrcZonePreset : 'CUSTOM',
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Källzon (Source Zone)'),
                  items: _getZoneDropdownItems(cfg),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedSrcZonePreset = val);
                  },
                ),
                if (selectedSrcZonePreset == 'CUSTOM')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextField(
                      controller: customSrcZoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Skapa ny Källzon',
                        hintText: 't.ex. DMZ, MANAGEMENT',
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _zoneExistsInMenu(selectedDstZonePreset, cfg) ? selectedDstZonePreset : 'CUSTOM',
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Målzon (Dest Zone)'),
                  items: _getZoneDropdownItems(cfg),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedDstZonePreset = val);
                  },
                ),
                if (selectedDstZonePreset == 'CUSTOM')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextField(
                      controller: customDstZoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Skapa ny Målzon',
                        hintText: 't.ex. DMZ, SERVERS',
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedServicePreset,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Tjänst / Protokoll'),
                  items: predefinedServices
                      .map((s) => DropdownMenuItem(value: s['value']!, child: Text(s['label']!)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => selectedServicePreset = val);
                    }
                  },
                ),
                if (selectedServicePreset == 'CUSTOM')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextField(
                      controller: customServiceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Anpassad Tjänst / Portnummer',
                        hintText: 't.ex. 8080 eller TCP 8080',
                      ),
                    ),
                  ),
                if (selectedAction == 'dnat') ...[
                  const Divider(color: Colors.white10, height: 24),
                  const Text('Port Forwarding (DNAT) Parametrar:', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  TextField(controller: extPortCtrl, decoration: const InputDecoration(labelText: 'Extern Port på WAN (t.ex. 443)')),
                  TextField(controller: intIpCtrl, decoration: const InputDecoration(labelText: 'Intern Mål-IP (t.ex. 192.168.10.10)')),
                  TextField(controller: intPortCtrl, decoration: const InputDecoration(labelText: 'Intern Målport (t.ex. 443)')),
                  TextField(controller: protoCtrl, decoration: const InputDecoration(labelText: 'Protokoll (tcp/udp)')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
            ElevatedButton(
              child: const Text('Spara Ändringar'),
              onPressed: () {
                NATConfigModel? updatedNAT;
                if (selectedAction == 'dnat') {
                  updatedNAT = NATConfigModel(
                    externalPort: int.tryParse(extPortCtrl.text) ?? 443,
                    internalIp: intIpCtrl.text,
                    internalPort: int.tryParse(intPortCtrl.text) ?? 443,
                    protocol: protoCtrl.text,
                  );
                }

                final finalService = selectedServicePreset == 'CUSTOM'
                    ? customServiceCtrl.text.toUpperCase()
                    : selectedServicePreset;

                final finalSrcZone = selectedSrcZonePreset == 'CUSTOM'
                    ? customSrcZoneCtrl.text.trim().toUpperCase()
                    : selectedSrcZonePreset;

                final finalDstZone = selectedDstZonePreset == 'CUSTOM'
                    ? customDstZoneCtrl.text.trim().toUpperCase()
                    : selectedDstZonePreset;

                // Spara nya zoner i zones listan
                final updatedZones = List<ZoneModel>.from(cfg.zones);
                if (finalSrcZone.isNotEmpty && finalSrcZone != 'ANY' && !updatedZones.any((z) => z.name.toUpperCase() == finalSrcZone)) {
                  updatedZones.add(ZoneModel(name: finalSrcZone, description: 'Egen skapad zon'));
                }
                if (finalDstZone.isNotEmpty && finalDstZone != 'ANY' && !updatedZones.any((z) => z.name.toUpperCase() == finalDstZone)) {
                  updatedZones.add(ZoneModel(name: finalDstZone, description: 'Egen skapad zon'));
                }

                final updatedPolicies = List<PolicyModel>.from(cfg.policies);
                updatedPolicies[idx] = PolicyModel(
                  id: pol.id,
                  name: nameCtrl.text,
                  enabled: pol.enabled,
                  priority: pol.priority,
                  sourceZone: finalSrcZone,
                  destZone: finalDstZone,
                  sourceObj: pol.sourceObj,
                  destObj: pol.destObj,
                  service: finalService,
                  action: selectedAction,
                  nat: updatedNAT,
                  logging: pol.logging,
                  description: pol.description,
                );

                provider.updateCandidate(ConfigModel(
                  version: cfg.version,
                  revision: cfg.revision,
                  updatedAt: cfg.updatedAt,
                  interfaces: cfg.interfaces,
                  zones: updatedZones,
                  objects: cfg.objects,
                  services: cfg.services,
                  policies: updatedPolicies,
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

  void _showAddDNATDialog(BuildContext context, ConfigProvider provider) {
    final nameCtrl = TextEditingController(text: 'Web Server HTTPS Forward');
    final extPortCtrl = TextEditingController(text: '443');
    final intIpCtrl = TextEditingController(text: '192.168.10.10');
    final intPortCtrl = TextEditingController(text: '443');
    final protoCtrl = TextEditingController(text: 'tcp');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Skapa Port Forwarding (DNAT)', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Regel-namn')),
            TextField(controller: extPortCtrl, decoration: const InputDecoration(labelText: 'Extern Port på WAN (t.ex. 443)')),
            TextField(controller: intIpCtrl, decoration: const InputDecoration(labelText: 'Intern Mål-IP (t.ex. 192.168.10.10)')),
            TextField(controller: intPortCtrl, decoration: const InputDecoration(labelText: 'Intern Målport (t.ex. 443)')),
            TextField(controller: protoCtrl, decoration: const InputDecoration(labelText: 'Protokoll (tcp/udp)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
          ElevatedButton(
            child: const Text('Spara Port Forwarding'),
            onPressed: () {
              final cfg = provider.candidateConfig ?? provider.runningConfig;
              if (cfg != null) {
                final extP = int.tryParse(extPortCtrl.text) ?? 443;
                final intP = int.tryParse(intPortCtrl.text) ?? 443;
                final newPol = PolicyModel(
                  id: 'dnat_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text,
                  enabled: true,
                  sourceZone: 'WAN',
                  destZone: 'LAN',
                  sourceObj: 'ANY',
                  destObj: 'ANY',
                  service: protoCtrl.text.toUpperCase(),
                  action: 'dnat',
                  nat: NATConfigModel(
                    externalPort: extP,
                    internalIp: intIpCtrl.text,
                    internalPort: intP,
                    protocol: protoCtrl.text,
                  ),
                );
                final updated = List<PolicyModel>.from(cfg.policies)..add(newPol);
                provider.updateCandidate(ConfigModel(
                  version: cfg.version,
                  revision: cfg.revision,
                  updatedAt: cfg.updatedAt,
                  interfaces: cfg.interfaces,
                  zones: cfg.zones,
                  objects: cfg.objects,
                  services: cfg.services,
                  policies: updated,
                  settings: cfg.settings,
                ));
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showAddPolicyDialog(BuildContext context, ConfigProvider provider) {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    final nameCtrl = TextEditingController(text: 'Tillåt LAN till SERVERS');
    
    String selectedSrcZonePreset = 'LAN';
    final customSrcZoneCtrl = TextEditingController(text: 'DMZ');

    String selectedDstZonePreset = 'SERVERS';
    final customDstZoneCtrl = TextEditingController(text: 'SERVERS');

    String selectedServicePreset = 'ANY';
    final customServiceCtrl = TextEditingController(text: '8080');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Skapa Brandväggspolicy', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Policynamn')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedSrcZonePreset,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Källzon (Source Zone)'),
                  items: _getZoneDropdownItems(cfg),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedSrcZonePreset = val);
                  },
                ),
                if (selectedSrcZonePreset == 'CUSTOM')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextField(
                      controller: customSrcZoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Skapa ny Källzon',
                        hintText: 't.ex. DMZ, MANAGEMENT',
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedDstZonePreset,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Målzon (Dest Zone)'),
                  items: _getZoneDropdownItems(cfg),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedDstZonePreset = val);
                  },
                ),
                if (selectedDstZonePreset == 'CUSTOM')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextField(
                      controller: customDstZoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Skapa ny Målzon',
                        hintText: 't.ex. DMZ, SERVERS',
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedServicePreset,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Tjänst / Protokoll'),
                  items: predefinedServices
                      .map((s) => DropdownMenuItem(value: s['value']!, child: Text(s['label']!)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => selectedServicePreset = val);
                    }
                  },
                ),
                if (selectedServicePreset == 'CUSTOM')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextField(
                      controller: customServiceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Anpassad Tjänst / Portnummer',
                        hintText: 't.ex. 8080 eller TCP 8080',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
            ElevatedButton(
              child: const Text('Spara Policy'),
              onPressed: () {
                if (cfg != null) {
                  final finalService = selectedServicePreset == 'CUSTOM'
                      ? customServiceCtrl.text.toUpperCase()
                      : selectedServicePreset;

                  final finalSrcZone = selectedSrcZonePreset == 'CUSTOM'
                      ? customSrcZoneCtrl.text.trim().toUpperCase()
                      : selectedSrcZonePreset;

                  final finalDstZone = selectedDstZonePreset == 'CUSTOM'
                      ? customDstZoneCtrl.text.trim().toUpperCase()
                      : selectedDstZonePreset;

                  final updatedZones = List<ZoneModel>.from(cfg.zones);
                  if (finalSrcZone.isNotEmpty && finalSrcZone != 'ANY' && !updatedZones.any((z) => z.name.toUpperCase() == finalSrcZone)) {
                    updatedZones.add(ZoneModel(name: finalSrcZone, description: 'Egen skapad zon'));
                  }
                  if (finalDstZone.isNotEmpty && finalDstZone != 'ANY' && !updatedZones.any((z) => z.name.toUpperCase() == finalDstZone)) {
                    updatedZones.add(ZoneModel(name: finalDstZone, description: 'Egen skapad zon'));
                  }

                  final newPol = PolicyModel(
                    id: 'pol_${DateTime.now().millisecondsSinceEpoch}',
                    name: nameCtrl.text,
                    enabled: true,
                    sourceZone: finalSrcZone,
                    destZone: finalDstZone,
                    sourceObj: 'ANY',
                    destObj: 'ANY',
                    service: finalService,
                    action: 'accept',
                  );
                  final updated = List<PolicyModel>.from(cfg.policies)..add(newPol);
                  provider.updateCandidate(ConfigModel(
                    version: cfg.version,
                    revision: cfg.revision,
                    updatedAt: cfg.updatedAt,
                    interfaces: cfg.interfaces,
                    zones: updatedZones,
                    objects: cfg.objects,
                    services: cfg.services,
                    policies: updated,
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
}
