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
                'Brandväggs- & NAT-Policies',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_moderator),
                label: const Text('+ Ny Policy'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                onPressed: () => _showAddPolicyDialog(context, provider),
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
                  child: Text('Inga användardefinierade policies. Default policy (DROP all forward) gäller.', style: TextStyle(color: Colors.grey)),
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
                final isAllow = pol.action == 'accept';
                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isAllow ? Colors.tealAccent.withOpacity(0.2) : Colors.redAccent.withOpacity(0.2),
                      child: Icon(
                        isAllow ? Icons.check_circle : Icons.block,
                        color: isAllow ? Colors.tealAccent : Colors.redAccent,
                      ),
                    ),
                    title: Text(pol.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Från: ${pol.sourceZone} (${pol.sourceObj})  ➔  Till: ${pol.destZone} (${pol.destObj})  |  Tjänst: ${pol.service}'),
                    trailing: Switch(
                      value: pol.enabled,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) {
                        final updatedPolicies = List<PolicyModel>.from(cfg.policies);
                        updatedPolicies[idx] = PolicyModel(
                          id: pol.id,
                          name: pol.name,
                          enabled: val,
                          priority: pol.priority,
                          sourceZone: pol.sourceZone,
                          destZone: pol.destZone,
                          sourceObj: pol.sourceObj,
                          destObj: pol.destObj,
                          service: pol.service,
                          action: pol.action,
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

  void _showAddPolicyDialog(BuildContext context, ConfigProvider provider) {
    final nameCtrl = TextEditingController(text: 'LAN till Internet');
    String srcZone = 'LAN';
    String destZone = 'WAN';
    String action = 'accept';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Skapa Brandväggs-policy', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Policynamn')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Från Zon: $srcZone', style: const TextStyle(color: Colors.white))),
                Expanded(child: Text('Till Zon: $destZone', style: const TextStyle(color: Colors.white))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
          ElevatedButton(
            child: const Text('Spara'),
            onPressed: () {
              final cfg = provider.candidateConfig ?? provider.runningConfig;
              if (cfg != null) {
                final newPol = PolicyModel(
                  id: 'pol_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text,
                  enabled: true,
                  priority: (cfg.policies.length + 1) * 10,
                  sourceZone: srcZone,
                  destZone: destZone,
                  sourceObj: 'ANY',
                  destObj: 'ANY',
                  service: 'ANY',
                  action: action,
                  logging: true,
                  description: 'Skapad i GUI',
                );
                final updatedPolicies = List<PolicyModel>.from(cfg.policies)..add(newPol);
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
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
