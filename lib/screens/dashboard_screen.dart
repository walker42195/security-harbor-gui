import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _pingController = TextEditingController(text: '8.8.8.8');
  String _pingOutput = '';
  bool _isPingLoading = false;
  bool _isTracerouteLoading = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final status = provider.systemStatus;

    final sysName = status?['hostname'] ?? 'security-harbor-fw';
    final sysVersion = status?['version'] ?? 'v0.2.2';
    final uptime = status?['uptime'] ?? '1h 42m';
    final cpuUsage = status?['cpu'] ?? 14.5;
    final memUsage = status?['memory'] ?? 38.2;

    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Status-översikt (Kompakta kort)
            Row(
              children: [
                _buildCompactStatCard('System', sysName, 'Ver: $sysVersion', Icons.dns, Colors.cyanAccent),
                const SizedBox(width: 10),
                _buildCompactStatCard('Uptime', uptime, 'Driftstatus: Aktiv', Icons.timer_outlined, Colors.tealAccent),
                const SizedBox(width: 10),
                _buildCompactStatCard('CPU', '${cpuUsage.toStringAsFixed(1)}%', 'Kärnor: 4 (Optimal)', Icons.memory, Colors.amber),
                const SizedBox(width: 10),
                _buildCompactStatCard('Minne', '${memUsage.toStringAsFixed(1)}%', 'RAM: 8 GB (LEDIGT 62%)', Icons.pie_chart_outline, Colors.lightBlueAccent),
              ],
            ),
            const SizedBox(height: 16),

            // Diagnostikvy
            Container(
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
                      const Expanded(
                        child: Text(
                          'Diagnostik & Nätverksverktyg',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.terminal, size: 12, color: Colors.cyanAccent),
                            SizedBox(width: 6),
                            Text('Körs från brandväggen (10.0.0.163)', style: TextStyle(color: Colors.cyanAccent, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: TextField(
                            controller: _pingController,
                            style: const TextStyle(fontSize: 11, color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Mål-IP eller domän (t.ex. 8.8.8.8)',
                              labelStyle: TextStyle(fontSize: 11),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: _isPingLoading
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.download, size: 14),
                        label: const Text('Ping', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: _isPingLoading ? null : () => _runPing(provider),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        icon: _isTracerouteLoading
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.alt_route, size: 14),
                        label: const Text('Traceroute', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: _isTracerouteLoading ? null : () => _runTraceroute(provider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 180,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _pingOutput.isEmpty ? 'Klicka på Ping eller Traceroute för att köra diagnos...' : _pingOutput,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent),
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

  Widget _buildCompactStatCard(String title, String mainValue, String subValue, IconData icon, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          border: Border.all(color: const Color(0xFF334155)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: accentColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(mainValue, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(subValue, style: TextStyle(color: accentColor, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _runPing(ConfigProvider provider) async {
    setState(() {
      _isPingLoading = true;
      _pingOutput = 'Kör ping mot ${_pingController.text}...';
    });
    final out = await provider.api.ping(_pingController.text);
    setState(() {
      _pingOutput = out;
      _isPingLoading = false;
    });
  }

  void _runTraceroute(ConfigProvider provider) async {
    setState(() {
      _isTracerouteLoading = true;
      _pingOutput = 'Kör traceroute mot ${_pingController.text}...';
    });
    final out = await provider.api.traceroute(_pingController.text);
    setState(() {
      _pingOutput = out;
      _isTracerouteLoading = false;
    });
  }
}
