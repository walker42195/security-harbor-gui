import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../models/config_model.dart';
import '../widgets/tls_trust_dialogs.dart';
import '../app_version.dart';
import '../services/update_service.dart';
import '../services/update_types.dart';

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

  final _syslogHostController = TextEditingController();
  final _syslogPortController = TextEditingController();
  String? _syslogProtocol;
  bool _isSavingSyslog = false;

  final _backupPassphraseController = TextEditingController();
  final _backupResultController = TextEditingController();
  bool _isCreatingBackup = false;
  bool _obscureBackupPassphrase = true;

  final _restoreB64Controller = TextEditingController();
  final _restorePassphraseController = TextEditingController();
  bool _isRestoring = false;

  final _factoryResetPasswordController = TextEditingController();
  bool _factoryResetConfirmed = false;
  bool _isFactoryResetting = false;

  // --- Uppdateringar ---
  bool _checkingUpdate = false;
  bool _updateChecked = false;
  Map<String, dynamic>? _fwUpdate; // agent + webui från agentens update/check
  bool _fwDownloading = false;
  bool _fwVerified = false; // låser upp Uppgradera för firewall-bunten
  bool _fwApplying = false;
  DesktopUpdate? _desktopUpdate;
  bool _desktopDownloading = false;
  bool _desktopVerified = false;
  String? _updateMessage;

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
    _syslogHostController.dispose();
    _syslogPortController.dispose();
    _backupPassphraseController.dispose();
    _backupResultController.dispose();
    _restoreB64Controller.dispose();
    _restorePassphraseController.dispose();
    _factoryResetPasswordController.dispose();
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
                      hintText: 'https://10.0.0.163:8443',
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
                                if (!mounted) return;
                                if (!kIsWeb) {
                                  if (!context.mounted) return;
                                  final proceed = await runTlsTrustCheck(context, provider.api);
                                  if (!mounted || !proceed) {
                                    setState(() => _isLoggingIn = false);
                                    return;
                                  }
                                }
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
            _buildUpdatesCard(provider),
            const SizedBox(height: 16),
            _buildSyslogCard(provider),
            const SizedBox(height: 16),
            _buildBackupRestoreCard(provider),
            const SizedBox(height: 16),
            _buildUserManagementCard(provider),
            const SizedBox(height: 16),
            _buildFactoryResetCard(provider),
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
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err ?? 'Lösenordet är ändrat'),
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

  Widget _buildSyslogCard(ConfigProvider provider) {
    final ConfigModel? cfg = provider.candidateConfig ?? provider.runningConfig;
    final syslog = cfg?.syslog ?? SyslogConfigModel(enabled: false);
    if (_syslogHostController.text.isEmpty && syslog.host.isNotEmpty) {
      _syslogHostController.text = syslog.host;
    }
    if (_syslogPortController.text.isEmpty) {
      _syslogPortController.text = syslog.port.toString();
    }
    _syslogProtocol ??= syslog.protocol;
    final protocol = _syslogProtocol!;

    Future<void> save(SyslogConfigModel updated) async {
      if (cfg == null) return;
      setState(() => _isSavingSyslog = true);
      await provider.updateCandidate(cfg.copyWith(syslog: updated));
      if (mounted) setState(() => _isSavingSyslog = false);
    }

    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forward_to_inbox, color: Colors.cyanAccent, size: 22),
                const SizedBox(width: 10),
                const Text('Centraliserad syslog', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Switch(
                  value: syslog.enabled,
                  activeThumbColor: Colors.tealAccent,
                  onChanged: (v) => save(syslog.copyWith(
                    enabled: v,
                    host: _syslogHostController.text.trim(),
                    port: int.tryParse(_syslogPortController.text.trim()) ?? 514,
                    protocol: protocol,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Vidarebefordra brandväggens systemloggar (inklusive tillåten/nekad trafik) till en central syslog-mottagare på nätet, utöver den lokala lagringen.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _syslogHostController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Mottagarens IP eller hostnamn',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _syslogPortController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '514',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: protocol,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: const [
                    DropdownMenuItem(value: 'udp', child: Text('UDP')),
                    DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                  ],
                  onChanged: (v) => setState(() => _syslogProtocol = v ?? 'udp'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: _isSavingSyslog
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.save, size: 16),
              label: const Text('Spara', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => save(syslog.copyWith(
                enabled: syslog.enabled,
                host: _syslogHostController.text.trim(),
                port: int.tryParse(_syslogPortController.text.trim()) ?? 514,
                protocol: protocol,
              )),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Uppdateringar ----

  Future<void> _checkForUpdates(ConfigProvider provider) async {
    setState(() {
      _checkingUpdate = true;
      _updateMessage = null;
      _fwVerified = false;
      _desktopVerified = false;
    });
    final fw = await provider.api.updateCheck();
    DesktopUpdate? desktop;
    if (!kIsWeb && desktopUpdateSupported) {
      desktop = await checkDesktopUpdate();
    }
    if (!mounted) return;
    setState(() {
      _fwUpdate = fw;
      _desktopUpdate = desktop;
      _updateChecked = true;
      _checkingUpdate = false;
      if (fw == null) {
        _updateMessage = 'Kunde inte kontakta uppdateringstjänsten (kräver att brandväggen når internet).';
      }
    });
  }

  Future<void> _downloadFirewallUpdate(ConfigProvider provider) async {
    setState(() { _fwDownloading = true; _updateMessage = null; });
    final err = await provider.api.updateDownload();
    if (!mounted) return;
    setState(() {
      _fwDownloading = false;
      _fwVerified = err == null;
      _updateMessage = err ?? 'Firewall-bunten nedladdad och verifierad (hash + signatur).';
    });
  }

  Future<void> _applyFirewallUpdate(ConfigProvider provider) async {
    final ok = await _confirmDialog(
      'Uppgradera brandväggen?',
      'Ta en Proxmox-snapshot först. Brandväggen installerar den verifierade bunten och '
          'agenten startar om på den nya versionen. Din konfiguration bevaras.',
    );
    if (!ok) return;
    setState(() { _fwApplying = true; _updateMessage = 'Installerar… agenten startar om strax.'; });
    await provider.api.updateApply();
    if (!mounted) return;
    setState(() {
      _fwApplying = false;
      _fwVerified = false;
      _updateMessage = 'Installationen startad. Agenten startar om — logga in igen om en stund och kontrollera versionen.';
    });
  }

  Future<void> _downloadDesktopUpdate() async {
    if (_desktopUpdate == null) return;
    setState(() { _desktopDownloading = true; _updateMessage = null; });
    final err = await downloadDesktopUpdate(_desktopUpdate!);
    if (!mounted) return;
    setState(() {
      _desktopDownloading = false;
      _desktopVerified = err == null;
      _updateMessage = err ?? 'Desktop-bunten nedladdad och verifierad (hash + signatur).';
    });
  }

  Future<void> _applyDesktopUpdate() async {
    final ok = await _confirmDialog(
      'Uppgradera desktop-appen?',
      'Appen ersätts med den nya versionen och startar om automatiskt. Osparade ändringar i vyn går förlorade.',
    );
    if (!ok) return;
    setState(() => _updateMessage = 'Uppgraderar… appen startar om.');
    await applyDesktopUpdate(); // återvänder normalt aldrig (appen avslutas)
  }

  Future<bool> _confirmDialog(String title, String body) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Fortsätt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Widget _versionRow({
    required String label,
    required String current,
    required String? available,
    required bool updateAvailable,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(
            child: Text(
              'Nu: $current${available != null ? '   •   Senaste: $available' : ''}',
              style: TextStyle(color: updateAvailable ? Colors.orangeAccent : Colors.white70, fontSize: 12),
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  Widget _buildUpdatesCard(ConfigProvider provider) {
    final fwAgent = (_fwUpdate?['agent'] as Map?)?.cast<String, dynamic>();
    final fwWeb = (_fwUpdate?['webui'] as Map?)?.cast<String, dynamic>();
    final agentNew = fwAgent != null && fwAgent['available'] != null && fwAgent['available'] != fwAgent['current'];
    final webNew = fwWeb != null && fwWeb['available'] != null && fwWeb['available'] != fwWeb['current'];
    final fwUpdateAvailable = _fwUpdate?['update_available'] == true || agentNew || webNew;

    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update_alt, color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 8),
                const Text('Uppdateringar', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _checkingUpdate ? null : () => _checkForUpdates(provider),
                  icon: _checkingUpdate
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 16),
                  label: const Text('Kontrollera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_updateChecked)
              const Text('Klicka på Kontrollera för att se om agenten, webb-GUI:t och desktop-appen har nya versioner.',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            if (_updateChecked && _fwUpdate != null) ...[
              _versionRow(
                label: 'Agent',
                current: fwAgent?['current']?.toString() ?? '—',
                available: fwAgent?['available']?.toString(),
                updateAvailable: agentNew,
              ),
              _versionRow(
                label: 'Webb-GUI',
                current: fwWeb?['current']?.toString() ?? '—',
                available: fwWeb?['available']?.toString(),
                updateAvailable: webNew,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: (!fwUpdateAvailable || _fwDownloading || _fwApplying) ? null : () => _downloadFirewallUpdate(provider),
                    icon: _fwDownloading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download, size: 16),
                    label: const Text('Ladda ner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    // Låst tills bunten laddats ner OCH verifierats (hash + signatur).
                    onPressed: (!_fwVerified || _fwApplying) ? null : () => _applyFirewallUpdate(provider),
                    icon: _fwApplying
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upgrade, size: 16),
                    label: const Text('Uppgradera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                  ),
                  if (_fwVerified) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.verified, color: Colors.tealAccent, size: 18),
                  ],
                ],
              ),
            ],
            if (_updateChecked && !kIsWeb && desktopUpdateSupported) ...[
              const Divider(color: Colors.white24, height: 24),
              _versionRow(
                label: 'Desktop-app',
                current: _desktopUpdate?.current ?? kGuiVersion,
                available: _desktopUpdate?.available,
                updateAvailable: _desktopUpdate?.updateAvailable ?? false,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: ((_desktopUpdate?.updateAvailable ?? false) && !_desktopDownloading)
                        ? () => _downloadDesktopUpdate()
                        : null,
                    icon: _desktopDownloading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download, size: 16),
                    label: const Text('Ladda ner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _desktopVerified ? () => _applyDesktopUpdate() : null,
                    icon: const Icon(Icons.upgrade, size: 16),
                    label: const Text('Uppgradera', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                  ),
                  if (_desktopVerified) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.verified, color: Colors.tealAccent, size: 18),
                  ],
                ],
              ),
            ],
            if (_updateMessage != null) ...[
              const SizedBox(height: 10),
              Text(_updateMessage!, style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBackupRestoreCard(ConfigProvider provider) {
    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.backup_outlined, color: Colors.cyanAccent, size: 22),
                SizedBox(width: 10),
                Text('Backup & Återställning', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Backupen innehåller konfigurationen och alla nycklar/certifikat, krypterad under en lösenfras du väljer själv. Spara lösenfrasen separat - den finns inte kvar hos brandväggen.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 16),
            const Text('Skapa backup', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _backupPassphraseController,
                    obscureText: _obscureBackupPassphrase,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Lösenfras för backupen',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureBackupPassphrase ? Icons.visibility : Icons.visibility_off, size: 18, color: Colors.grey),
                        onPressed: () => setState(() => _obscureBackupPassphrase = !_obscureBackupPassphrase),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: _isCreatingBackup
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.backup, size: 16),
                  label: const Text('Skapa backup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                  onPressed: _isCreatingBackup || _backupPassphraseController.text.isEmpty
                      ? null
                      : () async {
                          setState(() => _isCreatingBackup = true);
                          final result = await provider.api.createBackup(_backupPassphraseController.text);
                          if (!mounted) return;
                          setState(() {
                            _isCreatingBackup = false;
                            _backupResultController.text = result.backupB64 ?? '';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result.backupB64 != null ? 'Backup skapad - kopiera och spara texten nedan' : (result.error ?? 'Backup misslyckades')),
                              backgroundColor: result.backupB64 != null ? Colors.green : Colors.red,
                            ),
                          );
                        },
                ),
              ],
            ),
            if (_backupResultController.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                height: 120,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  border: Border.all(color: const Color(0xFF334155)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(_backupResultController.text, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.greenAccent)),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.copy, size: 14, color: Colors.cyanAccent),
                  label: const Text('Kopiera', style: TextStyle(fontSize: 11, color: Colors.cyanAccent)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _backupResultController.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Backup kopierad till urklipp!'), backgroundColor: Colors.teal),
                    );
                  },
                ),
              ),
            ],
            const Divider(color: Colors.white10, height: 32),
            const Text('Återställ från backup', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'Brandväggen startar om automatiskt vid lyckad återställning.',
              style: TextStyle(color: Colors.amberAccent, fontSize: 11),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _restoreB64Controller,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              decoration: const InputDecoration(labelText: 'Klistra in backup-text', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _restorePassphraseController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(labelText: 'Lösenfras', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: _isRestoring
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.restore, size: 16),
                  label: const Text('Återställ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                  onPressed: _isRestoring || _restoreB64Controller.text.isEmpty || _restorePassphraseController.text.isEmpty
                      ? null
                      : () async {
                          setState(() => _isRestoring = true);
                          final err = await provider.api.restoreBackup(_restoreB64Controller.text.trim(), _restorePassphraseController.text);
                          if (!mounted) return;
                          setState(() => _isRestoring = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err ?? 'Återställning skickad - brandväggen startar om, logga in igen om ~10 sekunder'),
                              backgroundColor: err == null ? Colors.green : Colors.red,
                            ),
                          );
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactoryResetCard(ConfigProvider provider) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: Colors.redAccent, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.redAccent, size: 22),
                SizedBox(width: 10),
                Text('Fabriksåterställning', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Tar bort ALL konfiguration, alla nycklar/certifikat och alla användarkonton permanent. Brandväggen startar om med fabriksinställningar (standardinloggning master / SecurityHarbor2026!). Detta går INTE att ångra utan en sparad backup.',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _factoryResetPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(labelText: 'Ditt nuvarande lösenord (krävs)', border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _factoryResetConfirmed,
                  activeColor: Colors.redAccent,
                  onChanged: (v) => setState(() => _factoryResetConfirmed = v ?? false),
                ),
                const Expanded(
                  child: Text('Jag förstår att detta raderar all konfiguration permanent', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: _isFactoryResetting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_forever, size: 16),
              label: const Text('Fabriksåterställ brandväggen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: !_factoryResetConfirmed || _factoryResetPasswordController.text.isEmpty || _isFactoryResetting
                  ? null
                  : () async {
                      setState(() => _isFactoryResetting = true);
                      final err = await provider.api.factoryReset(_factoryResetPasswordController.text);
                      if (!mounted) return;
                      setState(() => _isFactoryResetting = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err ?? 'Fabriksåterställning skickad - brandväggen startar om'),
                          backgroundColor: err == null ? Colors.green : Colors.red,
                        ),
                      );
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
                            if (!mounted) return;
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
                if (!mounted) return;
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
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;
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
