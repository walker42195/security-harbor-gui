import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Systeminställningar & Management',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agent API-anslutning', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Agent URL', style: TextStyle(color: Colors.white)),
                    subtitle: Text(provider.api.baseUrl, style: const TextStyle(color: Colors.grey)),
                    trailing: const Icon(Icons.lock, color: Colors.tealAccent),
                  ),
                  const Divider(color: Colors.white10),
                  ListTile(
                    title: const Text('Rollback Timeout (Sekunder)', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Standard 30 sekunder innan automatisk återställning sker om bekräftelse uteblir.'),
                    trailing: const Chip(label: Text('30s'), backgroundColor: Colors.cyanAccent),
                  ),
                  const Divider(color: Colors.white10),
                  ListTile(
                    title: const Text('Hård WAN Management-spärr', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('AKTIV PÅ SYSTEMNIVÅ (Kan ej inaktiveras i GUI)'),
                    trailing: const Icon(Icons.verified_user, color: Colors.tealAccent),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
