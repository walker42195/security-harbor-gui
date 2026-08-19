import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../models/config_model.dart';

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

  bool _nmapSyn = true;
  bool _nmapFullTcp = false;
  bool _nmapUdp = false;
  bool _nmapOsDetect = false;

  final TextEditingController _tcpdumpFilterController = TextEditingController();
  String? _tcpdumpInterface;
  int _tcpdumpPacketCount = 200;
  int _tcpdumpDurationSec = 10;

  @override
  void dispose() {
    _targetController.dispose();
    _tcpdumpFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);

    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Rubrik och Server-badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.build_circle_outlined, color: Colors.cyanAccent, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Nätverksdiagnostik & Verktyg',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.terminal, size: 13, color: Colors.cyanAccent),
                      SizedBox(width: 6),
                      Text('Körs direkt från brandväggen (10.0.0.163)', style: TextStyle(color: Colors.cyanAccent, fontSize: 11)),
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
                color: const Color(0xFF1E293B),
                border: Border.all(color: const Color(0xFF334155)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ange Mål-IP eller Hostnamn:', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: _targetController,
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              hintText: 't.ex. 8.8.8.8, 1.1.1.1 eller google.com',
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
                        label: const Text('Kör Ping', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: _anyLoading ? null : () => _runPing(provider),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: _isTracerouteLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.alt_route, size: 14),
                        label: const Text('Kör Traceroute', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.white,
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
                      const Text('Snabbval:', style: TextStyle(color: Colors.grey, fontSize: 10)),
                      _buildPresetChip('Google (8.8.8.8)', '8.8.8.8'),
                      _buildPresetChip('Cloudflare (1.1.1.1)', '1.1.1.1'),
                      _buildPresetChip('Gateway (10.0.0.1)', '10.0.0.1'),
                      _buildPresetChip('Harbor Web (security.novabase.se)', 'security.novabase.se'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // nmap-portskanning
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border.all(color: const Color(0xFF334155)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.radar, color: Colors.tealAccent, size: 16),
                      SizedBox(width: 8),
                      Text('nmap-portskanning', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 0,
                    children: [
                      _nmapCheck('TCP SYN-scan (-sS)', _nmapSyn, (v) => setState(() => _nmapSyn = v)),
                      _nmapCheck('Full TCP-scan (-p- -sV)', _nmapFullTcp, (v) => setState(() => _nmapFullTcp = v)),
                      _nmapCheck('UDP-scan (-sU)', _nmapUdp, (v) => setState(() => _nmapUdp = v)),
                      _nmapCheck('OS-detektion (-O)', _nmapOsDetect, (v) => setState(() => _nmapOsDetect = v)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    icon: _isNmapLoading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.radar, size: 14),
                    label: const Text('Kör nmap', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _anyLoading || (!_nmapSyn && !_nmapFullTcp && !_nmapUdp && !_nmapOsDetect) ? null : () => _runNmap(provider),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Full TCP-scan och UDP-scan kan ta flera minuter. Kör inte mot mål du inte har rätt att skanna.',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 10),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Live paketfångst (tcpdump)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border.all(color: const Color(0xFF334155)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.podcasts, color: Colors.orangeAccent, size: 16),
                      SizedBox(width: 8),
                      Text('Paketfångst (tcpdump)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Valfritt BPF-filter, t.ex. "port 443"',
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
                          decoration: const InputDecoration(
                            labelText: 'Paket',
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
                          decoration: const InputDecoration(
                            labelText: 'Sekunder',
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
                    label: const Text('Starta fångst', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: _anyLoading || _tcpdumpInterface == null ? null : () => _runTcpdump(provider),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Fångsten avslutas automatiskt efter valt antal paket eller sekunder, det som inträffar först (max 12 sekunder).',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
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
                      const Text(
                        'Konsol / Utdata:',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14, color: Colors.cyanAccent),
                            tooltip: 'Kopiera utdata',
                            onPressed: _output.isEmpty
                                ? null
                                : () {
                                    Clipboard.setData(ClipboardData(text: _output));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Utdata kopierad till urklipp!'), backgroundColor: Colors.teal),
                                    );
                                  },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.redAccent),
                            tooltip: 'Rensa konsol',
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
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _output.isEmpty
                            ? 'Välj mål och klicka på Kör Ping eller Kör Traceroute för att starta nätverksdiagnos...'
                            : _output,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent, height: 1.4),
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
      label: Text(label, style: const TextStyle(fontSize: 10, color: Colors.cyanAccent)),
      backgroundColor: const Color(0xFF0F172A),
      side: const BorderSide(color: Color(0xFF334155)),
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
      _output = 'Kör ping (4 paket) mot $target från brandväggen...\n--------------------------------------------------\n';
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
      _output = 'Kör traceroute (max 15 hopp) mot $target från brandväggen...\n--------------------------------------------------\n';
    });
    final out = await provider.api.traceroute(target);
    if (!mounted) return;
    setState(() {
      _output += out;
      _isTracerouteLoading = false;
    });
  }

  bool get _anyLoading => _isPingLoading || _isTracerouteLoading || _isNmapLoading || _isTcpdumpLoading;

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
        decoration: const InputDecoration(
          labelText: 'Gränssnitt',
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          border: OutlineInputBorder(),
        ),
        items: interfaces
            .map((i) => DropdownMenuItem(
                  value: i.device,
                  child: Text('${i.device} (${i.zone})', style: const TextStyle(fontSize: 12, color: Colors.white)),
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
      _output = 'Fångar paket på $iface från brandväggen...\n--------------------------------------------------\n';
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
          Checkbox(value: value, activeColor: Colors.tealAccent, onChanged: (v) => onChanged(v ?? false)),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
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
      _output = 'Kör nmap mot $target från brandväggen...\n--------------------------------------------------\n';
    });
    final out = await provider.api.nmap(
      target,
      synScan: _nmapSyn,
      fullTcp: _nmapFullTcp,
      udpScan: _nmapUdp,
      osDetect: _nmapOsDetect,
    );
    if (!mounted) return;
    setState(() {
      _output += out;
      _isNmapLoading = false;
    });
  }
}
