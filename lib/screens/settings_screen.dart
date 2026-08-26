import 'dart:convert' show utf8;
import '../theme.dart';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../localization.dart';
import '../time_format.dart';
import 'package:file_selector/file_selector.dart';
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

  // --- Tidigare versioner (rollback) ---
  List<Map<String, dynamic>>? _retainedVersions; // versions[] från /system/versions
  String? _retainedCurrentVersion; // "current" från samma svar
  bool _loadingRetainedVersions = false;
  bool _rollbackInProgress = false;
  String? _rollbackTargetVersion;

  // --- Tidigare konfigurationer (konfigurationshistorik) ---
  List<Map<String, dynamic>>? _configHistory; // history[] från /config/history
  int? _currentConfigRevision;
  bool _loadingConfigHistory = false;
  String? _restoringConfigId;

  // Rollback-timeouten (sekunder) som redigerbart fält.
  final TextEditingController _rollbackTimeoutController = TextEditingController();
  /// Tidszoner som servern känner till, plus den som faktiskt gäller där nu.
  /// Hämtas en gång; listan är statisk för en given server.
  List<String> _timezones = const [];
  String _serverTimezone = '';
  int? _rollbackTimeoutLoadedFrom; // värdet fältet fylldes från, för dirty-check

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
      _loadRetainedVersions(provider);
      _loadConfigHistory(provider);
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
    _rollbackTimeoutController.dispose();
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
    _syncRollbackTimeoutField(provider);
    _loadTimezones(provider);

    return Container(
      color: AppColors.bg,
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: Colors.cyanAccent, size: 22),
              const SizedBox(width: 10),
              Text(tr('settings.page_title'), style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),


          // Ordningen är den användaren bad om 2026-08-26: det man gör ofta
          // överst, och Server-inloggning sist — den rör man en gång när
          // klienten sätts upp och sedan aldrig mer.
          if (provider.isAuthenticated && provider.isAdmin) ...[
            _buildUpdatesCard(provider),
            const SizedBox(height: 16),
          ],
          _buildLanguageCard(provider),

          if (provider.isAuthenticated && provider.isAdmin) ...[
            const SizedBox(height: 16),
            _buildTimezoneCard(provider),
          ],

          if (provider.isAuthenticated) ...[
            const SizedBox(height: 16),
            _buildChangePasswordCard(provider),
          ],

          if (provider.isAuthenticated && provider.isAdmin) ...[
            const SizedBox(height: 16),
            _buildUserManagementCard(provider),
            const SizedBox(height: 16),
            _buildConfigHistoryCard(provider),
            const SizedBox(height: 16),
            _buildSyslogCard(provider),
            const SizedBox(height: 16),
            _buildBackupRestoreCard(provider),
            const SizedBox(height: 16),
            _buildFactoryResetCard(provider),
          ],

          const SizedBox(height: 16),
          _buildLoginCard(context, provider),
        ],
        ),
      ),
    );
  }

  /// Server-inloggning (URL, användare, lösenord, anslutningsstatus).
  /// Låg längst upp tidigare men ligger nu sist: det är en engångsinställning
  /// när klienten kopplas till en brandvägg, inte något man återkommer till.
  Widget _buildLoginCard(BuildContext context, ConfigProvider provider) {
    return Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security, color: Colors.cyanAccent, size: 22),
                        const SizedBox(width: 10),
                        Text(tr('settings.login.title'), style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Server URL
                    TextField(
                      controller: _urlController,
                      style: TextStyle(color: AppColors.text, fontSize: 12),
                      decoration: InputDecoration(
                        labelText: tr('settings.login.url_label'),
                        hintText: tr('settings.https_192_168_1_1_8443'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.link, color: Colors.cyanAccent, size: 18),
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
                            style: TextStyle(color: AppColors.text, fontSize: 12),
                            decoration: InputDecoration(
                              labelText: tr('settings.login.username_label'),
                              hintText: tr('settings.master'),
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.person, color: Colors.cyanAccent, size: 18),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: AppColors.text, fontSize: 12),
                            decoration: InputDecoration(
                              labelText: tr('settings.login.password_label'),
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock, color: Colors.cyanAccent, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, size: 18, color: AppColors.textMuted),
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
                          label: Text(tr('settings.login.submit'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                                            ? trp('settings.login.snackbar_success', {'user': _usernameController.text, 'url': _urlController.text})
                                            : trp('settings.login.snackbar_failed', {'url': _urlController.text})),
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
                                  ? tr('settings.login.status_logged_in')
                                  : tr('settings.login.status_logged_out'),
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
  
                    Divider(color: AppColors.divider, height: 32),
  
                    // Övriga Systeminställningar
                    // Rollback-timeouten var tidigare en Chip — ett värde man
                    // kunde läsa (knappt: ljus text på cyan botten) men inte
                    // ändra, trots att agenten läser fältet ur configen. Nu är
                    // det en riktig inmatningsruta.
                    ListTile(
                      dense: true,
                      title: Text(tr('settings.rollback_timeout.title'), style: TextStyle(color: AppColors.text, fontSize: 12)),
                      subtitle: Text(tr('settings.rollback_timeout.body'), style: const TextStyle(fontSize: 11)),
                      trailing: provider.isAdmin
                          ? SizedBox(
                              width: 132,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 72,
                                    child: TextField(
                                      controller: _rollbackTimeoutController,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(color: AppColors.text, fontSize: 13),
                                      textAlign: TextAlign.right,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        suffixText: 's',
                                        suffixStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(),
                                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF475569))),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.save, size: 18, color: Colors.cyanAccent),
                                    tooltip: tr('settings.rollback_timeout.save'),
                                    onPressed: _rollbackTimeoutDirty(provider) ? () => _saveRollbackTimeout(provider) : null,
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              '${(provider.runningConfig ?? provider.candidateConfig)?.settings.rollbackTimeoutSec ?? 30} s',
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                    ),
                    Divider(color: AppColors.divider),
                    ListTile(
                      dense: true,
                      title: Text(tr('settings.wan_lock.title'), style: TextStyle(color: AppColors.text, fontSize: 12)),
                      subtitle: Text(tr('settings.wan_lock.body'), style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.verified_user, color: Colors.tealAccent, size: 18),
                    ),
                  ],
                ),
              ),
            );
  }

  Future<void> _loadTimezones(ConfigProvider provider) async {
    if (_timezones.isNotEmpty || !provider.isAuthenticated || !provider.isAdmin) return;
    final result = await provider.api.getTimezones();
    if (!mounted) return;
    setState(() {
      _timezones = result.available;
      _serverTimezone = result.current;
    });
  }

  /// Tidszon på servern.
  ///
  /// Visar BÅDE vad konfigurationen säger och vad servern faktiskt står på.
  /// De två kan skilja sig: värdet sätts först vid Applicera, och lyckas det
  /// inte (t.ex. saknad polkit-regel) syns det som en varning i stället för
  /// att tyst se ut att ha gått igenom.
  Widget _buildTimezoneCard(ConfigProvider provider) {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    final selected = cfg?.settings.timezone ?? '';
    final differs = selected.isNotEmpty &&
        _serverTimezone.isNotEmpty &&
        selected != _serverTimezone;

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.cyanAccent, size: 22),
                const SizedBox(width: 10),
                Text(tr('settings.tidszon'),
                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 6),
            Text(tr('settings.tidszon_body'),
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _timezoneReadout(
                      tr('settings.tidszon_nuvarande'),
                      _serverTimezone.isEmpty ? '—' : _serverTimezone),
                ),
                Expanded(
                  child: _timezoneReadout(
                      tr('settings.tidszon_vald'),
                      selected.isEmpty ? tr('settings.tidszon_ej_satt') : selected),
                ),
              ],
            ),
            if (differs) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.amberAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(tr('settings.tidszon_avvikelse'),
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_calendar, size: 15),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              label: Text(tr('settings.tidszon_sok'), style: const TextStyle(fontSize: 12)),
              onPressed: () => _pickTimezone(provider, selected),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.desktop_windows_outlined, size: 13, color: AppColors.textFaint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(tr('settings.tidszon_klientnotis'),
                      style: TextStyle(color: AppColors.textFaint, fontSize: 10.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timezoneReadout(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(color: AppColors.text, fontSize: 12.5)),
        ],
      );

  /// Sökbar väljare. Listan är ~600 zoner lång — en vanlig dropdown är
  /// oanvändbar där, man måste kunna skriva "stock" och få träffen.
  Future<void> _pickTimezone(ConfigProvider provider, String current) async {
    final searchCtrl = TextEditingController();
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final matches = _timezones
              .where((z) => query.isEmpty || z.toLowerCase().contains(query))
              .toList();
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(tr('settings.tidszon'),
                style: TextStyle(color: AppColors.text, fontSize: 14)),
            content: SizedBox(
              width: 420,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    style: TextStyle(color: AppColors.text, fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search, size: 16, color: AppColors.textMuted),
                      labelText: tr('settings.tidszon_sok'),
                      labelStyle: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: matches.isEmpty
                        ? Center(
                            child: Text(tr('settings.tidszon_ej_satt'),
                                style: TextStyle(color: AppColors.textFaint, fontSize: 12)))
                        : ListView.builder(
                            itemCount: matches.length,
                            itemBuilder: (_, i) {
                              final zone = matches[i];
                              final isCurrent = zone == current;
                              return ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                leading: Icon(
                                    isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
                                    size: 15,
                                    color: isCurrent ? Colors.cyanAccent : AppColors.textMuted),
                                title: Text(zone,
                                    style: TextStyle(
                                        color: isCurrent ? Colors.cyanAccent : AppColors.text,
                                        fontSize: 12)),
                                onTap: () => Navigator.of(ctx).pop(zone),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(tr('main.cancel'))),
            ],
          );
        },
      ),
    );
    searchCtrl.dispose();
    if (picked == null) return;

    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return;
    await provider.updateCandidate(
        cfg.copyWith(settings: cfg.settings.copyWith(timezone: picked)));
  }

  Widget _buildLanguageCard(ConfigProvider provider) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.language, color: Colors.cyanAccent, size: 22),
                const SizedBox(width: 10),
                Text(tr('settings.language.title'), style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            Text(tr('settings.language.body'), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 14),
            SegmentedButton<AppLanguage>(
              segments: [
                ButtonSegment(value: AppLanguage.sv, label: Text(tr('settings.language.sv'))),
                ButtonSegment(value: AppLanguage.en, label: Text(tr('settings.language.en'))),
              ],
              selected: {provider.language},
              onSelectionChanged: (selection) => provider.setLanguage(selection.first),
              style: SegmentedButton.styleFrom(
                backgroundColor: AppColors.bg,
                foregroundColor: AppColors.textMuted,
                selectedBackgroundColor: Colors.cyanAccent,
                selectedForegroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordCard(ConfigProvider provider) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.password, color: Colors.cyanAccent, size: 22),
                SizedBox(width: 10),
                Text(tr('settings.byt_eget_losenord'), style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _currentPwController,
                    obscureText: true,
                    style: TextStyle(color: AppColors.text, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: tr('settings.nuvarande_losenord'),
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
                    style: TextStyle(color: AppColors.text, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: tr('settings.nytt_losenord_minst_8_tecken'),
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
              label: Text(tr('settings.byt_losenord'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                          content: Text(err ?? tr('settings.password_changed')),
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
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forward_to_inbox, color: Colors.cyanAccent, size: 22),
                const SizedBox(width: 10),
                Text(tr('settings.centraliserad_syslog'), style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
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
            Text(tr('settings.vidarebefordra_brandvaggens_systemloggar_inklusive_tillaten_nekad'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _syslogHostController,
                    style: TextStyle(color: AppColors.text, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: tr('settings.mottagarens_ip_eller_hostnamn'),
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
                    style: TextStyle(color: AppColors.text, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: tr('settings.port'),
                      hintText: '514',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: protocol,
                  dropdownColor: AppColors.surface,
                  style: TextStyle(color: AppColors.text, fontSize: 12),
                  items: [
                    DropdownMenuItem(value: 'udp', child: Text(tr('settings.udp'))),
                    DropdownMenuItem(value: 'tcp', child: Text(tr('settings.tcp'))),
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
              label: Text(tr('settings.spara'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        _updateMessage = tr('settings.update_check_failed');
      }
    });
    await _loadRetainedVersions(provider);
  }

  Future<void> _downloadFirewallUpdate(ConfigProvider provider) async {
    setState(() { _fwDownloading = true; _updateMessage = null; });
    final err = await provider.api.updateDownload();
    if (!mounted) return;
    setState(() {
      _fwDownloading = false;
      _fwVerified = err == null;
      _updateMessage = err ?? tr('settings.firmware_downloaded_verified');
    });
  }

  Future<void> _applyFirewallUpdate(ConfigProvider provider) async {
    final ok = await _confirmDialog(
      tr('settings.upgrade_firewall_title'),
      tr('settings.upgrade_firewall_body'),
    );
    if (!ok) return;
    final target = (_fwUpdate?['agent'] as Map?)?['available']?.toString();
    setState(() {
      _fwApplying = true;
      _updateMessage = tr('settings.starting_install');
    });
    await provider.api.updateApply();
    if (!mounted) return;
    // Följ uppgraderingen: agenten installerar och startar om (API:t är nere en
    // stund). Polla tills den svarar igen på den nya versionen, med en tydlig
    // "Uppgraderar…"-indikator hela tiden. Token/sessionen överlever omstarten,
    // så användaren behöver inte logga in igen.
    await _pollForUpgrade(provider, target);
  }

  Future<void> _pollForUpgrade(ConfigProvider provider, String? target) async {
    const stepSeconds = 3;
    const maxSeconds = 240; // ~4 min tak (install.sh kör bl.a. suricata-update)
    for (var elapsed = stepSeconds; elapsed <= maxSeconds; elapsed += stepSeconds) {
      await Future.delayed(const Duration(seconds: stepSeconds));
      if (!mounted) return;
      // Den ÖPPNA version-endpointen svarar även om token blivit ogiltig av
      // omstarten — så vi kan upptäcka att agenten kommit tillbaka på nya
      // versionen oavsett sessionsläge. null medan agenten är nere.
      final ver = await provider.api
          .getAgentVersion()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (!mounted) return;
      if (ver != null && (target == null || ver == target)) {
        // Agenten är uppe på (den nya) versionen. Är sessionen fortfarande
        // giltig? (Nyare agenter persisterar token över omstarten.)
        final status = await provider.api
            .getSystemStatus()
            .timeout(const Duration(seconds: 4), onTimeout: () => null);
        if (!mounted) return;
        _fwApplying = false;
        _fwVerified = false;
        _fwUpdate = null; // tvinga en ny "Kontrollera" för uppdaterad status
        if (status != null) {
          provider.systemStatus = status;
          setState(() => _updateMessage = trp('settings.upgrade_complete', {'ver': ver}));
        } else {
          // Token blev ogiltig av omstarten — visa inloggningsvyn.
          setState(() => _updateMessage = trp('settings.upgrade_complete_relogin', {'ver': ver}));
          await provider.logout();
        }
        return;
      }
      setState(() {
        _updateMessage = ver == null
            ? trp('settings.upgrading_installing', {'s': elapsed.toString()})
            : trp('settings.upgrading_waiting', {'ver': ver, 's': elapsed.toString()});
      });
    }
    if (!mounted) return;
    setState(() {
      _fwApplying = false;
      _updateMessage = tr('settings.upgrade_taking_long');
    });
  }

  /// Synkar textfältet med configen, men BARA när användaren inte håller på
  /// att redigera det — annars hade varje inkommande statusuppdatering
  /// skrivit över det man just skrivit in.
  void _syncRollbackTimeoutField(ConfigProvider provider) {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return;
    final value = cfg.settings.rollbackTimeoutSec;
    if (_rollbackTimeoutLoadedFrom == value) return;
    _rollbackTimeoutLoadedFrom = value;
    _rollbackTimeoutController.text = '$value';
  }

  bool _rollbackTimeoutDirty(ConfigProvider provider) {
    final parsed = int.tryParse(_rollbackTimeoutController.text.trim());
    return parsed != null && parsed != _rollbackTimeoutLoadedFrom;
  }

  /// Sparar timeouten till kandidatkonfigurationen. Agenten klämmer värdet
  /// till 10 s–10 min; vi avvisar samma intervall här så att användaren får
  /// veta det direkt istället för att undra varför siffran ändrade sig.
  Future<void> _saveRollbackTimeout(ConfigProvider provider) async {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return;
    final parsed = int.tryParse(_rollbackTimeoutController.text.trim());
    if (parsed == null || parsed < 10 || parsed > 600) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('settings.rollback_timeout.invalid')), backgroundColor: Colors.red),
      );
      return;
    }
    await provider.updateCandidate(
      cfg.copyWith(settings: cfg.settings.copyWith(rollbackTimeoutSec: parsed)),
    );
    if (!mounted) return;
    _rollbackTimeoutLoadedFrom = parsed;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('settings.rollback_timeout.saved')), backgroundColor: Colors.teal),
    );
  }

  Future<void> _loadConfigHistory(ConfigProvider provider) async {
    setState(() => _loadingConfigHistory = true);
    final res = await provider.api.listConfigHistory();
    if (!mounted) return;
    setState(() {
      _configHistory = res == null
          ? null
          : List<Map<String, dynamic>>.from((res['history'] as List?) ?? const []);
      _currentConfigRevision = (res?['current_revision'] as num?)?.toInt();
      _loadingConfigHistory = false;
    });
  }

  /// Läser in en sparad konfiguration som kandidat. Den aktiveras INTE här —
  /// användaren måste trycka Applicera, precis som för varje annan ändring,
  /// och får då hela Safe Apply-kedjan. Därför är dialogen formulerad som
  /// "läs in", inte "återställ": inget har ändrats skarpt när den är klar.
  Future<void> _restoreConfigFromHistory(ConfigProvider provider, Map<String, dynamic> entry) async {
    final id = entry['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final revision = entry['revision']?.toString() ?? '?';
    final ok = await _confirmDialog(
      trp('settings.config_history.restore_confirm_title', {'revision': revision}),
      tr('settings.config_history.restore_confirm_body'),
    );
    if (!ok) return;
    setState(() {
      _restoringConfigId = id;
      _updateMessage = null;
    });
    final err = await provider.api.restoreConfigFromHistory(id);
    if (!mounted) return;
    setState(() => _restoringConfigId = null);
    if (err != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
      return;
    }
    // Kandidaten på servern har bytts ut — hämta hem den så att GUI:t visar
    // den inlästa konfigurationen och "ej applicerade ändringar"-indikatorn.
    await provider.fetchAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(trp('settings.config_history.restored', {'revision': revision})),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _loadRetainedVersions(ConfigProvider provider) async {
    setState(() => _loadingRetainedVersions = true);
    final res = await provider.api.listRetainedVersions();
    if (!mounted) return;
    setState(() {
      _retainedVersions = res == null
          ? null
          : List<Map<String, dynamic>>.from((res['versions'] as List?) ?? const []);
      _retainedCurrentVersion = res?['current']?.toString();
      _loadingRetainedVersions = false;
    });
  }

  Future<void> _rollbackToVersion(ConfigProvider provider, String version) async {
    final ok = await _confirmDialog(
      trp('settings.rollback_confirm_title', {'version': version}),
      trp('settings.rollback_confirm_body', {'version': version}),
    );
    if (!ok) return;
    setState(() {
      _rollbackInProgress = true;
      _rollbackTargetVersion = version;
      _updateMessage = tr('settings.starting_rollback');
    });
    await provider.api.rollbackToVersion(version);
    if (!mounted) return;
    // Samma polling-mönster som en vanlig uppgradering — agenten är nere en
    // stund medan den installerar om och startar om.
    await _pollForUpgrade(provider, version);
    if (!mounted) return;
    setState(() {
      _rollbackInProgress = false;
      _rollbackTargetVersion = null;
    });
    await _loadRetainedVersions(provider);
  }

  Future<void> _downloadDesktopUpdate() async {
    if (_desktopUpdate == null) return;
    setState(() { _desktopDownloading = true; _updateMessage = null; });
    final err = await downloadDesktopUpdate(_desktopUpdate!);
    if (!mounted) return;
    setState(() {
      _desktopDownloading = false;
      _desktopVerified = err == null;
      _updateMessage = err ?? tr('settings.desktop_downloaded_verified');
    });
  }

  Future<void> _applyDesktopUpdate() async {
    final ok = await _confirmDialog(
      tr('settings.upgrade_desktop_title'),
      tr('settings.upgrade_desktop_body'),
    );
    if (!ok) return;
    setState(() => _updateMessage = tr('settings.upgrading_app_restart'));
    await applyDesktopUpdate(); // återvänder normalt aldrig (appen avslutas)
  }

  Future<bool> _confirmDialog(String title, String body) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Text(body, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('settings.avbryt'), style: TextStyle(fontSize: 12))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('settings.fortsatt'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
          SizedBox(width: 110, child: Text(label, style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(
            child: Text(
              trp('settings.now_latest', {'current': current, 'latest': available != null ? trp('settings.latest_suffix', {'available': available}) : ''}),
              style: TextStyle(color: updateAvailable ? Colors.orangeAccent : AppColors.textMuted, fontSize: 12),
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
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update_alt, color: Colors.cyanAccent, size: 20),
                const SizedBox(width: 8),
                Text(tr('settings.uppdateringar'), style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _checkingUpdate ? null : () => _checkForUpdates(provider),
                  icon: _checkingUpdate
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(tr('settings.kontrollera'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_updateChecked)
              Text(tr('settings.klicka_pa_kontrollera_for_att_se'),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            if (_updateChecked && _fwUpdate != null) ...[
              _versionRow(
                label: tr('settings.agent_label'),
                current: fwAgent?['current']?.toString() ?? '—',
                available: fwAgent?['available']?.toString(),
                updateAvailable: agentNew,
              ),
              _versionRow(
                label: tr('settings.webui_label'),
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
                    label: Text(tr('settings.ladda_ner'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    // Låst tills bunten laddats ner OCH verifierats (hash + signatur).
                    onPressed: (!_fwVerified || _fwApplying) ? null : () => _applyFirewallUpdate(provider),
                    icon: _fwApplying
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upgrade, size: 16),
                    label: Text(tr('settings.uppgradera'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
              Divider(color: AppColors.textFaint, height: 24),
              _versionRow(
                label: tr('settings.desktop_label'),
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
                    label: Text(tr('settings.ladda_ner'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _desktopVerified ? () => _applyDesktopUpdate() : null,
                    icon: const Icon(Icons.upgrade, size: 16),
                    label: Text(tr('settings.uppgradera'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
                  ),
                  if (_desktopVerified) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.verified, color: Colors.tealAccent, size: 18),
                  ],
                ],
              ),
            ],
            Divider(color: AppColors.textFaint, height: 24),
            Row(
              children: [
                const Icon(Icons.history, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 8),
                Text(tr('settings.tidigare_versioner'), style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: _loadingRetainedVersions
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.refresh, size: 16, color: AppColors.textMuted),
                  onPressed: _loadingRetainedVersions ? null : () => _loadRetainedVersions(provider),
                ),
              ],
            ),
            Text(
              tr('settings.retained_versions_body'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 6),
            if (_retainedVersions == null || _retainedVersions!.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(tr('settings.inga_tidigare_versioner_sparade_annu'), style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
              )
            else
              ..._retainedVersions!.map((v) {
                final version = v['version']?.toString() ?? '?';
                final archivedAt = v['archived_at']?.toString();
                final isCurrent = version == _retainedCurrentVersion;
                final isTarget = _rollbackInProgress && _rollbackTargetVersion == version;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(version, style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Text(
                          archivedAt != null ? trp('settings.saved_at', {'date': formatServerTime(archivedAt)}) : '',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ),
                      if (isCurrent)
                        Text(tr('settings.kors_nu'), style: TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold))
                      else
                        OutlinedButton.icon(
                          onPressed: _rollbackInProgress ? null : () => _rollbackToVersion(provider, version),
                          icon: isTarget
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.restore, size: 14),
                          label: Text(tr('settings.aterstall'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.orangeAccent, side: const BorderSide(color: Colors.orangeAccent)),
                        ),
                    ],
                  ),
                );
              }),
            if (_updateMessage != null) ...[
              const SizedBox(height: 10),
              Text(_updateMessage!, style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  /// Konfigurationshistorik — de tre senast bekräftade konfigurationerna.
  /// Skild från "Tidigare versioner" i uppdateringskortet: det gäller
  /// agentens programvara, det här gäller regelverket. Safe Apply räcker
  /// bara i stunden; upptäcker man felet dagen efter finns det inget att
  /// backa till utan den här listan.
  Widget _buildConfigHistoryCard(ConfigProvider provider) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_toggle_off, color: Colors.cyanAccent, size: 22),
                const SizedBox(width: 10),
                Text(tr('settings.config_history.title'),
                    style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_currentConfigRevision != null)
                  Text(trp('settings.config_history.current_revision', {'revision': '$_currentConfigRevision'}),
                      style: const TextStyle(color: Colors.tealAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: _loadingConfigHistory
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.refresh, size: 16, color: AppColors.textMuted),
                  onPressed: _loadingConfigHistory ? null : () => _loadConfigHistory(provider),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(tr('settings.config_history.body'), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 10),
            if (_configHistory == null || _configHistory!.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(tr('settings.config_history.empty'),
                    style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
              )
            else
              ..._configHistory!.map((entry) {
                final id = entry['id']?.toString() ?? '';
                final revision = entry['revision']?.toString() ?? '?';
                final archivedAt = entry['archived_at']?.toString();
                final busy = _restoringConfigId == id;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(trp('settings.config_history.revision', {'revision': revision}),
                            style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Text(
                          archivedAt != null ? trp('settings.saved_at', {'date': formatServerTime(archivedAt)}) : '',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _restoringConfigId != null ? null : () => _restoreConfigFromHistory(provider, entry),
                        icon: busy
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.restore_page, size: 14),
                        label: Text(tr('settings.config_history.load'),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orangeAccent, side: const BorderSide(color: Colors.orangeAccent)),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupRestoreCard(ConfigProvider provider) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.backup_outlined, color: Colors.cyanAccent, size: 22),
                SizedBox(width: 10),
                Text(tr('settings.backup_aterstallning'), style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 6),
            Text(tr('settings.backupen_innehaller_konfigurationen_och_alla_nycklar'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Text(tr('settings.skapa_backup'), style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _backupPassphraseController,
                    obscureText: _obscureBackupPassphrase,
                    // Utan onChanged byggs vyn aldrig om medan man skriver, så
                    // knappens isEmpty-villkor omvärderades inte och den förblev
                    // släckt. Att klicka på ögat råkade anropa setState och
                    // "fixade" det — därav den förvirrande buggen.
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: AppColors.text, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: tr('settings.losenfras_for_backupen'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureBackupPassphrase ? Icons.visibility : Icons.visibility_off, size: 18, color: AppColors.textMuted),
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
                  label: Text(tr('settings.skapa_backup'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                              content: Text(result.backupB64 != null ? tr('settings.backup_created') : (result.error ?? tr('settings.backup_failed'))),
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
                  color: AppColors.bg,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(_backupResultController.text, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.greenAccent)),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.save_alt, size: 14, color: Colors.cyanAccent),
                      label: Text(tr('settings.spara_till_fil'),
                          style: const TextStyle(fontSize: 11, color: Colors.cyanAccent)),
                      onPressed: _saveBackupToFile,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.copy, size: 14, color: Colors.cyanAccent),
                      label: Text(tr('settings.kopiera'), style: TextStyle(fontSize: 11, color: Colors.cyanAccent)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _backupResultController.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr('settings.backup_kopierad_till_urklipp')), backgroundColor: Colors.teal),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            Divider(color: AppColors.divider, height: 32),
            Text(tr('settings.aterstall_fran_backup'), style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(tr('settings.brandvaggen_startar_om_automatiskt_vid_lyckad'),
              style: TextStyle(color: Colors.amberAccent, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.folder_open, size: 14),
                label: Text(tr('settings.las_fran_fil'), style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent)),
                onPressed: _loadBackupFromFile,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _restoreB64Controller,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: AppColors.text, fontSize: 11, fontFamily: 'monospace'),
              decoration: InputDecoration(labelText: tr('settings.klistra_in_backup_text'), border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _restorePassphraseController,
                    obscureText: true,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: AppColors.text, fontSize: 12),
                    decoration: InputDecoration(labelText: tr('settings.losenfras'), border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: _isRestoring
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.restore, size: 16),
                  label: Text(tr('settings.aterstall'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                              content: Text(err ?? tr('settings.restore_sent')),
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

  /// Backupfilens ändelse. Egen ändelse i stället för .txt, så filen går att
  /// känna igen och filväljaren kan filtrera på den vid återställning.
  static const _backupExtension = 'shb';

  /// Sparar backupen till fil.
  ///
  /// Innehållet är den redan krypterade base64-strängen — samma sträng som
  /// visas i rutan. Textrutan är kvar: den behövs när man vill klistra in
  /// backupen någon annanstans, och den är det enda som fungerar om
  /// filväljaren inte går att öppna.
  Future<void> _saveBackupToFile() async {
    final content = _backupResultController.text;
    if (content.isEmpty) return;

    final now = DateTime.now();
    final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final suggested = 'security-harbor-backup_$stamp.$_backupExtension';

    try {
      final location = await getSaveLocation(
        suggestedName: suggested,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Security Harbor backup', extensions: [_backupExtension]),
        ],
      );
      if (location == null) return; // användaren avbröt
      final file = XFile.fromData(
        Uint8List.fromList(utf8.encode(content)),
        mimeType: 'application/octet-stream',
        name: suggested,
      );
      await file.saveTo(location.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trp('settings.backup_sparad_till', {'path': location.path})),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${tr('settings.spara_misslyckades')}: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  /// Läser en backupfil in i textrutan.
  ///
  /// Fyller BARA i rutan — återställningen körs fortfarande av den vanliga
  /// knappen, med lösenfras. Att låta ett filval starta en återställning
  /// direkt vore alldeles för lätt att göra av misstag: en återställning
  /// skriver över hela konfigurationen och startar om brandväggen.
  Future<void> _loadBackupFromFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Security Harbor backup', extensions: [_backupExtension]),
          const XTypeGroup(label: 'Alla filer', extensions: ['*']),
        ],
      );
      if (file == null) return; // användaren avbröt
      final content = (await file.readAsString()).trim();
      if (!mounted) return;
      setState(() => _restoreB64Controller.text = content);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trp('settings.backup_last_fran', {'name': file.name})),
        backgroundColor: Colors.teal,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${tr('settings.kunde_inte_lasa_filen')}: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildFactoryResetCard(ConfigProvider provider) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: Colors.redAccent, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.redAccent, size: 22),
                SizedBox(width: 10),
                Text(tr('settings.fabriksaterstallning'), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 6),
            Text(tr('settings.tar_bort_all_konfiguration_alla_nycklar'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _factoryResetPasswordController,
              obscureText: true,
              style: TextStyle(color: AppColors.text, fontSize: 12),
              decoration: InputDecoration(labelText: tr('settings.ditt_nuvarande_losenord_kravs'), border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: _factoryResetConfirmed,
                  activeColor: Colors.redAccent,
                  onChanged: (v) => setState(() => _factoryResetConfirmed = v ?? false),
                ),
                Expanded(
                  child: Text(tr('settings.jag_forstar_att_detta_raderar_all'), style: TextStyle(color: AppColors.text, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: _isFactoryResetting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_forever, size: 16),
              label: Text(tr('settings.fabriksaterstall_brandvaggen'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                          content: Text(err ?? tr('settings.factory_reset_sent')),
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
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group, color: Colors.cyanAccent, size: 22),
                const SizedBox(width: 10),
                Text(tr('settings.anvandare'), style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 15)),
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
              Text(tr('settings.inga_anvandare_inlasta'), style: TextStyle(color: AppColors.textFaint, fontSize: 12))
            else
              ..._users.map((u) => ListTile(
                    dense: true,
                    leading: Icon(u['role'] == 'admin' ? Icons.admin_panel_settings : Icons.visibility, color: Colors.cyanAccent, size: 18),
                    title: Text(u['username'] ?? '', style: TextStyle(color: AppColors.text, fontSize: 12)),
                    subtitle: Text(u['role'] ?? '', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.lock_reset, size: 16, color: Colors.amber),
                          tooltip: tr('settings.aterstall_losenord'),
                          onPressed: () => _showResetPasswordDialog(provider, u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                          tooltip: tr('settings.ta_bort_anvandare'),
                          onPressed: () async {
                            final err = await provider.api.deleteUser(u['id']);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(err ?? tr('settings.user_deleted')),
                                backgroundColor: err == null ? Colors.green : Colors.red,
                              ),
                            );
                            if (err == null) _loadUsers();
                          },
                        ),
                      ],
                    ),
                  )),
            Divider(color: AppColors.divider, height: 32),
            Text(tr('settings.skapa_ny_anvandare'), style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newUserController,
                    style: TextStyle(color: AppColors.text, fontSize: 12),
                    decoration: InputDecoration(labelText: tr('settings.anvandarnamn'), border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _newUserPwController,
                    obscureText: true,
                    style: TextStyle(color: AppColors.text, fontSize: 12),
                    decoration: InputDecoration(labelText: tr('settings.losenord_minst_8_tecken'), border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _newUserRole,
                  dropdownColor: AppColors.surface,
                  style: TextStyle(color: AppColors.text, fontSize: 12),
                  items: [
                    DropdownMenuItem(value: 'viewer', child: Text(tr('settings.viewer'))),
                    DropdownMenuItem(value: 'admin', child: Text(tr('settings.admin'))),
                  ],
                  onChanged: (v) => setState(() => _newUserRole = v ?? 'viewer'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add, size: 16),
              label: Text(tr('settings.skapa_anvandare'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                    content: Text(err ?? tr('settings.user_created')),
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
        backgroundColor: AppColors.surface,
        title: Text(trp('settings.reset_password_for', {'user': user['username']}), style: TextStyle(color: AppColors.text, fontSize: 14)),
        content: TextField(
          controller: pwController,
          obscureText: true,
          style: TextStyle(color: AppColors.text, fontSize: 12),
          decoration: InputDecoration(labelText: tr('settings.nytt_losenord_minst_8_tecken'), border: OutlineInputBorder(), isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('settings.avbryt'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () async {
              final err = await provider.api.resetUserPassword(user['id'], pwController.text);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(err ?? tr('settings.password_reset')),
                  backgroundColor: err == null ? Colors.green : Colors.red,
                ),
              );
            },
            child: Text(tr('settings.aterstall')),
          ),
        ],
      ),
    );
  }
}
