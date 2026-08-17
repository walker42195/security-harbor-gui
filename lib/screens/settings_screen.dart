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
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  bool _isLoggingIn = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    _urlController = TextEditingController(text: provider.api.baseUrl);
    _usernameController = TextEditingController(text: 'admin');
    _passwordController = TextEditingController(text: 'SecurityHarbor2026!');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);

    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.settings, color: Colors.cyanAccent, size: 22),
              SizedBox(width: 10),
              Text('Systeminställningar & Management', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),

          // Inloggning & Serveranslutningskort
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.security, color: Colors.cyanAccent, size: 22),
                      SizedBox(width: 10),
                      Text('Server-inloggning & Agent API', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Server URL
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Brandväggens Agent URL (IP och Port)',
                      hintText: 'http://10.0.0.163:8443',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link, color: Colors.cyanAccent, size: 18),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Användarnamn & Lösenord
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'Användarnamn',
                            hintText: 'admin',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person, color: Colors.cyanAccent, size: 18),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          decoration: InputDecoration(
                            labelText: 'Lösenord',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock, color: Colors.cyanAccent, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, size: 18, color: Colors.grey),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Inloggningsknapp & Status
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: _isLoggingIn
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.login, size: 16),
                        label: const Text('Logga in på Brandväggen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: _isLoggingIn
                            ? null
                            : () async {
                                setState(() => _isLoggingIn = true);
                                await provider.changeAgentUrl(_urlController.text);
                                await provider.login(_usernameController.text, _passwordController.text);
                                setState(() => _isLoggingIn = false);

                                if (context.mounted) {
                                  final ok = provider.isAuthenticated;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Inloggad som ${_usernameController.text} på ${_urlController.text}!'
                                          : 'Inloggning misslyckades på ${_urlController.text}'),
                                      backgroundColor: ok ? Colors.green : Colors.red,
                                    ),
                                  );
                                }
                              },
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          Icon(
                            provider.isAuthenticated ? Icons.check_circle : Icons.error_outline,
                            color: provider.isAuthenticated ? Colors.tealAccent : Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            provider.isAuthenticated
                                ? 'Status: Inloggad (Token Aktiv)'
                                : 'Status: Ej inloggad',
                            style: TextStyle(
                              color: provider.isAuthenticated ? Colors.tealAccent : Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Divider(color: Colors.white10, height: 32),

                  // Övriga Systeminställningar
                  ListTile(
                    dense: true,
                    title: const Text('Safe Apply Rollback Timeout (Sekunder)', style: TextStyle(color: Colors.white, fontSize: 12)),
                    subtitle: const Text('Standard 30 sekunder innan automatisk återställning sker om bekräftelse (Commit) uteblir.', style: TextStyle(fontSize: 11)),
                    trailing: const Chip(label: Text('30s', style: TextStyle(fontSize: 11)), backgroundColor: Colors.cyanAccent),
                  ),
                  const Divider(color: Colors.white10),
                  ListTile(
                    dense: true,
                    title: const Text('Hård WAN Management-spärr', style: TextStyle(color: Colors.white, fontSize: 12)),
                    subtitle: const Text('AKTIV PÅ SYSTEMNIVÅ (Inkommande administration på WAN spärras alltid för säkerhet)', style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.verified_user, color: Colors.tealAccent, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
