import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../widgets/dialog_helpers.dart';

class ObjectsScreen extends StatelessWidget {
  const ObjectsScreen({super.key});

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
                'Objekt & Grupper',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.dns),
                label: const Text('+ Skapa Objekt'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                onPressed: () => _showAddObjectDialog(context, provider),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (cfg != null && cfg.objects.isEmpty)
            const Card(
              color: Color(0xFF1E293B),
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: Text('Inga sparade nätverksobjekt ännu.', style: TextStyle(color: Colors.grey))),
              ),
            )
          else if (cfg != null)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cfg.objects.length,
              itemBuilder: (context, idx) {
                final obj = cfg.objects[idx];
                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.category, color: Colors.cyanAccent),
                    title: Text(obj.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Typ: ${obj.type.toUpperCase()}  |  Värden: ${obj.values.join(", ")}'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddObjectDialog(BuildContext context, ConfigProvider provider) {
    final nameCtrl = TextEditingController(text: 'WEB-SERVERS');
    final valCtrl = TextEditingController(text: '192.168.10.10, 192.168.10.11');

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
              dialogTitleRow(context, 'Skapa nytt Nätverksobjekt', () => Navigator.pop(ctx)),
              const SizedBox(height: 12),

              dialogSection(title: 'OBJEKT', children: [
                dialogField(nameCtrl, 'Objektnamn'),
                const SizedBox(height: 12),
                dialogField(valCtrl, 'IP / CIDR', hint: 'komma-separerade'),
              ]),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    child: const Text('Spara', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
              final cfg = provider.candidateConfig ?? provider.runningConfig;
              if (cfg != null) {
                final newObj = ObjectModel(
                  id: 'obj_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text,
                  type: 'host',
                  values: valCtrl.text.split(',').map((e) => e.trim()).toList(),
                  description: 'Skapad i GUI',
                );
                final updatedObjs = List<ObjectModel>.from(cfg.objects)..add(newObj);
                provider.updateCandidate(ConfigModel(
                  version: cfg.version,
                  revision: cfg.revision,
                  updatedAt: cfg.updatedAt,
                  interfaces: cfg.interfaces,
                  zones: cfg.zones,
                  objects: updatedObjs,
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
            ],
          ),
        ),
      ),
    );
  }
}
