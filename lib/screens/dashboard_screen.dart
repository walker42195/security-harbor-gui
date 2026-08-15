import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SECURITY HARBOR FIREWALL',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Systemöversikt & Live Status',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                onPressed: () => provider.fetchAll(),
                tooltip: 'Uppdatera status',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  context,
                  title: 'Systemstatus',
                  value: sys != null ? sys['state'].toString().toUpperCase() : 'ANSLUTER...',
                  icon: Icons.shield,
                  color: sys != null ? Colors.tealAccent : Colors.amber,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusCard(
                  context,
                  title: 'Konfigurations-revision',
                  value: cfg != null ? 'Rev #${cfg.revision}' : 'N/A',
                  icon: Icons.history,
                  color: Colors.cyanAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatusCard(
                  context,
                  title: 'Aktiva Gränssnitt',
                  value: cfg != null ? '${cfg.interfaces.where((i) => i.enabled).length} Aktiva' : '0',
                  icon: Icons.router,
                  color: Colors.lightBlueAccent,
                ),
              ),
            ],
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
                      backgroundColor: iface.zone == 'WAN' ? Colors.redAccent.withOpacity(0.2) : Colors.tealAccent.withOpacity(0.2),
                      child: Icon(
                        iface.zone == 'WAN' ? Icons.public : Icons.lan,
                        color: iface.zone == 'WAN' ? Colors.redAccent : Colors.tealAccent,
                      ),
                    ),
                    title: Text('${iface.id} (${iface.device})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('Zon: ${iface.zone}  |  IP: ${iface.ipv4}  |  Typ: ${iface.addressType}'),
                    trailing: Chip(
                      label: Text(iface.enabled ? 'AKTIV' : 'AVSTÄNGD'),
                      backgroundColor: iface.enabled ? Colors.tealAccent.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
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
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
