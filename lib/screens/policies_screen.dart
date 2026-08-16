import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

class PoliciesScreen extends StatelessWidget {
  const PoliciesScreen({super.key});

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
    final srcZoneCtrl = TextEditingController(text: pol.sourceZone);
    final dstZoneCtrl = TextEditingController(text: pol.destZone);
    final serviceCtrl = TextEditingController(text: pol.service);
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
                TextField(controller: srcZoneCtrl, decoration: const InputDecoration(labelText: 'Källzon (Source Zone, t.ex. LAN, WAN, ANY)')),
                TextField(controller: dstZoneCtrl, decoration: const InputDecoration(labelText: 'Målzon (Dest Zone, t.ex. SERVERS, WAN, ANY)')),
                TextField(controller: serviceCtrl, decoration: const InputDecoration(labelText: 'Tjänst / Port (t.ex. HTTP, HTTPS, ANY, TCP)')),
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

                final updatedPolicies = List<PolicyModel>.from(cfg.policies);
                updatedPolicies[idx] = PolicyModel(
                  id: pol.id,
                  name: nameCtrl.text,
                  enabled: pol.enabled,
                  priority: pol.priority,
                  sourceZone: srcZoneCtrl.text.toUpperCase(),
                  destZone: dstZoneCtrl.text.toUpperCase(),
                  sourceObj: pol.sourceObj,
                  destObj: pol.destObj,
                  service: serviceCtrl.text.toUpperCase(),
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
                  zones: cfg.zones,
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
    final nameCtrl = TextEditingController(text: 'Tillåt LAN till SERVERS');
    final srcZoneCtrl = TextEditingController(text: 'LAN');
    final dstZoneCtrl = TextEditingController(text: 'SERVERS');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Skapa Brandväggspolicy', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Policynamn')),
            TextField(controller: srcZoneCtrl, decoration: const InputDecoration(labelText: 'Källzon (Source Zone)')),
            TextField(controller: dstZoneCtrl, decoration: const InputDecoration(labelText: 'Målzon (Dest Zone)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
          ElevatedButton(
            child: const Text('Spara Policy'),
            onPressed: () {
              final cfg = provider.candidateConfig ?? provider.runningConfig;
              if (cfg != null) {
                final newPol = PolicyModel(
                  id: 'pol_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text,
                  enabled: true,
                  sourceZone: srcZoneCtrl.text.toUpperCase(),
                  destZone: dstZoneCtrl.text.toUpperCase(),
                  sourceObj: 'ANY',
                  destObj: 'ANY',
                  service: 'ANY',
                  action: 'accept',
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
}
