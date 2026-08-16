import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    _urlController = TextEditingController(text: provider.api.baseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

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
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Agent URL (IP och Port)',
                            hintText: 'http://10.0.0.163:8443',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link, color: Colors.cyanAccent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync),
                        label: const Text('Spara & Anslut'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20)),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setState(() => _isSaving = true);
                                await provider.changeAgentUrl(_urlController.text);
                                setState(() => _isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(provider.isAuthenticated ? 'Ansluten till ${provider.api.baseUrl}!' : 'Misslyckades ansluta till ${provider.api.baseUrl}'),
                                      backgroundColor: provider.isAuthenticated ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        provider.isAuthenticated ? Icons.check_circle : Icons.error_outline,
                        color: provider.isAuthenticated ? Colors.tealAccent : Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        provider.isAuthenticated ? 'Status: Ansluten och autentiserad' : 'Status: Ej ansluten',
                        style: TextStyle(color: provider.isAuthenticated ? Colors.tealAccent : Colors.amber),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 32),
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
