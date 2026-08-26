import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../services/config_export.dart';
import '../localization.dart';

class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _serverInfo;
  bool _loadingServerInfo = true;
  String? _openVpnCaCertPem;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadServerInfo();
    _loadOpenVpnCa();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOpenVpnCa() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    final ca = await provider.api.getOpenVPNCACertPem();
    if (!mounted) return;
    setState(() => _openVpnCaCertPem = ca);
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

  OpenVPNConfigModel _currentOvpn(ConfigProvider provider) {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    return cfg?.openvpn ??
        OpenVPNConfigModel(enabled: false, listenPort: 1194, protocol: 'udp', address: '10.77.77.0/24', endpoint: '', clients: []);
  }

  Future<void> _saveOpenVpn(ConfigProvider provider, OpenVPNConfigModel ovpn) async {
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    if (cfg == null) return;
    await provider.updateCandidate(cfg.copyWith(openvpn: ovpn));
    if (mounted) await _loadOpenVpnCa();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final wg = _currentWg(provider);
    final serverPubKey = _serverInfo?['public_key'] as String? ?? '';
    final ovpn = _currentOvpn(provider);

    return Container(
      color: AppColors.bg,
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Icon(Icons.vpn_lock, color: AppColors.accent, size: 22),
                const SizedBox(width: 10),
                Text(tr('vpn.vpn'), style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'WireGuard'),
              Tab(text: 'OpenVPN'),
            ],
          ),
          Divider(color: AppColors.border, height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildServerCard(provider, wg, serverPubKey),
                      const SizedBox(height: 14),
                      _buildPeersCard(provider, wg),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOpenVpnServerCard(provider, ovpn),
                      const SizedBox(height: 14),
                      _buildOpenVpnClientsCard(provider, ovpn),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('vpn.serverinstallningar_wg0'), style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Switch(
                    value: wg.enabled,
                    activeThumbColor: AppColors.ok,
                    onChanged: (v) => _saveWireGuard(provider, wg.copyWith(enabled: v)),
                  ),
                  Text(wg.enabled ? 'Aktiverad' : 'Inaktiverad', style: TextStyle(color: wg.enabled ? AppColors.ok : AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _labeledField(tr('vpn.vpn_nat_label'), addressCtrl, hint: '10.66.66.1/24')),
              const SizedBox(width: 10),
              SizedBox(width: 140, child: _labeledField(tr('vpn.lyssningsport_udp'), listenPortCtrl, hint: '51820')),
            ],
          ),
          const SizedBox(height: 10),
          _labeledField(tr('vpn.publik_endpoint_label'), endpointCtrl, hint: tr('vpn.publik_endpoint_hint')),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 14),
                label: Text(tr('vpn.spara_serverinstallningar'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBg, foregroundColor: AppColors.onAccentBg),
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
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
              else if (serverPubKey.isNotEmpty)
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.key, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(tr('vpn.server_publik_nyckel'), style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SelectableText(serverPubKey, style: TextStyle(color: AppColors.text, fontSize: 10, fontFamily: 'monospace'), maxLines: 1),
                      ),
                    ],
                  ),
                )
              else
                Text(tr('vpn.serverns_nyckelpar_genereras_automatiskt_nar_vpn'), style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Text(tr('vpn.kom_ihag_att_applicera_bekrafta_andringarna'),
            style: TextStyle(color: AppColors.warn, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _labeledField(String label, TextEditingController ctrl, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 34,
          child: TextField(
            controller: ctrl,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
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
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('VPN-klienter (${wg.peers.length})', style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: Text(tr('vpn.lagg_till_klient'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.ok, foregroundColor: AppColors.onStatus),
                onPressed: () => _showAddPeerFlow(provider, wg),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (wg.peers.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(tr('vpn.inga_vpn_klienter_tillagda_annu'), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(peer.enabled ? Icons.person : Icons.person_off, size: 16, color: peer.enabled ? AppColors.ok : AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(peer.name, style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text(peer.allowedIps, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ),
          Expanded(
            flex: 3,
            child: Text(peer.publicKey, style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
          ),
          Switch(
            value: peer.enabled,
            activeThumbColor: AppColors.ok,
            onChanged: (v) {
              final updated = wg.peers.map((p) => p.id == peer.id ? WireGuardPeerModel(id: p.id, name: p.name, publicKey: p.publicKey, allowedIps: p.allowedIps, enabled: v) : p).toList();
              _saveWireGuard(provider, wg.copyWith(peers: updated));
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
            tooltip: tr('vpn.ta_bort_klient'),
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
    final nameCtrl = TextEditingController(text: tr('vpn.ny_klient'));
    final allowedIpCtrl = TextEditingController(text: _suggestNextClientIp(wg));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('vpn.lagg_till_vpn_klient'), style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _labeledField(tr('vpn.namn'), nameCtrl, hint: tr('vpn.namn_hint')),
              const SizedBox(height: 10),
              _labeledField(tr('vpn.tilldelad_ip_label'), allowedIpCtrl, hint: '10.66.66.2/32'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('vpn.avbryt'), style: TextStyle(color: AppColors.textMuted))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.ok, foregroundColor: AppColors.onStatus),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(tr('vpn.generera_nyckelpar_lagg_till')),
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
          SnackBar(content: Text(tr('vpn.misslyckades_generera_nyckelpar_fran_brandvaggen')), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final newPeer = WireGuardPeerModel(
      id: 'peer-${DateTime.now().millisecondsSinceEpoch}',
      name: nameCtrl.text.trim().isEmpty ? tr('vpn.klient') : nameCtrl.text.trim(),
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
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Container(
          width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 520.0),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: AppColors.warn, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(trp('vpn.client_config_for', {'name': peer.name}), style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(tr('vpn.detta_visas_bara_en_gang_den'),
                style: TextStyle(color: AppColors.warn, fontSize: 11),
              ),
              const SizedBox(height: 14),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  color: AppColors.text,
                  child: QrImageView(data: clientConfig, size: 220, backgroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(clientConfig, style: TextStyle(color: AppColors.ok, fontSize: 11, fontFamily: 'monospace')),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.copy, size: 14, color: AppColors.accent),
                    label: Text(tr('vpn.kopiera'), style: TextStyle(color: AppColors.accent)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: clientConfig));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('vpn.klientkonfiguration_kopierad')), backgroundColor: Colors.teal),
                      );
                    },
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.save_alt, size: 14, color: AppColors.accent),
                    label: Text(tr('vpn.spara_till_fil'), style: TextStyle(color: AppColors.accent)),
                    onPressed: () => _saveClientConfig('${_safeFileName(peer.name)}.conf', clientConfig),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBg, foregroundColor: AppColors.onAccentBg),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr('vpn.klart_jag_har_sparat_den')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenVpnServerCard(ConfigProvider provider, OpenVPNConfigModel ovpn) {
    final listenPortCtrl = TextEditingController(text: ovpn.listenPort.toString());
    final addressCtrl = TextEditingController(text: ovpn.address);
    final endpointCtrl = TextEditingController(text: ovpn.endpoint);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('vpn.serverinstallningar_tls_pki'), style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Switch(
                    value: ovpn.enabled,
                    activeThumbColor: AppColors.ok,
                    onChanged: (v) => _saveOpenVpn(provider, ovpn.copyWith(enabled: v)),
                  ),
                  Text(ovpn.enabled ? 'Aktiverad' : 'Inaktiverad', style: TextStyle(color: ovpn.enabled ? AppColors.ok : AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _labeledField(tr('vpn.vpn_subnat_label'), addressCtrl, hint: '10.77.77.0/24')),
              const SizedBox(width: 10),
              SizedBox(width: 140, child: _labeledField(tr('vpn.lyssningsport'), listenPortCtrl, hint: '1194')),
              const SizedBox(width: 10),
              SizedBox(width: 110, child: _protocolDropdown(provider, ovpn)),
            ],
          ),
          const SizedBox(height: 10),
          _labeledField(tr('vpn.publik_endpoint_label'), endpointCtrl, hint: tr('vpn.publik_endpoint_hint')),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 14),
                label: Text(tr('vpn.spara_serverinstallningar'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBg, foregroundColor: AppColors.onAccentBg),
                onPressed: () {
                  final port = int.tryParse(listenPortCtrl.text.trim()) ?? ovpn.listenPort;
                  _saveOpenVpn(
                    provider,
                    ovpn.copyWith(listenPort: port, address: addressCtrl.text.trim(), endpoint: endpointCtrl.text.trim()),
                  );
                },
              ),
              const SizedBox(width: 14),
              if (_openVpnCaCertPem != null && _openVpnCaCertPem!.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.verified_user, size: 13, color: AppColors.ok),
                    SizedBox(width: 6),
                    Text(tr('vpn.ca_certifikat_genererat_och_redo_att'), style: TextStyle(color: AppColors.ok, fontSize: 10)),
                  ],
                )
              else
                Text(tr('vpn.ca_t_genereras_automatiskt_vid_forsta'), style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Text(tr('vpn.kom_ihag_att_applicera_bekrafta_andringarna_2'),
            style: TextStyle(color: AppColors.warn, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _protocolDropdown(ConfigProvider provider, OpenVPNConfigModel ovpn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('vpn.protokoll'), style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 34,
          child: DropdownButtonFormField<String>(
            initialValue: ovpn.protocol,
            dropdownColor: AppColors.surface,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
            items: [
              DropdownMenuItem(value: 'udp', child: Text(tr('vpn.udp'))),
              DropdownMenuItem(value: 'tcp', child: Text(tr('vpn.tcp'))),
            ],
            onChanged: (v) {
              if (v != null) _saveOpenVpn(provider, ovpn.copyWith(protocol: v));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOpenVpnClientsCard(ConfigProvider provider, OpenVPNConfigModel ovpn) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Klientprofiler (${ovpn.clients.length})', style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: Text(tr('vpn.utfarda_klientcertifikat'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.ok, foregroundColor: AppColors.onStatus),
                onPressed: () => _showAddOpenVpnClientFlow(provider, ovpn),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (ovpn.clients.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(tr('vpn.inga_openvpn_klientprofiler_utfardade_annu'), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            ...ovpn.clients.map((c) => _buildOpenVpnClientRow(provider, ovpn, c)),
        ],
      ),
    );
  }

  Widget _buildOpenVpnClientRow(ConfigProvider provider, OpenVPNConfigModel ovpn, OpenVPNClientModel client) {
    final active = client.enabled && !client.revoked;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(client.revoked ? Icons.block : (active ? Icons.person : Icons.person_off), size: 16, color: client.revoked ? AppColors.danger : (active ? AppColors.ok : AppColors.textMuted)),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(client.name, style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              client.revoked ? tr('vpn.sparrad') : (client.enabled ? tr('vpn.aktiv') : tr('vpn.inaktiverad')),
              style: TextStyle(color: client.revoked ? AppColors.danger : AppColors.textMuted, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text('Serienr: ${client.certSerial}', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
          ),
          if (!client.revoked)
            Switch(
              value: client.enabled,
              activeThumbColor: AppColors.ok,
              onChanged: (v) {
                final updated = ovpn.clients.map((c) => c.id == client.id ? c.copyWith(enabled: v) : c).toList();
                _saveOpenVpn(provider, ovpn.copyWith(clients: updated));
              },
            ),
          IconButton(
            icon: Icon(client.revoked ? Icons.delete_forever : Icons.block, size: 16, color: AppColors.danger),
            tooltip: client.revoked ? tr('vpn.ta_bort_permanent') : tr('vpn.sparra_certifikat'),
            onPressed: () {
              if (client.revoked) {
                final updated = ovpn.clients.where((c) => c.id != client.id).toList();
                _saveOpenVpn(provider, ovpn.copyWith(clients: updated));
              } else {
                final updated = ovpn.clients.map((c) => c.id == client.id ? c.copyWith(revoked: true, enabled: false) : c).toList();
                _saveOpenVpn(provider, ovpn.copyWith(clients: updated));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddOpenVpnClientFlow(ConfigProvider provider, OpenVPNConfigModel ovpn) async {
    final nameCtrl = TextEditingController(text: tr('vpn.ny_klient'));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('vpn.utfarda_openvpn_klientcertifikat'), style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _labeledField(tr('vpn.namn'), nameCtrl, hint: tr('vpn.namn_hint')),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('vpn.avbryt'), style: TextStyle(color: AppColors.textMuted))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.ok, foregroundColor: AppColors.onStatus),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(tr('vpn.signera_med_ca_lagg_till')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final name = nameCtrl.text.trim().isEmpty ? tr('vpn.klient') : nameCtrl.text.trim();
    final result = await provider.api.generateOpenVPNClient(name);
    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('vpn.misslyckades_signera_klientcertifikat_pa_brandvaggen')), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final newClient = OpenVPNClientModel(
      id: 'ovpn-client-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      enabled: true,
      certSerial: result['serial'] ?? '',
      certPem: result['cert_pem'] ?? '',
      issuedAt: DateTime.now().toIso8601String(),
    );

    await _saveOpenVpn(provider, ovpn.copyWith(clients: [...ovpn.clients, newClient]));

    if (mounted) {
      _showOpenVpnConfigDialog(newClient, result['ovpn_config'] ?? '');
    }
  }

  /// Filnamn av ett klient-/peer-namn. Namnet är fritext från GUI:t och
  /// hamnar i en sökväg — snedstreck och liknande måste bort, annars skulle
  /// "hem/laptop" försöka skriva i en katalog som inte finns.
  static String _safeFileName(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
    return cleaned.isEmpty ? 'klient' : cleaned;
  }

  /// Sparar konfigurationen till fil och kvitterar var den hamnade.
  ///
  /// Filen innehåller klientens PRIVATA nyckel — därför sätts 0600 på
  /// desktop/mobil (se config_export_io.dart), och därför säger kvittensen
  /// var filen ligger: den ska flyttas till klienten och inte bli kvar.
  Future<void> _saveClientConfig(String filename, String content) async {
    final saved = await saveTextFile(filename, content);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved == null
            ? tr('vpn.spara_misslyckades')
            : trp('vpn.sparad_till', {'path': saved})),
        backgroundColor: saved == null ? Colors.red : Colors.teal,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _showOpenVpnConfigDialog(OpenVPNClientModel client, String ovpnConfig) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Container(
          width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 520.0),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: AppColors.warn, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(trp('vpn.client_profile_for', {'name': client.name}), style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(tr('vpn.detta_ar_en_komplett_ovpn_fil'),
                style: TextStyle(color: AppColors.warn, fontSize: 11),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 320),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(ovpnConfig, style: TextStyle(color: AppColors.ok, fontSize: 10, fontFamily: 'monospace')),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.copy, size: 14, color: AppColors.accent),
                    label: Text(tr('vpn.kopiera'), style: TextStyle(color: AppColors.accent)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: ovpnConfig));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(tr('vpn.ovpn_innehall_kopierat')), backgroundColor: Colors.teal),
                      );
                    },
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.save_alt, size: 14, color: AppColors.accent),
                    label: Text(tr('vpn.spara_ovpn'), style: TextStyle(color: AppColors.accent)),
                    onPressed: () => _saveClientConfig('${_safeFileName(client.name)}.ovpn', ovpnConfig),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBg, foregroundColor: AppColors.onAccentBg),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr('vpn.klart_jag_har_sparat_den')),
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
