import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

/// Egen sida för DNS-ENHETER: manuella (statiska) DNS-poster och de enheter
/// som registrerats automatiskt via DHCP. Bröts ut från DNS-sidan (som blev
/// för full med resolver- och blocklist-inställningar) 2026-08-22.
class DnsDevicesScreen extends StatefulWidget {
  const DnsDevicesScreen({super.key});

  @override
  State<DnsDevicesScreen> createState() => _DnsDevicesScreenState();
}

class _DnsDevicesScreenState extends State<DnsDevicesScreen> {
  List<DhcpLeaseModel> _leases = [];
  bool _loadingLeases = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadLeases();
  }

  Future<void> _loadLeases() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    setState(() => _loadingLeases = true);
    try {
      final leases = await provider.api.getDhcpLeases();
      if (mounted) {
        setState(() {
          _leases = leases;
          _loadingLeases = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLeases = false);
    }
  }

  DNSConfigModel _current(ConfigProvider provider) {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    return cfg?.dns ?? DNSConfigModel(enabled: false, upstreamServers: ['1.1.1.1', '1.0.0.1']);
  }

  Future<void> _save(ConfigProvider provider, DNSConfigModel dns) async {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return;
    await provider.updateCandidate(cfg.copyWith(dns: dns));
  }

  String _fqdn(String hostname, String localDomain) {
    if (hostname.isEmpty) return '';
    return localDomain.isNotEmpty ? '$hostname.$localDomain' : hostname;
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.devices, color: Colors.cyanAccent, size: 22),
                    SizedBox(width: 10),
                    Text('DNS-enheter', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Uppdatera', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.cyanAccent, side: const BorderSide(color: Colors.cyanAccent)),
                  onPressed: _loadLeases,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildStaticRecordsCard(provider, dns),
            const SizedBox(height: 14),
            _buildAutoRegisteredCard(dns),
          ],
        ),
      ),
    );
  }

  Widget _cardShell({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          border: Border.all(color: const Color(0xFF334155)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: child,
      );

  Widget _buildStaticRecordsCard(ConfigProvider provider, DNSConfigModel dns) {
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Manuella DNS-poster (${dns.staticRecords.length})', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Lägg till post', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                onPressed: () => _showAddStaticRecordDialog(provider, dns),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (dns.staticRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Inga manuella poster tillagda ännu.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ...dns.staticRecords.map((rec) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    border: Border.all(color: const Color(0xFF334155)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.dns, size: 14, color: Colors.tealAccent),
                      const SizedBox(width: 10),
                      // Manuella poster visas EXAKT som angivna (inget lokalt
                      // suffix hängs på — vill man ha det skriver man hela
                      // namnet själv). Bara DHCP-auto-poster får LocalDomain.
                      Expanded(child: Text(rec.hostname, style: const TextStyle(color: Colors.white, fontSize: 12))),
                      Expanded(child: Text(rec.ip, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace'))),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        onPressed: () {
                          final updated = dns.staticRecords.where((r) => r != rec).toList();
                          _save(provider, dns.copyWith(staticRecords: updated));
                        },
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildAutoRegisteredCard(DNSConfigModel dns) {
    // Endast leases med värdnamn kan registreras i DNS.
    final named = _leases.where((l) => l.hostname.trim().isNotEmpty).toList()
      ..sort((a, b) => a.hostname.toLowerCase().compareTo(b.hostname.toLowerCase()));
    final filtered = _search.isEmpty
        ? named
        : named.where((l) {
            final q = _search.toLowerCase();
            return l.hostname.toLowerCase().contains(q) || l.ip.toLowerCase().contains(q) || l.mac.toLowerCase().contains(q);
          }).toList();

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Automatiskt registrerade enheter (${named.length})', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              SizedBox(
                width: 200,
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Sök namn / IP / MAC',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                    prefixIcon: Icon(Icons.search, size: 14, color: Colors.grey),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (!dns.dhcpHostnameRegistration)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Automatisk registrering är avstängd — enheterna nedan listas men slås inte upp i DNS förrän du slår på den ovan.',
                  style: TextStyle(color: Colors.amber, fontSize: 10)),
            ),
          const SizedBox(height: 6),
          if (_loadingLeases)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Inga DHCP-enheter med värdnamn hittades.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              color: const Color(0xFF0F172A),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('DNS-namn', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('IP', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Gränssnitt', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Zon', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            ...filtered.map((l) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF334155)))),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(_fqdn(l.hostname, dns.localDomain), style: const TextStyle(color: Colors.white, fontSize: 12))),
                      Expanded(flex: 2, child: Text(l.ip, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'monospace'))),
                      Expanded(flex: 2, child: Text(l.interfaceDevice, style: const TextStyle(color: Colors.grey, fontSize: 11))),
                      Expanded(flex: 2, child: Text(l.zone, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11))),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  void _showAddStaticRecordDialog(ConfigProvider provider, DNSConfigModel dns) {
    final hostnameCtrl = TextEditingController();
    final ipCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Container(
          width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 400.0),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lägg till DNS-post', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _labeledField('Namn (exakt, valfri domän)', hostnameCtrl, hint: 't.ex. server1.example.com eller server1'),
              const SizedBox(height: 12),
              _labeledField('IP-adress', ipCtrl, hint: '192.168.1.50'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt', style: TextStyle(fontSize: 12))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                    child: const Text('Lägg till', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final hostname = hostnameCtrl.text.trim();
                      final ip = ipCtrl.text.trim();
                      if (hostname.isEmpty || ip.isEmpty) return;
                      final newRec = DNSStaticRecordModel(hostname: hostname, ip: ip);
                      _save(provider, dns.copyWith(staticRecords: [...dns.staticRecords, newRec]));
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labeledField(String label, TextEditingController ctrl, {String? hint}) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 11),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 11),
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }
}
