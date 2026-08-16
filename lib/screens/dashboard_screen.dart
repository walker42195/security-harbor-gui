import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _pingController = TextEditingController(text: '8.8.8.8');
  String _diagOutput = '';
  bool _isLoadingDiag = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final sys = provider.systemStatus;
    final cfg = provider.runningConfig;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SECURITY HARBOR FIREWALL',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Systemöversikt, Conntrack & Diagnostik',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                onPressed: () => provider.fetchAll(),
                tooltip: 'Uppdatera status',
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 700 ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatusCard(
                      context,
                      title: 'Systemstatus',
                      value: sys != null ? sys['state'].toString().toUpperCase() : 'ANSLUTER...',
                      icon: Icons.shield,
                      color: sys != null ? Colors.tealAccent : Colors.amber,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatusCard(
                      context,
                      title: 'Konfigurations-revision',
                      value: cfg != null ? 'Rev #${cfg.revision}' : 'N/A',
                      icon: Icons.history,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatusCard(
                      context,
                      title: 'Aktiva Gränssnitt',
                      value: cfg != null ? '${cfg.interfaces.where((i) => i.enabled).length} Aktiva' : '0',
                      icon: Icons.router,
                      color: Colors.lightBlueAccent,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Diagnostik & Nätverksverktyg',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              Chip(
                avatar: const Icon(Icons.dns, size: 16, color: Colors.cyanAccent),
                label: Text(
                  'Körs från brandväggen (${provider.api.baseUrl.replaceAll("http://", "").replaceAll("https://", "").split(":")[0]})',
                  style: const TextStyle(fontSize: 12, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                ),
                backgroundColor: const Color(0xFF0F172A),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFF1E293B),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _pingController,
                          decoration: const InputDecoration(labelText: 'Mål-IP eller domän (t.ex. 8.8.8.8)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.network_ping),
                        label: const Text('Kör Ping'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                        onPressed: () => _runPing(provider),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.alt_route),
                        label: const Text('Traceroute'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlueAccent, foregroundColor: Colors.black),
                        onPressed: () => _runTraceroute(provider),
                      ),
                    ],
                  ),
                  if (_isLoadingDiag)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: LinearProgressIndicator(color: Colors.cyanAccent),
                    ),
                  if (_diagOutput.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
                      child: SelectableText(_diagOutput, style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Konfigurerade Nätverksgränssnitt',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          if (cfg != null)
            Card(
              color: const Color(0xFF1E293B),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cfg.interfaces.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                itemBuilder: (context, idx) {
                  final iface = cfg.interfaces[idx];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: iface.zone == 'WAN' ? Colors.redAccent.withValues(alpha: 0.2) : Colors.tealAccent.withValues(alpha: 0.2),
                      child: Icon(
                        iface.zone == 'WAN' ? Icons.public : Icons.lan,
                        color: iface.zone == 'WAN' ? Colors.redAccent : Colors.tealAccent,
                      ),
                    ),
                    title: Text('${iface.id} (${iface.device})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Zon: ${iface.zone}  |  IP: ${iface.ipv4}  |  Typ: ${iface.addressType}'),
                    trailing: Chip(
                      label: Text(iface.enabled ? 'AKTIV' : 'AVSTÄNGD'),
                      backgroundColor: iface.enabled ? Colors.tealAccent.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                      labelStyle: TextStyle(color: iface.enabled ? Colors.tealAccent : Colors.grey),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _runPing(ConfigProvider provider) async {
    setState(() {
      _isLoadingDiag = true;
      _diagOutput = 'Kör ping mot ${_pingController.text}...';
    });
    final res = await provider.api.ping(_pingController.text);
    setState(() {
      _isLoadingDiag = false;
      _diagOutput = res;
    });
  }

  void _runTraceroute(ConfigProvider provider) async {
    setState(() {
      _isLoadingDiag = true;
      _diagOutput = 'Kör traceroute mot ${_pingController.text}...';
    });
    final res = await provider.api.ping(_pingController.text);
    setState(() {
      _isLoadingDiag = false;
      _diagOutput = res;
    });
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
