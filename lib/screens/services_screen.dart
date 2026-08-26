import 'dart:async';
import '../theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../localization.dart';

/// Tjänstepanel — visar systemd-status för samtliga tjänster agenten
/// hanterar (Unbound, Kea DHCP, Suricata, HAProxy, OpenVPN, rsyslog, samt
/// agenten själv) och låter en administratör starta om var och en
/// individuellt. Tillkom 2026-08-24 efter en live-incident där Suricata
/// fastnade i ett trasigt läge (se agentens pkg/api/services.go och
/// pkg/engine/engine.go) — en administratör hade då ingen egen väg att
/// bara starta om den enskilda tjänsten utan att felsöka på
/// kommandoraden.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<ServiceStatusModel> _services = [];
  bool _loading = false;
  String? _restartingId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    if (!provider.isAuthenticated) return;
    if (_restartingId != null) return; // Rör inte listan mitt i en omstart.
    setState(() => _loading = true);
    final services = await provider.api.getServicesStatus();
    if (!mounted) return;
    setState(() {
      _services = services;
      _loading = false;
    });
  }

  Color _statusColor(ServiceStatusModel s) {
    switch (s.active) {
      case 'active':
        return AppColors.ok;
      case 'activating':
      case 'reloading':
        return AppColors.warn;
      case 'failed':
        return AppColors.danger;
      case 'inactive':
        return AppColors.textMuted;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(ServiceStatusModel s) {
    switch (s.active) {
      case 'active':
        return tr('services.status_active');
      case 'activating':
        return tr('services.status_activating');
      case 'reloading':
        return tr('services.status_reloading');
      case 'failed':
        return tr('services.status_failed');
      case 'inactive':
        return tr('services.status_inactive');
      default:
        return s.active;
    }
  }

  IconData _statusIcon(ServiceStatusModel s) {
    switch (s.active) {
      case 'active':
        return Icons.check_circle;
      case 'activating':
      case 'reloading':
        return Icons.hourglass_top;
      case 'failed':
        return Icons.error;
      default:
        return Icons.pause_circle_outline;
    }
  }

  Future<void> _restart(BuildContext context, ConfigProvider provider, ServiceStatusModel s) async {
    // Agentens egen omstart kopplar ner sessionen — administratören ska
    // veta det INNAN de trycker, inte upptäcka det av att GUI:t plötsligt
    // slutar svara.
    final isSelf = s.id == 'agent';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(trp('services.restart_confirm_title', {'name': s.name}), style: TextStyle(color: AppColors.text, fontSize: 14)),
        content: Text(
          isSelf ? tr('services.restart_confirm_self') : tr('services.restart_confirm_other'),
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(tr('services.avbryt'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(tr('services.starta_om')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _restartingId = s.id);

    if (isSelf) {
      // Fyra i rad: skicka begäran, men vänta INTE på ett svar som aldrig
      // kommer på ett meningsfullt sätt (anslutningen bryts när processen
      // dör) — logga bara ut lokalt efter en kort paus så att begäran hann
      // nå fram.
      unawaited(provider.api.restartService(s.id));
      await Future.delayed(const Duration(milliseconds: 800));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('services.agenten_startar_om_logga_in_igen')), backgroundColor: Colors.orange),
      );
      await provider.logout();
      return;
    }

    final err = await provider.api.restartService(s.id);
    if (!mounted) return;
    setState(() => _restartingId = null);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err == null ? trp('services.restarted', {'name': s.name}) : trp('services.restart_failed', {'err': err})),
          backgroundColor: err == null ? Colors.teal : Colors.red,
        ),
      );
    }
    await _poll();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);

    return Container(
      color: AppColors.bg,
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surface,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.miscellaneous_services, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(tr('services.tjanster'), style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.refresh, size: 18, color: _loading ? AppColors.textFaint : AppColors.ok),
                  tooltip: tr('services.uppdatera_status'),
                  onPressed: _loading ? null : _poll,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.bg,
            child: Text(
              tr('services.status_note'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
          Expanded(
            child: _services.isEmpty
                ? Center(
                    child: _loading
                        ? CircularProgressIndicator(color: AppColors.accent)
                        : Text(tr('services.kunde_inte_hamta_tjanststatus'), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _services.length,
                    itemBuilder: (context, idx) => _buildServiceCard(context, provider, _services[idx]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, ConfigProvider provider, ServiceStatusModel s) {
    final restarting = _restartingId == s.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: s.active == 'failed' ? AppColors.danger.withValues(alpha: 0.5) : AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 320,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon(s), color: _statusColor(s), size: 18),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(s.name, style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold))),
                          // En tjänst kan vara igång i systemd utan att
                          // FUNKTIONEN är påslagen hos oss — rsyslog är
                          // systemets ordinarie logghanterare och körs
                          // alltid, oavsett om vi vidarebefordrar loggar.
                          if (!s.configured) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: AppColors.textFaint),
                              ),
                              child: Text(tr('services.not_configured'),
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      Text(s.description, style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor(s).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _statusColor(s).withValues(alpha: 0.4)),
            ),
            child: Text(
              '${_statusLabel(s)} (${s.sub})',
              style: TextStyle(
                color: s.configured ? _statusColor(s) : AppColors.textFaint,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(s.unit, style: TextStyle(color: AppColors.textFaint, fontSize: 10, fontFamily: 'monospace')),
          OutlinedButton.icon(
            icon: restarting
                ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warn))
                : Icon(Icons.restart_alt, size: 14, color: AppColors.warn),
            label: Text(restarting ? 'Startar om...' : 'Starta om', style: TextStyle(fontSize: 11, color: AppColors.text)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              side: BorderSide(color: AppColors.warn),
            ),
            onPressed: restarting ? null : () => _restart(context, provider, s),
          ),
        ],
      ),
    );
  }
}
