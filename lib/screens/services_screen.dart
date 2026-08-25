import 'dart:async';
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
        return Colors.tealAccent;
      case 'activating':
      case 'reloading':
        return Colors.amber;
      case 'failed':
        return Colors.redAccent;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.grey;
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
        backgroundColor: const Color(0xFF1E293B),
        title: Text(trp('services.restart_confirm_title', {'name': s.name}), style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: Text(
          isSelf ? tr('services.restart_confirm_self') : tr('services.restart_confirm_other'),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(tr('services.avbryt'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
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
      color: const Color(0xFF0F172A),
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.miscellaneous_services, color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(tr('services.tjanster'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.refresh, size: 18, color: _loading ? Colors.white24 : Colors.tealAccent),
                  tooltip: tr('services.uppdatera_status'),
                  onPressed: _loading ? null : _poll,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF0F172A),
            child: Text(
              tr('services.status_note'),
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
          Expanded(
            child: _services.isEmpty
                ? Center(
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.cyanAccent)
                        : Text(tr('services.kunde_inte_hamta_tjanststatus'), style: TextStyle(color: Colors.grey, fontSize: 12)),
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
        color: const Color(0xFF1E293B),
        border: Border.all(color: s.active == 'failed' ? Colors.redAccent.withValues(alpha: 0.5) : const Color(0xFF334155)),
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
                      Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(s.description, style: const TextStyle(color: Colors.grey, fontSize: 10)),
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
              style: TextStyle(color: _statusColor(s), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          Text(s.unit, style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
          OutlinedButton.icon(
            icon: restarting
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent))
                : const Icon(Icons.restart_alt, size: 14, color: Colors.amberAccent),
            label: Text(restarting ? 'Startar om...' : 'Starta om', style: const TextStyle(fontSize: 11, color: Colors.white)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              side: const BorderSide(color: Colors.amberAccent),
            ),
            onPressed: restarting ? null : () => _restart(context, provider, s),
          ),
        ],
      ),
    );
  }
}
