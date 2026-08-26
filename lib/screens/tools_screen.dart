import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../models/config_model.dart';
import '../localization.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final TextEditingController _targetController = TextEditingController(text: '8.8.8.8');
  String _output = '';
  bool _isPingLoading = false;
  bool _isTracerouteLoading = false;
  bool _isNmapLoading = false;
  bool _isTcpdumpLoading = false;
  bool _isDigLoading = false;
  bool _isArpLoading = false;

  final TextEditingController _digServerController = TextEditingController();
  String _digType = 'A';

  bool _nmapSyn = true;
  bool _nmapFullTcp = false;
  bool _nmapUdp = false;
  bool _nmapOsDetect = false;
  // Snabb timing (-T4) — separat från scanningstyperna ovan eftersom den
  // går att kombinera med VILKEN som helst av dem (styr bara hur aggressivt
  // nmap parallelliserar/timeoutar, inte vad som skannas). Efterfrågad av
  // en administratör 2026-08-24 — nmaps standardtiming (-T3) kan annars
  // kännas onödigt långsam mot ett eget, pålitligt nät.
  bool _nmapFastTiming = false;

  final TextEditingController _tcpdumpFilterController = TextEditingController();
  String? _tcpdumpInterface;
  int _tcpdumpPacketCount = 200;
  int _tcpdumpDurationSec = 10;

  @override
  void dispose() {
    _targetController.dispose();
    _tcpdumpFilterController.dispose();
    _digServerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);

    return Container(
      color: AppColors.bg,
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Rubrik och Server-badge. Wrap i stället för Row+spaceBetween:
            // titeln + den långa badgetexten overflowade tyst på en
            // telefonskärm (upptäckt 2026-08-24).
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.build_circle_outlined, color: AppColors.accent, size: 22),
                    SizedBox(width: 10),
                    Text(tr('tools.natverksdiagnostik_verktyg'),
                      style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.terminal, size: 13, color: AppColors.accent),
                      SizedBox(width: 6),
                      Text(tr('tools.kors_direkt_fran_brandvaggen_inte_fran'), style: TextStyle(color: AppColors.accent, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Kontrollpanel för Ping & Traceroute
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('tools.ange_mal_ip_eller_hostnamn'), style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: _targetController,
                            style: TextStyle(fontSize: 12, color: AppColors.text, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: tr('tools.t_ex_8_8_8_8'),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: _isPingLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.download, size: 14),
                        label: Text(tr('tools.kor_ping'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onStatus,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: _anyLoading ? null : () => _runPing(provider),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: _isTracerouteLoading
                            ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.text))
                            : const Icon(Icons.alt_route, size: 14),
                        label: Text(tr('tools.kor_traceroute'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.info,
                          foregroundColor: AppColors.text,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: _anyLoading ? null : () => _runTraceroute(provider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Snabbknappar (Presets)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Text(tr('tools.snabbval'), style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      _buildPresetChip(tr('tools.google_preset'), '8.8.8.8'),
                      _buildPresetChip(tr('tools.cloudflare_preset'), '1.1.1.1'),
                      _buildPresetChip(tr('tools.quad9_preset'), '9.9.9.9'),
                      _buildPresetChip('example.com', 'example.com'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // nmap-portskanning — placerad direkt under Ping & Traceroute
            // (näst överst) på uttrycklig begäran 2026-08-24, i stället för
            // längre ner bland de mer sällan använda verktygen.
            Container(
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
                    children: [
                      Icon(Icons.radar, color: AppColors.ok, size: 16),
                      SizedBox(width: 8),
                      Text(tr('tools.nmap_portskanning'), style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 0,
                    children: [
                      _nmapCheck(tr('tools.tcp_syn_scan'), _nmapSyn, (v) => setState(() => _nmapSyn = v)),
                      _nmapCheck(tr('tools.full_tcp_scan'), _nmapFullTcp, (v) => setState(() => _nmapFullTcp = v)),
                      _nmapCheck(tr('tools.udp_scan'), _nmapUdp, (v) => setState(() => _nmapUdp = v)),
                      _nmapCheck(tr('tools.os_detect'), _nmapOsDetect, (v) => setState(() => _nmapOsDetect = v)),
                      _nmapCheck(tr('tools.fast_timing'), _nmapFastTiming, (v) => setState(() => _nmapFastTiming = v)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    icon: _isNmapLoading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.radar, size: 14),
                    label: Text(tr('tools.kor_nmap'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ok,
                      foregroundColor: AppColors.onStatus,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _anyLoading || (!_nmapSyn && !_nmapFullTcp && !_nmapUdp && !_nmapOsDetect) ? null : () => _runNmap(provider),
                  ),
                  const SizedBox(height: 4),
                  Text(tr('tools.full_tcp_scan_och_udp_scan'),
                    style: TextStyle(color: AppColors.warn, fontSize: 10),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // DNS-uppslag (dig)
            Container(
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
                    children: [
                      Icon(Icons.travel_explore, size: 15, color: AppColors.accent),
                      SizedBox(width: 6),
                      Text(tr('tools.dns_uppslag_dig'), style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(tr('tools.namn_att_sla_upp_anges_i'), style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(tr('tools.typ'), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      const SizedBox(width: 6),
                      // Höjden matchar nu textfältet bredvid (36px) i
                      // stället för att bara krympa till DropdownButtonets
                      // egen, mindre intrinsiska höjd — de såg tidigare
                      // omotiverat olika stora ut på samma rad.
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _digType,
                            isDense: true,
                            dropdownColor: AppColors.surface,
                            style: TextStyle(color: AppColors.text, fontSize: 12),
                            items: const ['A', 'AAAA', 'CNAME', 'MX', 'TXT', 'NS', 'SOA', 'PTR', 'SRV']
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (v) => setState(() => _digType = v ?? 'A'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: _digServerController,
                            style: TextStyle(fontSize: 12, color: AppColors.text),
                            decoration: InputDecoration(
                              hintText: tr('tools.dns_server_valfritt_t_ex_1'),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: _isDigLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.travel_explore, size: 14),
                        label: Text(tr('tools.kor_dig'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onStatus,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: _anyLoading ? null : () => _runDig(provider),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ARP-/grannbordstabell
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.table_rows_outlined, size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(tr('tools.arp_tabell_ip_mac_for_enheter'),
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: _isArpLoading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.table_chart, size: 14),
                    label: Text(tr('tools.visa_arp_tabell'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onStatus,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _anyLoading ? null : () => _runArp(provider),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Live paketfångst (tcpdump)
            Container(
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
                    children: [
                      Icon(Icons.podcasts, color: AppColors.caution, size: 16),
                      SizedBox(width: 8),
                      Text(tr('tools.paketfangst_tcpdump'), style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildInterfaceDropdown(provider),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: _tcpdumpFilterController,
                            style: TextStyle(fontSize: 12, color: AppColors.text),
                            decoration: InputDecoration(
                              hintText: tr('tools.valfritt_bpf_filter_t_ex_port'),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        height: 36,
                        child: DropdownButtonFormField<int>(
                          initialValue: _tcpdumpPacketCount,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: tr('tools.paket'),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            border: OutlineInputBorder(),
                          ),
                          items: const [50, 200, 500, 2000]
                              .map((n) => DropdownMenuItem(value: n, child: Text('$n', style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (v) => setState(() => _tcpdumpPacketCount = v ?? 200),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        height: 36,
                        child: DropdownButtonFormField<int>(
                          initialValue: _tcpdumpDurationSec,
                          isDense: true,
                          decoration: InputDecoration(
                            labelText: tr('tools.sekunder'),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            border: OutlineInputBorder(),
                          ),
                          items: const [5, 10, 12]
                              .map((n) => DropdownMenuItem(value: n, child: Text('$n', style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (v) => setState(() => _tcpdumpDurationSec = v ?? 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: _isTcpdumpLoading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.podcasts, size: 14),
                    label: Text(tr('tools.starta_fangst'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.caution,
                      foregroundColor: AppColors.onStatus,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _anyLoading || _tcpdumpInterface == null ? null : () => _runTcpdump(provider),
                  ),
                  const SizedBox(height: 4),
                  Text(tr('tools.fangsten_avslutas_automatiskt_efter_valt_antal'),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Diagnostik Terminal Konsol
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
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
                      Text(tr('tools.konsol_utdata'),
                        style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.copy, size: 14, color: AppColors.accent),
                            tooltip: tr('tools.kopiera_utdata'),
                            onPressed: _output.isEmpty
                                ? null
                                : () {
                                    Clipboard.setData(ClipboardData(text: _output));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(tr('tools.utdata_kopierad_till_urklipp')), backgroundColor: Colors.teal),
                                    );
                                  },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_sweep, size: 16, color: AppColors.danger),
                            tooltip: tr('tools.rensa_konsol'),
                            onPressed: () => setState(() => _output = ''),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    height: 340,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _output.isEmpty
                            ? tr('tools.placeholder_output')
                            : _output,
                        style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.ok, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String value) {
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 10, color: AppColors.accent)),
      backgroundColor: AppColors.bg,
      side: BorderSide(color: AppColors.border),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: () {
        setState(() {
          _targetController.text = value;
        });
      },
    );
  }

  void _runPing(ConfigProvider provider) async {
    final target = _targetController.text.trim();
    if (target.isEmpty) return;

    setState(() {
      _isPingLoading = true;
      _output = trp('tools.running_ping', {'target': target});
    });
    final out = await provider.api.ping(target);
    if (!mounted) return;
    setState(() {
      _output += out;
      _isPingLoading = false;
    });
  }

  void _runTraceroute(ConfigProvider provider) async {
    final target = _targetController.text.trim();
    if (target.isEmpty) return;

    setState(() {
      _isTracerouteLoading = true;
      _output = trp('tools.running_traceroute', {'target': target});
    });
    final out = await provider.api.traceroute(target);
    if (!mounted) return;
    setState(() {
      _output += out;
      _isTracerouteLoading = false;
    });
  }

  bool get _anyLoading => _isPingLoading || _isTracerouteLoading || _isNmapLoading || _isTcpdumpLoading || _isDigLoading || _isArpLoading;

  void _runDig(ConfigProvider provider) async {
    final target = _targetController.text.trim();
    if (target.isEmpty) return;
    final server = _digServerController.text.trim();
    setState(() {
      _isDigLoading = true;
      _output = trp('tools.running_dig', {'type': _digType, 'target': target, 'server': server.isEmpty ? '' : ' @$server'});
    });
    final out = await provider.api.dig(target, type: _digType, server: server);
    if (!mounted) return;
    setState(() {
      _output += out;
      _isDigLoading = false;
    });
  }

  void _runArp(ConfigProvider provider) async {
    setState(() {
      _isArpLoading = true;
      _output = tr('tools.running_arp');
    });
    final out = await provider.api.arpTable();
    if (!mounted) return;
    setState(() {
      _output += out;
      _isArpLoading = false;
    });
  }

  Widget _buildInterfaceDropdown(ConfigProvider provider) {
    final ConfigModel? cfg = provider.candidateConfig ?? provider.runningConfig;
    final interfaces = cfg?.interfaces ?? <InterfaceModel>[];
    if (_tcpdumpInterface == null && interfaces.isNotEmpty) {
      _tcpdumpInterface = interfaces.first.device;
    }
    return SizedBox(
      height: 36,
      child: DropdownButtonFormField<String>(
        initialValue: interfaces.any((i) => i.device == _tcpdumpInterface) ? _tcpdumpInterface : null,
        isDense: true,
        decoration: InputDecoration(
          labelText: tr('tools.granssnitt'),
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          border: OutlineInputBorder(),
        ),
        items: interfaces
            .map((i) => DropdownMenuItem(
                  value: i.device,
                  child: Text('${i.device} (${i.zone})', style: TextStyle(fontSize: 12, color: AppColors.text)),
                ))
            .toList(),
        onChanged: (v) => setState(() => _tcpdumpInterface = v),
      ),
    );
  }

  void _runTcpdump(ConfigProvider provider) async {
    final iface = _tcpdumpInterface;
    if (iface == null) return;

    setState(() {
      _isTcpdumpLoading = true;
      _output = trp('tools.running_capture', {'iface': iface});
    });
    final out = await provider.api.tcpdumpCapture(
      iface,
      filter: _tcpdumpFilterController.text.trim(),
      packetCount: _tcpdumpPacketCount,
      durationSec: _tcpdumpDurationSec,
    );
    if (!mounted) return;
    setState(() {
      _output += out;
      _isTcpdumpLoading = false;
    });
  }

  Widget _nmapCheck(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: value, activeColor: AppColors.ok, onChanged: (v) => onChanged(v ?? false)),
          Text(label, style: TextStyle(color: AppColors.text, fontSize: 11)),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  void _runNmap(ConfigProvider provider) async {
    final target = _targetController.text.trim();
    if (target.isEmpty) return;

    setState(() {
      _isNmapLoading = true;
      _output = trp('tools.running_nmap', {'target': target});
    });
    final out = await provider.api.nmap(
      target,
      synScan: _nmapSyn,
      fullTcp: _nmapFullTcp,
      udpScan: _nmapUdp,
      osDetect: _nmapOsDetect,
      fastTiming: _nmapFastTiming,
    );
    if (!mounted) return;
    setState(() {
      _output += out;
      _isNmapLoading = false;
    });
  }
}
