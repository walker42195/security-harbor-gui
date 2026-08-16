import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';

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

  @override
  void dispose() {
    _targetController.dispose();
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
                        onPressed: _isPingLoading || _isTracerouteLoading ? null : () => _runPing(provider),
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
                        onPressed: _isPingLoading || _isTracerouteLoading ? null : () => _runTraceroute(provider),
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
}
