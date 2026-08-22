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
          content: Text(ok ? '"${src.name}" uppdaterad' : 'Misslyckades uppdatera "${src.name}" — se felmeddelande på källan'),
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
          width: 480,
          height: 560,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Blockerade domäner — ${src.name} (${domains.length})',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: domains.isEmpty
                    ? const Center(child: Text('Inga domäner hämtade ännu.', style: TextStyle(color: Colors.grey, fontSize: 12)))
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
            _buildDevicesHint(),
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
          const Text('Upplösningsläge', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
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
                    title: const Text('Vidarebefordra till upstream-servrar', style: TextStyle(color: Colors.white, fontSize: 12)),
                    value: false,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.tealAccent,
                    title: const Text('Slå upp själv mot rot-servrarna (rekursiv)', style: TextStyle(color: Colors.white, fontSize: 12)),
                    value: true,
                  ),
                ),
              ],
            ),
          ),
          if (!dns.recursive) ...[
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
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'I rekursivt läge slår servern upp domäner direkt mot DNS-rotens namnservrar istället för att fråga en upstream-leverantör (t.ex. Cloudflare/Google).',
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
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

  Widget _buildDevicesHint() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: const [
          Icon(Icons.devices, color: Colors.cyanAccent, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Manuella DNS-poster och automatiskt registrerade DHCP-enheter finns nu på den egna sidan "DNS-enheter" i vänstermenyn.',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
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
                label: const Text('Lägg till blocklista', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                onPressed: () => _showAddBlocklistDialog(provider, dns),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Flera blocklistor kan vara aktiva samtidigt — de slås ihop till en gemensam lista i Unbound.',
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
          const SizedBox(height: 10),
          if (dns.blocklists.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Inga domänblocklistor tillagda ännu.', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                  tooltip: 'Uppdatera nu',
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
                tooltip: 'Ta bort',
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
            width: 460,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lägg till domänblocklista', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _labeledField('Namn', nameCtrl),
                const SizedBox(height: 12),
                const Text('Källtyp', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'stevenblack_hosts', child: Text('StevenBlack hosts (ads/malware/tracking)')),
                    DropdownMenuItem(value: 'custom_domain_url', child: Text('Anpassad URL (en domän per rad)')),
                  ],
                  onChanged: (v) => setDialogState(() {
                    kind = v ?? kind;
                    if (kind == 'stevenblack_hosts' && nameCtrl.text.trim().isEmpty) nameCtrl.text = 'StevenBlack hosts';
                  }),
                ),
                if (kind == 'custom_domain_url') ...[
                  const SizedBox(height: 12),
                  _labeledField('URL', urlCtrl, hint: 'https://exempel.se/domains.txt'),
                ],
                const SizedBox(height: 12),
                _labeledField('Uppdateringsintervall (timmar)', refreshHoursCtrl, hint: '24'),
                const SizedBox(height: 6),
                const Text(
                  'Listan hämtas automatiskt enligt intervallet ovan. Innehållet syns i vyn efter första hämtningen.',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 10),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                      child: const Text('Skapa & hämta nu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
        return 'Anpassad URL';
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
