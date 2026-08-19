import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../widgets/tls_trust_dialogs.dart';

/// Visas vid appstart (och efter utloggning) istället för att kräva att
/// användaren navigerar till Settings-vyn för att logga in. Brandväggens
/// URL förifylls från det senast sparade värdet (se
/// ConfigProvider._loadSavedUrl) — lösenordet sparas ALDRIG och måste
/// alltid anges manuellt.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late TextEditingController _urlController;
  final _usernameController = TextEditingController(text: 'master');
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _urlControllerInitialized = false;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login(ConfigProvider provider) async {
    await provider.changeAgentUrl(_urlController.text);

    // Trust-on-first-use: kolla brandväggens TLS-certifikat INNAN vi
    // faktiskt loggar in. Hoppas över helt på web (webbläsaren sköter sin
    // egen certifikatvarning) eller om URL:en inte är https://.
    if (!kIsWeb) {
      final proceed = await runTlsTrustCheck(context, provider.api);
      if (!mounted || !proceed) return;
    }

    await provider.login(_usernameController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);

    // _urlController skapas först när det sparade värdet (om något) har
    // hunnit läsas in, så fältet inte hinner visas tomt och sedan hoppa
    // till ett värde efter att SharedPreferences svarat.
    if (!_urlControllerInitialized && !provider.isInitializing) {
      _urlController = TextEditingController(text: provider.api.baseUrl == 'https://localhost:8443' ? '' : provider.api.baseUrl);
      _urlControllerInitialized = true;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: provider.isInitializing
            ? const CircularProgressIndicator(color: Colors.cyanAccent)
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.security, color: Colors.cyanAccent, size: 48),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Administrationsgränssnitt', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          border: Border.all(color: const Color(0xFF334155)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!kIsWeb) ...[
                              TextField(
                                controller: _urlController,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: const InputDecoration(
                                  labelText: 'Brandväggens adress',
                                  hintText: 'https://10.0.0.163:8443',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.link, color: Colors.cyanAccent, size: 18),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextField(
                              controller: _usernameController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'Användarnamn',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person, color: Colors.cyanAccent, size: 18),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              onSubmitted: (_) => _login(provider),
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
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                icon: provider.isLoading
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                    : const Icon(Icons.login, size: 16),
                                label: const Text('Logga in', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                                onPressed: provider.isLoading ? null : () => _login(provider),
                              ),
                            ),
                            if (provider.errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
