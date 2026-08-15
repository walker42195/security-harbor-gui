import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

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
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('+ Lägg till VLAN'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                onPressed: () => _showAddVLANDialog(context, provider),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (cfg != null)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cfg.interfaces.length,
              itemBuilder: (context, idx) {
                final iface = cfg.interfaces[idx];
                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      iface.vlanId > 0 ? Icons.share : Icons.settings_ethernet,
                      color: iface.zone == 'WAN' ? Colors.redAccent : Colors.cyanAccent,
                    ),
                    title: Text('${iface.id}  [${iface.device}]', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Zon: ${iface.zone}  |  IP: ${iface.ipv4}  |  VLAN ID: ${iface.vlanId > 0 ? iface.vlanId : "Ingen"}'),
                    trailing: Switch(
                      value: iface.enabled,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) {
                        final updatedIfaces = List<InterfaceModel>.from(cfg.interfaces);
                        updatedIfaces[idx] = InterfaceModel(
                          id: iface.id,
                          device: iface.device,
                          parent: iface.parent,
                          vlanId: iface.vlanId,
                          zone: iface.zone,
                          enabled: val,
                          addressType: iface.addressType,
                          ipv4: iface.ipv4,
                          gateway: iface.gateway,
                          mtu: iface.mtu,
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

  void _showAddVLANDialog(BuildContext context, ConfigProvider provider) {
    final nameCtrl = TextEditingController(text: 'vlan10');
    final vlanIdCtrl = TextEditingController(text: '10');
    final ipCtrl = TextEditingController(text: '192.168.10.1/24');
    String selectedZone = 'LAN';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Skapa nytt VLAN Interface', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Namn (t.ex. vlan10)')),
            TextField(controller: vlanIdCtrl, decoration: const InputDecoration(labelText: 'VLAN ID (1-4094)')),
            TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP / Subnät (t.ex. 192.168.10.1/24)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
          ElevatedButton(
            child: const Text('Skapa'),
            onPressed: () {
              final cfg = provider.candidateConfig ?? provider.runningConfig;
              if (cfg != null) {
                final newIface = InterfaceModel(
                  id: nameCtrl.text,
                  device: 'ens19.${vlanIdCtrl.text}',
                  parent: 'ens19',
                  vlanId: int.tryParse(vlanIdCtrl.text) ?? 10,
                  zone: selectedZone,
                  enabled: true,
                  addressType: 'static',
                  ipv4: ipCtrl.text,
                );
                final updatedIfaces = List<InterfaceModel>.from(cfg.interfaces)..add(newIface);
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
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
