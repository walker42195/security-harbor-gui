import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../localization.dart';

class DnsScreen extends StatefulWidget {
  const DnsScreen({super.key});

  @override
  State<DnsScreen> createState() => _DnsScreenState();
}

class _DnsScreenState extends State<DnsScreen> {
  final Set<String> _refreshingIds = {};

  DNSConfigModel _current(ConfigProvider provider) {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    return cfg?.dns ?? DNSConfigModel(enabled: false, upstreamServers: ['1.1.1.1', '1.0.0.1']);
  }

  Future<void> _save(ConfigProvider provider, DNSConfigModel dns) async {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return;
    await provider.updateCandidate(cfg.copyWith(dns: dns));
  }

  Future<void> _refreshBlocklist(ConfigProvider provider, DNSConfigModel dns, DNSBlocklistSourceModel src) async {
    setState(() => _refreshingIds.add(src.id));
    final ok = await provider.api.refreshDNSBlocklist(src.id);
    await provider.fetchAll();
    if (mounted) {
      setState(() => _refreshingIds.remove(src.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? trp('dns.blocklist_updated', {'name': src.name}) : trp('dns.blocklist_update_failed', {'name': src.name})),
          backgroundColor: ok ? Colors.teal : Colors.red,
        ),
      );
    }
  }

  Future<void> _viewDomains(ConfigProvider provider, DNSBlocklistSourceModel src) async {
    final domains = await provider.api.getDNSBlocklistDomains(src.id);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Container(
          width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 480.0),
          height: 560,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(trp('dns.blocked_domains_title', {'name': src.name, 'count': '${domains.length}'}),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: domains.isEmpty
                    ? Center(child: Text(tr('dns.inga_domaner_hamtade_annu'), style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : Container(
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), border: Border.all(color: const Color(0xFF334155)), borderRadius: BorderRadius.circular(4)),
                        child: ListView.builder(
                          itemCount: domains.length,
                          itemBuilder: (c, i) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            child: Text(domains[i], style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
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
            Row(
              children: [
                Icon(Icons.dns, color: Colors.cyanAccent, size: 22),
                SizedBox(width: 10),
                Text(tr('dns.dns_dns_filtrering'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            _buildResolverCard(provider, dns),
            const SizedBox(height: 14),
            _buildLocalZoneCard(provider, dns),
            const SizedBox(height: 14),
            _buildBlocklistsCard(provider, dns),
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
              Text(tr('dns.lokal_dns_resolver'), style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Switch(
                    value: dns.enabled,
                    activeThumbColor: Colors.tealAccent,
                    onChanged: (v) => _save(provider, dns.copyWith(enabled: v)),
                  ),
                  Text(dns.enabled ? tr('dns.aktiverad') : tr('dns.inaktiverad'), style: TextStyle(color: dns.enabled ? Colors.tealAccent : Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(tr('dns.upplosningslage'), style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          RadioGroup<bool>(
            groupValue: dns.recursive,
            onChanged: (v) => _save(provider, dns.copyWith(recursive: v ?? false)),
            child: Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.tealAccent,
                    title: Text(tr('dns.vidarebefordra_till_upstream_servrar'), style: TextStyle(color: Colors.white, fontSize: 12)),
                    value: false,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.tealAccent,
                    title: Text(tr('dns.sla_upp_sjalv_mot_rot_servrarna'), style: TextStyle(color: Colors.white, fontSize: 12)),
                    value: true,
                  ),
                ),
              ],
            ),
          ),
          if (!dns.recursive) ...[
            const SizedBox(height: 10),
            _labeledField(tr('dns.upstream_label'), upstreamCtrl, hint: '1.1.1.1, 1.0.0.1'),
            const SizedBox(height: 10),
            Row(
              children: [
                Switch(
                  value: dns.dotEnabled,
                  activeThumbColor: Colors.tealAccent,
                  onChanged: (v) => _save(provider, dns.copyWith(dotEnabled: v)),
                ),
                const SizedBox(width: 6),
                Text(tr('dns.dns_over_tls_dot_mot_upstream'), style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
            if (dns.dotEnabled) ...[
              const SizedBox(height: 6),
              _labeledField(tr('dns.tls_hostname_label'), dotHostCtrl, hint: 'cloudflare-dns.com'),
            ],
          ] else ...[
            const SizedBox(height: 6),
            Text(tr('dns.i_rekursivt_lage_slar_servern_upp'),
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 14),
            label: Text(tr('dns.spara'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () {
              final upstream = upstreamCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              _save(provider, dns.copyWith(upstreamServers: upstream, dotHostname: dotHostCtrl.text.trim()));
            },
          ),
          const SizedBox(height: 6),
          Text(tr('dns.kom_ihag_att_applicera_bekrafta_andringarna'),
            style: TextStyle(color: Colors.amberAccent, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalZoneCard(ConfigProvider provider, DNSConfigModel dns) {
    final localDomainCtrl = TextEditingController(text: dns.localDomain);
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
          Text(tr('dns.lokal_dns_zon'), style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            children: [
              Switch(
                value: dns.dhcpHostnameRegistration,
                activeThumbColor: Colors.tealAccent,
                onChanged: (v) => _save(provider, dns.copyWith(dhcpHostnameRegistration: v)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(tr('dns.registrera_dhcp_tilldelade_enheters_vardnamn_automatiskt'), style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _labeledField(tr('dns.lokal_domain_label'), localDomainCtrl, hint: 'lan'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 14),
            label: Text(tr('dns.spara'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () => _save(provider, dns.copyWith(localDomain: localDomainCtrl.text.trim())),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.devices, color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('dns.dns_devices_hint'),
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlocklistsCard(ConfigProvider provider, DNSConfigModel dns) {
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
              Text('Domänblocklistor (${dns.blocklists.length})', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: Text(tr('dns.lagg_till_blocklista'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                onPressed: () => _showAddBlocklistDialog(provider, dns),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(tr('dns.flera_blocklistor_kan_vara_aktiva_samtidigt'),
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
          const SizedBox(height: 10),
          if (dns.blocklists.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(tr('dns.inga_domanblocklistor_tillagda_annu'), style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ...dns.blocklists.map((src) => _buildBlocklistRow(provider, dns, src)),
        ],
      ),
    );
  }

  Widget _buildBlocklistRow(ConfigProvider provider, DNSConfigModel dns, DNSBlocklistSourceModel src) {
    final refreshing = _refreshingIds.contains(src.id);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(src.enabled ? Icons.block : Icons.block_outlined, size: 16, color: src.enabled ? Colors.tealAccent : Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Text(src.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                flex: 2,
                child: Text(_kindLabel(src.kind), style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ),
              TextButton(
                onPressed: () => _viewDomains(provider, src),
                child: Text('${src.entryCount} domäner', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
              ),
              if (refreshing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent)),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.tealAccent),
                  tooltip: tr('dns.uppdatera_nu'),
                  onPressed: () => _refreshBlocklist(provider, dns, src),
                ),
              Switch(
                value: src.enabled,
                activeThumbColor: Colors.tealAccent,
                onChanged: (v) {
                  final updated = dns.blocklists.map((b) => b.id == src.id ? b.copyWith(enabled: v) : b).toList();
                  _save(provider, dns.copyWith(blocklists: updated));
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                tooltip: tr('dns.ta_bort'),
                onPressed: () {
                  final updated = dns.blocklists.where((b) => b.id != src.id).toList();
                  _save(provider, dns.copyWith(blocklists: updated));
                },
              ),
            ],
          ),
          if (src.lastError.isNotEmpty || src.lastUpdated.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 26),
              child: Wrap(
                spacing: 14,
                children: [
                  Text(src.lastUpdated.isEmpty ? 'Aldrig uppdaterad' : 'Uppdaterad: ${_shortTime(src.lastUpdated)}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  if (src.lastError.isNotEmpty) Text('Fel: ${src.lastError}', style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAddBlocklistDialog(ConfigProvider provider, DNSConfigModel dns) {
    final nameCtrl = TextEditingController(text: 'StevenBlack hosts');
    final urlCtrl = TextEditingController();
    final refreshHoursCtrl = TextEditingController(text: '24');
    String kind = 'stevenblack_hosts';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 460.0),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('dns.lagg_till_domanblocklista'), style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _labeledField(tr('dns.namn_label'), nameCtrl),
                const SizedBox(height: 12),
                Text(tr('dns.kalltyp'), style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: 'stevenblack_hosts', child: Text(tr('dns.stevenblack_hosts_ads_malware_tracking'))),
                    DropdownMenuItem(value: 'custom_domain_url', child: Text(tr('dns.anpassad_url_en_doman_per_rad'))),
                  ],
                  onChanged: (v) => setDialogState(() {
                    kind = v ?? kind;
                    if (kind == 'stevenblack_hosts' && nameCtrl.text.trim().isEmpty) nameCtrl.text = 'StevenBlack hosts';
                  }),
                ),
                if (kind == 'custom_domain_url') ...[
                  const SizedBox(height: 12),
                  _labeledField(tr('dns.url_label'), urlCtrl, hint: 'https://exempel.se/domains.txt'),
                ],
                const SizedBox(height: 12),
                _labeledField(tr('dns.uppdateringsintervall_label'), refreshHoursCtrl, hint: '24'),
                const SizedBox(height: 6),
                Text(tr('dns.listan_hamtas_automatiskt_enligt_intervallet_ovan'),
                  style: TextStyle(color: Colors.amberAccent, fontSize: 10),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('dns.avbryt'), style: TextStyle(fontSize: 12))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                      child: Text(tr('dns.skapa_hamta_nu'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final newSrc = DNSBlocklistSourceModel(
                          id: 'dnsbl_${DateTime.now().millisecondsSinceEpoch}',
                          name: nameCtrl.text.trim().isEmpty ? _kindLabel(kind) : nameCtrl.text.trim(),
                          enabled: true,
                          kind: kind,
                          url: urlCtrl.text.trim(),
                          refreshHours: int.tryParse(refreshHoursCtrl.text.trim()) ?? 24,
                        );
                        await _save(provider, dns.copyWith(blocklists: [...dns.blocklists, newSrc]));
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await provider.api.refreshDNSBlocklist(newSrc.id);
                        await provider.fetchAll();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'stevenblack_hosts':
        return 'StevenBlack hosts';
      case 'custom_domain_url':
        return tr('dns.anpassad_url');
      default:
        return kind;
    }
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
