import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

class DnsScreen extends StatefulWidget {
  const DnsScreen({super.key});

  @override
  State<DnsScreen> createState() => _DnsScreenState();
}

class _DnsScreenState extends State<DnsScreen> {
  bool _refreshing = false;

  DNSConfigModel _current(ConfigProvider provider) {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    return cfg?.dns ?? DNSConfigModel(enabled: false, upstreamServers: ['1.1.1.1', '1.0.0.1']);
  }

  Future<void> _save(ConfigProvider provider, DNSConfigModel dns) async {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return;
    await provider.updateCandidate(cfg.copyWith(dns: dns));
  }

  Future<void> _refreshBlocklist(ConfigProvider provider) async {
    setState(() => _refreshing = true);
    final ok = await provider.api.refreshDNSBlocklist();
    await provider.fetchAll();
    if (mounted) {
      setState(() => _refreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Domänblocklistan uppdaterad' : 'Misslyckades uppdatera blocklistan — se felmeddelande nedan'),
          backgroundColor: ok ? Colors.teal : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final dns = _current(provider);

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
                Icon(Icons.dns, color: Colors.cyanAccent, size: 22),
                SizedBox(width: 10),
                Text('DNS & DNS-filtrering', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            _buildResolverCard(provider, dns),
            const SizedBox(height: 14),
            _buildBlocklistCard(provider, dns),
          ],
        ),
      ),
    );
  }

  Widget _buildResolverCard(ConfigProvider provider, DNSConfigModel dns) {
    final upstreamCtrl = TextEditingController(text: dns.upstreamServers.join(', '));
    final dotHostCtrl = TextEditingController(text: dns.dotHostname.isEmpty ? 'cloudflare-dns.com' : dns.dotHostname);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lokal DNS-resolver', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Switch(
                    value: dns.enabled,
                    activeThumbColor: Colors.tealAccent,
                    onChanged: (v) => _save(provider, dns.copyWith(enabled: v)),
                  ),
                  Text(dns.enabled ? 'Aktiverad' : 'Inaktiverad', style: TextStyle(color: dns.enabled ? Colors.tealAccent : Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _labeledField('Upstream DNS-servrar (komma-separerade)', upstreamCtrl, hint: '1.1.1.1, 1.0.0.1'),
          const SizedBox(height: 10),
          Row(
            children: [
              Switch(
                value: dns.dotEnabled,
                activeThumbColor: Colors.tealAccent,
                onChanged: (v) => _save(provider, dns.copyWith(dotEnabled: v)),
              ),
              const SizedBox(width: 6),
              const Text('DNS-over-TLS (DoT) mot upstream', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          if (dns.dotEnabled) ...[
            const SizedBox(height: 6),
            _labeledField('TLS-hostnamn för verifiering', dotHostCtrl, hint: 'cloudflare-dns.com'),
          ],
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 14),
            label: const Text('Spara', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () {
              final upstream = upstreamCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              _save(provider, dns.copyWith(upstreamServers: upstream, dotHostname: dotHostCtrl.text.trim()));
            },
          ),
          const SizedBox(height: 6),
          const Text(
            'Kom ihåg att applicera & bekräfta ändringarna för att öppna DNS-porten (53) mot LAN och starta resolvern.',
            style: TextStyle(color: Colors.amberAccent, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocklistCard(ConfigProvider provider, DNSConfigModel dns) {
    final urlCtrl = TextEditingController(text: dns.blocklistUrl);
    final refreshHoursCtrl = TextEditingController(text: dns.blocklistRefreshHours.toString());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Domänblockering', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Switch(
                    value: dns.blocklistEnabled,
                    activeThumbColor: Colors.tealAccent,
                    onChanged: (v) => _save(provider, dns.copyWith(blocklistEnabled: v)),
                  ),
                  Text(dns.blocklistEnabled ? 'Aktiverad' : 'Inaktiverad', style: TextStyle(color: dns.blocklistEnabled ? Colors.tealAccent : Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Källa', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: dns.blocklistKind,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'stevenblack_hosts', child: Text('StevenBlack hosts (ads/malware/tracking)')),
              DropdownMenuItem(value: 'custom_url', child: Text('Anpassad URL (en domän per rad)')),
            ],
            onChanged: (v) {
              if (v != null) _save(provider, dns.copyWith(blocklistKind: v));
            },
          ),
          if (dns.blocklistKind == 'custom_url') ...[
            const SizedBox(height: 10),
            _labeledField('URL', urlCtrl, hint: 'https://exempel.se/domains.txt'),
          ],
          const SizedBox(height: 10),
          _labeledField('Uppdateringsintervall (timmar)', refreshHoursCtrl, hint: '24'),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 14),
                label: const Text('Spara', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                onPressed: () {
                  _save(provider, dns.copyWith(blocklistUrl: urlCtrl.text.trim(), blocklistRefreshHours: int.tryParse(refreshHoursCtrl.text.trim()) ?? 24));
                },
              ),
              const SizedBox(width: 10),
              _refreshing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent))
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 14, color: Colors.tealAccent),
                      label: const Text('Uppdatera nu', style: TextStyle(fontSize: 11, color: Colors.tealAccent)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.tealAccent)),
                      onPressed: () => _refreshBlocklist(provider),
                    ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _statusChip(Icons.list_alt, '${dns.blocklistEntryCount} blockerade domäner', Colors.grey),
              _statusChip(Icons.update, dns.blocklistLastUpdated.isEmpty ? 'Aldrig uppdaterad' : 'Uppdaterad: ${_shortTime(dns.blocklistLastUpdated)}', Colors.grey),
              if (dns.blocklistLastError.isNotEmpty) _statusChip(Icons.error_outline, 'Fel: ${dns.blocklistLastError}', Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 10, color: color)),
      ],
    );
  }

  String _shortTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Widget _labeledField(String label, TextEditingController ctrl, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 34,
          child: TextField(
            controller: ctrl,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
