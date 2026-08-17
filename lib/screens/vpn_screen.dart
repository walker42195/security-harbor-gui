import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> {
  Map<String, dynamic>? _serverInfo;
  bool _loadingServerInfo = true;

  @override
  void initState() {
    super.initState();
    _loadServerInfo();
  }

  Future<void> _loadServerInfo() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    final info = await provider.api.getWireGuardServerInfo();
    if (!mounted) return;
    setState(() {
      _serverInfo = info;
      _loadingServerInfo = false;
    });
  }

  WireGuardConfigModel _currentWg(ConfigProvider provider) {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    return cfg?.wireguard ??
        WireGuardConfigModel(enabled: false, listenPort: 51820, address: '10.66.66.1/24', endpoint: '', peers: []);
  }

  Future<void> _saveWireGuard(ConfigProvider provider, WireGuardConfigModel wg) async {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return;
    await provider.updateCandidate(cfg.copyWith(wireguard: wg));
    if (mounted) await _loadServerInfo();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final wg = _currentWg(provider);
    final serverPubKey = _serverInfo?['public_key'] as String? ?? '';

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
                Icon(Icons.vpn_lock, color: Colors.cyanAccent, size: 22),
                SizedBox(width: 10),
                Text('WireGuard VPN', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            _buildServerCard(provider, wg, serverPubKey),
            const SizedBox(height: 14),
            _buildPeersCard(provider, wg),
          ],
        ),
      ),
    );
  }

  Widget _buildServerCard(ConfigProvider provider, WireGuardConfigModel wg, String serverPubKey) {
    final listenPortCtrl = TextEditingController(text: wg.listenPort.toString());
    final addressCtrl = TextEditingController(text: wg.address);
    final endpointCtrl = TextEditingController(text: wg.endpoint);

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
              const Text('Serverinställningar (wg0)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Switch(
                    value: wg.enabled,
                    activeColor: Colors.tealAccent,
                    onChanged: (v) => _saveWireGuard(provider, wg.copyWith(enabled: v)),
                  ),
                  Text(wg.enabled ? 'Aktiverad' : 'Inaktiverad', style: TextStyle(color: wg.enabled ? Colors.tealAccent : Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _labeledField('VPN-nät (server-IP/CIDR)', addressCtrl, hint: '10.66.66.1/24')),
              const SizedBox(width: 10),
              SizedBox(width: 140, child: _labeledField('Lyssningsport (UDP)', listenPortCtrl, hint: '51820')),
            ],
          ),
          const SizedBox(height: 10),
          _labeledField('Publik endpoint (klienter ansluter mot)', endpointCtrl, hint: 't.ex. din-domän.se eller WAN-IP'),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 14),
                label: const Text('Spara serverinställningar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                onPressed: () {
                  final port = int.tryParse(listenPortCtrl.text.trim()) ?? wg.listenPort;
                  _saveWireGuard(
                    provider,
                    wg.copyWith(listenPort: port, address: addressCtrl.text.trim(), endpoint: endpointCtrl.text.trim()),
                  );
                },
              ),
              const SizedBox(width: 14),
              if (_loadingServerInfo)
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
              else if (serverPubKey.isNotEmpty)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.key, size: 13, color: Colors.grey),
                      const SizedBox(width: 6),
                      const Text('Server publik nyckel:', style: TextStyle(color: Colors.grey, fontSize: 10)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SelectableText(serverPubKey, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'), maxLines: 1),
                      ),
                    ],
                  ),
                )
              else
                const Text('Serverns nyckelpar genereras automatiskt när VPN:en aktiveras och appliceras.', style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Kom ihåg att applicera & bekräfta ändringarna (banderollen högst upp) för att öppna UDP-porten mot WAN och starta wg0.',
            style: TextStyle(color: Colors.amberAccent, fontSize: 10),
          ),
        ],
      ),
    );
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

  Widget _buildPeersCard(ConfigProvider provider, WireGuardConfigModel wg) {
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
              Text('VPN-klienter (${wg.peers.length})', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Lägg till klient', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                onPressed: () => _showAddPeerFlow(provider, wg),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (wg.peers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Inga VPN-klienter tillagda ännu.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ...wg.peers.map((peer) => _buildPeerRow(provider, wg, peer)),
        ],
      ),
    );
  }

  Widget _buildPeerRow(ConfigProvider provider, WireGuardConfigModel wg, WireGuardPeerModel peer) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(peer.enabled ? Icons.person : Icons.person_off, size: 16, color: peer.enabled ? Colors.tealAccent : Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(peer.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text(peer.allowedIps, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ),
          Expanded(
            flex: 3,
            child: Text(peer.publicKey, style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
          ),
          Switch(
            value: peer.enabled,
            activeColor: Colors.tealAccent,
            onChanged: (v) {
              final updated = wg.peers.map((p) => p.id == peer.id ? WireGuardPeerModel(id: p.id, name: p.name, publicKey: p.publicKey, allowedIps: p.allowedIps, enabled: v) : p).toList();
              _saveWireGuard(provider, wg.copyWith(peers: updated));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
            tooltip: 'Ta bort klient',
            onPressed: () {
              final updated = wg.peers.where((p) => p.id != peer.id).toList();
              _saveWireGuard(provider, wg.copyWith(peers: updated));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddPeerFlow(ConfigProvider provider, WireGuardConfigModel wg) async {
    final nameCtrl = TextEditingController(text: 'Ny klient');
    final allowedIpCtrl = TextEditingController(text: _suggestNextClientIp(wg));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lägg till VPN-klient', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _labeledField('Namn', nameCtrl, hint: 't.ex. Fredriks laptop'),
              const SizedBox(height: 10),
              _labeledField('Tilldelad IP i VPN-nätet (AllowedIPs)', allowedIpCtrl, hint: '10.66.66.2/32'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Avbryt', style: TextStyle(color: Colors.grey))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Generera nyckelpar & lägg till'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final keys = await provider.api.generateWireGuardPeerKeys();
    if (keys == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Misslyckades generera nyckelpar från brandväggen'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final newPeer = WireGuardPeerModel(
      id: 'peer-${DateTime.now().millisecondsSinceEpoch}',
      name: nameCtrl.text.trim().isEmpty ? 'Klient' : nameCtrl.text.trim(),
      publicKey: keys['public_key']!,
      allowedIps: allowedIpCtrl.text.trim(),
      enabled: true,
    );

    await _saveWireGuard(provider, wg.copyWith(peers: [...wg.peers, newPeer]));

    if (mounted) {
      _showClientConfigDialog(newPeer, keys['private_key']!, wg);
    }
  }

  String _suggestNextClientIp(WireGuardConfigModel wg) {
    // Enkel heuristik: 10.66.66.<2 + antal befintliga klienter>/32, baserat
    // på server-adressen om den är satt.
    final base = wg.address.split('/').first;
    final parts = base.split('.');
    if (parts.length == 4) {
      final nextOctet = 2 + wg.peers.length;
      return '${parts[0]}.${parts[1]}.${parts[2]}.$nextOctet/32';
    }
    return '10.66.66.${2 + wg.peers.length}/32';
  }

  void _showClientConfigDialog(WireGuardPeerModel peer, String privateKey, WireGuardConfigModel wg) {
    final serverPubKey = _serverInfo?['public_key'] as String? ?? wg.serverPublicKey;
    final endpointHost = wg.endpoint.isNotEmpty ? wg.endpoint : '<SÄTT-ENDPOINT-I-SERVERINSTÄLLNINGAR>';
    final clientConfig = '''
[Interface]
PrivateKey = $privateKey
Address = ${peer.allowedIps}
DNS = 1.1.1.1

[Peer]
PublicKey = $serverPubKey
Endpoint = $endpointHost:${wg.listenPort}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
''';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.amberAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Klientkonfiguration för "${peer.name}"', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Detta visas bara EN gång — den privata nyckeln sparas aldrig på brandväggen. Spara eller skanna QR-koden nu.',
                style: TextStyle(color: Colors.amberAccent, fontSize: 11),
              ),
              const SizedBox(height: 14),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.white,
                  child: QrImageView(data: clientConfig, size: 220, backgroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  border: Border.all(color: const Color(0xFF334155)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(clientConfig, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace')),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 14, color: Colors.cyanAccent),
                    label: const Text('Kopiera', style: TextStyle(color: Colors.cyanAccent)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: clientConfig));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Klientkonfiguration kopierad'), backgroundColor: Colors.teal),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Klart, jag har sparat den'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
