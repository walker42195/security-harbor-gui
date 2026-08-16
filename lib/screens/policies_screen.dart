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
                'Brandväggs- & NAT-regler',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.input),
                    label: const Text('+ Port Forwarding (DNAT)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlueAccent, foregroundColor: Colors.black),
                    onPressed: () => _showAddDNATDialog(context, provider),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('+ Skapa Policy'),
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
                child: Center(child: Text('Inga sparade policies ännu. Standardregel: Nekar all inter-VLAN trafik (Default Deny).', style: TextStyle(color: Colors.grey))),
              ),
            )
          else if (cfg != null)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cfg.policies.length,
              itemBuilder: (context, idx) {
                final pol = cfg.policies[idx];
                final isAllow = pol.action == 'accept';
                final isDNAT = pol.action == 'dnat';

                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDNAT
                          ? Colors.lightBlueAccent.withOpacity(0.2)
                          : isAllow
                              ? Colors.tealAccent.withOpacity(0.2)
                              : Colors.redAccent.withOpacity(0.2),
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
                    trailing: Switch(
                      value: pol.enabled,
                      activeThumbColor: Colors.tealAccent,
                      onChanged: (val) {
                        _togglePolicy(provider, cfg, idx, val);
                      },
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
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
                  sourceZone: srcZoneCtrl.text,
                  destZone: dstZoneCtrl.text,
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
