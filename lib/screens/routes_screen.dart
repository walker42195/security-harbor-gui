import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

/// Statiska IP-rutter (`ip route add <nät> via <gateway>`) — för nät som
/// inte nås via brandväggens vanliga default-rutt utan kräver en specifik
/// gateway, t.ex. ett internt nät bakom en annan router på LAN-sidan. Se
/// pkg/config.StaticRoute i backend.
///
/// OBS: en rutt gör bara nätet NÅBART — den avgör inte om trafik dit
/// TILLÅTS. Det kräver fortfarande en vanlig Allow-policy under Policies
/// (Default Deny gäller annars som vanligt).
class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    final routes = cfg?.staticRoutes ?? [];

    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E293B),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.alt_route, color: Colors.cyanAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Statiska Rutter (Routing)',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16, color: Colors.cyanAccent),
                  label: const Text('Ny rutt', style: TextStyle(fontSize: 12, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    side: const BorderSide(color: Colors.cyanAccent),
                  ),
                  onPressed: cfg == null ? null : () => _showEditRouteDialog(context, provider, cfg, null),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF0F172A),
            child: const Text(
              'En rutt gör bara nätet NÅBART. Trafik dit tillåts fortfarande bara om det finns en '
              'motsvarande Allow-policy under Policies — Default Deny gäller annars som vanligt.',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),

          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border.all(color: const Color(0xFF334155)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: routes.isEmpty
                  ? const Center(
                      child: Text(
                        'Inga statiska rutter definierade.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: routes.length,
                      separatorBuilder: (_, _) => const Divider(color: Color(0xFF334155), height: 1),
                      itemBuilder: (context, idx) => _buildRouteRow(context, provider, cfg!, idx),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRow(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx) {
    final r = cfg.staticRoutes[idx];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(
            r.enabled ? Icons.check_circle : Icons.pause_circle_outline,
            size: 16,
            color: r.enabled ? Colors.tealAccent : Colors.grey,
          ),
          const SizedBox(width: 10),
          // Expanded (flex) i stället för en hård SizedBox(width: 180) —
          // på en telefonskärm gav den fasta bredden + ikonknapparna
          // tillsammans en RenderFlex-overflow (upptäckt 2026-08-24). Namn
          // och nät/gateway delar nu bredden proportionellt istället.
          Expanded(
            flex: 2,
            child: Text(
              r.name.isEmpty ? '(namnlös rutt)' : r.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: r.enabled ? Colors.white : Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                children: [
                  TextSpan(text: r.network, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  const TextSpan(text: '  via  '),
                  TextSpan(text: r.gateway, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  if (r.interfaceDevice.isNotEmpty) TextSpan(text: '  dev ${r.interfaceDevice}', style: const TextStyle(color: Colors.white38)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 16, color: Colors.cyanAccent),
            tooltip: 'Redigera rutt',
            onPressed: () => _showEditRouteDialog(context, provider, cfg, idx),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
            tooltip: 'Ta bort rutt',
            onPressed: () => _deleteRoute(context, provider, cfg, idx),
          ),
          Switch(
            value: r.enabled,
            activeThumbColor: Colors.tealAccent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (val) {
              final updated = List<StaticRouteModel>.from(cfg.staticRoutes);
              updated[idx] = r.copyWith(enabled: val);
              provider.updateCandidate(cfg.copyWith(staticRoutes: updated));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRoute(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx) async {
    final r = cfg.staticRoutes[idx];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Ta bort rutten?', style: TextStyle(color: Colors.white, fontSize: 14)),
        content: Text(
          'Vill du ta bort rutten "${r.name.isEmpty ? r.network : r.name}"?\n\n'
          'Ändringen sparas i kandidaten men slår inte igenom på brandväggen förrän du '
          'trycker Applicera.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Avbryt')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Ta bort'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = List<StaticRouteModel>.from(cfg.staticRoutes)..removeAt(idx);
    provider.updateCandidate(cfg.copyWith(staticRoutes: updated));
  }

  Widget _dialogField(String label, TextEditingController ctrl, {String? hint}) {
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

  void _showEditRouteDialog(BuildContext context, ConfigProvider provider, ConfigModel cfg, int? idx) {
    final isEditing = idx != null;
    final r = isEditing ? cfg.staticRoutes[idx] : null;

    final nameCtrl = TextEditingController(text: r?.name ?? '');
    final networkCtrl = TextEditingController(text: r?.network ?? '');
    final gatewayCtrl = TextEditingController(text: r?.gateway ?? '');
    final descCtrl = TextEditingController(text: r?.description ?? '');
    bool enabled = r?.enabled ?? true;
    String? selectedDevice = r?.interfaceDevice.isEmpty ?? true ? null : r!.interfaceDevice;

    final devices = <String>{for (final i in cfg.interfaces) if (i.device.isNotEmpty) i.device}.toList()..sort();

    String? formError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            isEditing ? 'Redigera rutt' : 'Ny statisk rutt',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 420.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField('Namn (valfritt)', nameCtrl, hint: 't.ex. Kontorsnät via router'),
                const SizedBox(height: 10),
                _dialogField('Nät (CIDR)', networkCtrl, hint: 't.ex. 192.168.113.0/24'),
                const SizedBox(height: 10),
                _dialogField('Gateway', gatewayCtrl, hint: 't.ex. 10.0.0.1'),
                const SizedBox(height: 10),
                Text('Gränssnitt (valfritt)', style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: selectedDevice,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Låt kärnan välja (rekommenderas)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Låt kärnan välja (rekommenderas)')),
                    for (final d in devices) DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) => setState(() => selectedDevice = v),
                ),
                const SizedBox(height: 10),
                _dialogField('Beskrivning (valfritt)', descCtrl),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: enabled,
                      activeColor: Colors.tealAccent,
                      checkColor: Colors.black,
                      onChanged: (v) => setState(() => enabled = v ?? true),
                    ),
                    const Text('Aktiverad', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
                if (formError != null) ...[
                  const SizedBox(height: 8),
                  Text(formError!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Avbryt')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
              onPressed: () {
                // Enkel klientvalidering — den auktoritativa kontrollen
                // (giltig CIDR/IP, ingen krock, känt gränssnitt) görs ändå av
                // validateStaticRoutes i backend vid Apply, men ett omedelbart
                // fel här är bättre UX än att behöva trycka Applicera för att
                // upptäcka en felstavning.
                final network = networkCtrl.text.trim();
                final gateway = gatewayCtrl.text.trim();
                if (network.isEmpty || !network.contains('/')) {
                  setState(() => formError = 'Nätet måste anges som CIDR, t.ex. 192.168.113.0/24');
                  return;
                }
                if (gateway.isEmpty) {
                  setState(() => formError = 'Gateway måste anges, t.ex. 10.0.0.1');
                  return;
                }

                final newRoute = StaticRouteModel(
                  id: isEditing ? r!.id : 'route_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  enabled: enabled,
                  network: network,
                  gateway: gateway,
                  interfaceDevice: selectedDevice ?? '',
                  description: descCtrl.text.trim(),
                );

                final updated = List<StaticRouteModel>.from(cfg.staticRoutes);
                if (isEditing) {
                  updated[idx] = newRoute;
                } else {
                  updated.add(newRoute);
                }
                provider.updateCandidate(cfg.copyWith(staticRoutes: updated));
                Navigator.pop(ctx);
              },
              child: const Text('Spara', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
