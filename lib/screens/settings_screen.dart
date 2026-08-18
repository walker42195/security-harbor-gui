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

  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  bool _isChangingPassword = false;

  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = false;
  final _newUserController = TextEditingController();
  final _newUserPwController = TextEditingController();
  String _newUserRole = 'viewer';

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    _urlController = TextEditingController(text: provider.api.baseUrl);
    // Inget hop-kodat lösenord här — appen distribueras publikt, och ett
    // förifyllt lösenord i klientkoden hade skickats ut till varje
    // nedladdning. Användarnamnet "admin" är inte känsligt i sig.
    _usernameController = TextEditingController(text: 'master');
    _passwordController = TextEditingController();
    if (provider.isAuthenticated && provider.isAdmin) {
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    setState(() => _loadingUsers = true);
    final users = await provider.api.getUsers();
    if (mounted) setState(() { _users = users; _loadingUsers = false; });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _currentPwController.dispose();
    _newPwController.dispose();
    _newUserController.dispose();
    _newUserPwController.dispose();
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
                            hintText: 'master',
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

          if (provider.isAuthenticated) ...[
            const SizedBox(height: 16),
            _buildChangePasswordCard(provider),
          ],

          if (provider.isAuthenticated && provider.isAdmin) ...[
            const SizedBox(height: 16),
            _buildUserManagementCard(provider),
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordCard(ConfigProvider provider) {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.password, color: Colors.cyanAccent, size: 22),
                SizedBox(width: 10),
                Text('Byt eget lösenord', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _currentPwController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Nuvarande lösenord',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _newPwController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Nytt lösenord (minst 8 tecken)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: _isChangingPassword
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.save, size: 16),
              label: const Text('Byt lösenord', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _isChangingPassword
                  ? null
                  : () async {
                      setState(() => _isChangingPassword = true);
                      final err = await provider.api.changePassword(_currentPwController.text, _newPwController.text);
                      setState(() => _isChangingPassword = false);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err == null ? 'Lösenordet är ändrat' : err),
                          backgroundColor: err == null ? Colors.green : Colors.red,
                        ),
                      );
                      if (err == null) {
                        _currentPwController.clear();
                        _newPwController.clear();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagementCard(ConfigProvider provider) {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group, color: Colors.cyanAccent, size: 22),
                const SizedBox(width: 10),
                const Text('Användare', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                IconButton(
                  icon: _loadingUsers
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                      : const Icon(Icons.refresh, size: 18, color: Colors.cyanAccent),
                  onPressed: _loadingUsers ? null : _loadUsers,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_users.isEmpty && !_loadingUsers)
              const Text('Inga användare inlästa.', style: TextStyle(color: Colors.white38, fontSize: 12))
            else
              ..._users.map((u) => ListTile(
                    dense: true,
                    leading: Icon(u['role'] == 'admin' ? Icons.admin_panel_settings : Icons.visibility, color: Colors.cyanAccent, size: 18),
                    title: Text(u['username'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    subtitle: Text(u['role'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.lock_reset, size: 16, color: Colors.amber),
                          tooltip: 'Återställ lösenord',
                          onPressed: () => _showResetPasswordDialog(provider, u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                          tooltip: 'Ta bort användare',
                          onPressed: () async {
                            final err = await provider.api.deleteUser(u['id']);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(err ?? 'Användaren borttagen'),
                                backgroundColor: err == null ? Colors.green : Colors.red,
                              ),
                            );
                            if (err == null) _loadUsers();
                          },
                        ),
                      ],
                    ),
                  )),
            const Divider(color: Colors.white10, height: 32),
            const Text('Skapa ny användare', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newUserController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(labelText: 'Användarnamn', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _newUserPwController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(labelText: 'Lösenord (minst 8 tecken)', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _newUserRole,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: const [
                    DropdownMenuItem(value: 'viewer', child: Text('viewer')),
                    DropdownMenuItem(value: 'admin', child: Text('admin')),
                  ],
                  onChanged: (v) => setState(() => _newUserRole = v ?? 'viewer'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text('Skapa användare', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                final err = await provider.api.createUser(_newUserController.text, _newUserPwController.text, _newUserRole);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(err ?? 'Användaren skapad'),
                    backgroundColor: err == null ? Colors.green : Colors.red,
                  ),
                );
                if (err == null) {
                  _newUserController.clear();
                  _newUserPwController.clear();
                  _loadUsers();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(ConfigProvider provider, Map<String, dynamic> user) {
    final pwController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Återställ lösenord för ${user['username']}', style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: TextField(
          controller: pwController,
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: const InputDecoration(labelText: 'Nytt lösenord (minst 8 tecken)', border: OutlineInputBorder(), isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Avbryt')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () async {
              final err = await provider.api.resetUserPassword(user['id'], pwController.text);
              Navigator.pop(dialogContext);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(err ?? 'Lösenordet återställt'),
                  backgroundColor: err == null ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text('Återställ'),
          ),
        ],
      ),
    );
  }
}
