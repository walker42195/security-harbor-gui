import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../theme.dart';

/// Inställningskort för e-postnotifieringar (Fas 14). Fristående: läser/sparar
/// via /api/v1/notifications (utanför candidate/apply-flödet), eftersom notiser
/// inte påverkar brandväggsregelverket och SMTP-lösenordet lagras krypterat
/// separat på brandväggen.
class NotificationsCard extends StatefulWidget {
  const NotificationsCard({super.key});

  @override
  State<NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends State<NotificationsCard> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '587');
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  String _security = 'starttls';
  bool _enabled = false;
  bool _notifyService = true;
  bool _notifyAutoBlock = true;
  bool _hasPassword = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in [_host, _port, _user, _pass, _from, _to]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final api = Provider.of<ConfigProvider>(context, listen: false).api;
    final cfg = await api.getNotifications();
    if (!mounted) return;
    setState(() {
      if (cfg != null) {
        _enabled = cfg['enabled'] == true;
        _host.text = (cfg['smtp_host'] ?? '').toString();
        _port.text = (cfg['smtp_port'] ?? 587).toString();
        _user.text = (cfg['smtp_user'] ?? '').toString();
        _from.text = (cfg['from_addr'] ?? '').toString();
        _to.text = (cfg['to_addr'] ?? '').toString();
        _security = (cfg['security'] ?? 'starttls').toString();
        _notifyService = cfg['notify_service_failure'] != false;
        _notifyAutoBlock = cfg['notify_auto_block'] != false;
        _hasPassword = cfg['has_password'] == true;
      }
      _loading = false;
    });
  }

  Map<String, dynamic> _payload() => {
        'enabled': _enabled,
        'smtp_host': _host.text.trim(),
        'smtp_port': int.tryParse(_port.text.trim()) ?? 587,
        'smtp_user': _user.text.trim(),
        // Tomt lösen => backend behåller det sparade.
        'smtp_pass': _pass.text,
        'from_addr': _from.text.trim(),
        'to_addr': _to.text.trim(),
        'security': _security,
        'notify_service_failure': _notifyService,
        'notify_auto_block': _notifyAutoBlock,
      };

  void _snack(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.ok : AppColors.danger,
    ));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final api = Provider.of<ConfigProvider>(context, listen: false).api;
    final err = await api.saveNotifications(_payload());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (err == null && _pass.text.isNotEmpty) _hasPassword = true;
      if (err == null) _pass.clear();
    });
    _snack(err == null ? 'Notifieringar sparade' : 'Kunde inte spara: $err', err == null);
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    final api = Provider.of<ConfigProvider>(context, listen: false).api;
    final err = await api.testNotifications(_payload());
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(err == null ? 'Testmejl skickat — kolla inkorgen' : 'Test misslyckades: $err', err == null);
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _loading
            ? const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator()))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, color: AppColors.accent, size: 22),
                      const SizedBox(width: 10),
                      Text('E-postnotifieringar', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Switch(
                        value: _enabled,
                        activeThumbColor: AppColors.ok,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Skicka e-post när en tjänst hamnar i fel-läge eller när ett IP blockeras automatiskt (IDS/VPN).',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(flex: 2, child: TextField(controller: _host, style: TextStyle(color: AppColors.text, fontSize: 12), decoration: _dec('SMTP-server'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _port, keyboardType: TextInputType.number, style: TextStyle(color: AppColors.text, fontSize: 12), decoration: _dec('Port'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _security,
                          isDense: true,
                          decoration: _dec('Kryptering'),
                          dropdownColor: AppColors.surface,
                          style: TextStyle(color: AppColors.text, fontSize: 12),
                          items: const [
                            DropdownMenuItem(value: 'starttls', child: Text('STARTTLS (587)')),
                            DropdownMenuItem(value: 'tls', child: Text('SSL/TLS (465)')),
                            DropdownMenuItem(value: 'none', child: Text('Ingen (25)')),
                          ],
                          onChanged: (v) => setState(() => _security = v ?? 'starttls'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _user, style: TextStyle(color: AppColors.text, fontSize: 12), decoration: _dec('Användarnamn (valfritt)'))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _pass,
                          obscureText: true,
                          style: TextStyle(color: AppColors.text, fontSize: 12),
                          decoration: _dec(_hasPassword ? 'Lösenord (sparat — lämna tomt för oförändrat)' : 'Lösenord (valfritt)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _from, style: TextStyle(color: AppColors.text, fontSize: 12), decoration: _dec('Avsändaradress (From)'))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _to, style: TextStyle(color: AppColors.text, fontSize: 12), decoration: _dec('Mottagare (To)'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.ok,
                    value: _notifyService,
                    onChanged: (v) => setState(() => _notifyService = v ?? true),
                    title: Text('Meddela när en tjänst hamnar i fel-läge', style: TextStyle(color: AppColors.text, fontSize: 12)),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.ok,
                    value: _notifyAutoBlock,
                    onChanged: (v) => setState(() => _notifyAutoBlock = v ?? true),
                    title: Text('Meddela när ett IP auto-blockeras (IDS/VPN)', style: TextStyle(color: AppColors.text, fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Spara'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _test,
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Skicka testmejl'),
                      ),
                      if (_busy) ...[
                        const SizedBox(width: 12),
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
