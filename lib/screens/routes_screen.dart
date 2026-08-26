import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../localization.dart';

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
      color: AppColors.bg,
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surface,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.alt_route, color: Colors.cyanAccent, size: 20),
                    SizedBox(width: 8),
                    Text(tr('routes.statiska_rutter_routing'),
                      style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16, color: Colors.cyanAccent),
                  label: Text(tr('routes.ny_rutt'), style: TextStyle(fontSize: 12, color: Colors.white)),
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
            color: AppColors.bg,
            child: Text(
              tr('routes.intro_body'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),

          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: routes.isEmpty
                  ? Center(
                      child: Text(tr('routes.inga_statiska_rutter_definierade'),
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: routes.length,
                      separatorBuilder: (_, _) => Divider(color: AppColors.border, height: 1),
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
            color: r.enabled ? Colors.tealAccent : AppColors.textMuted,
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
                color: r.enabled ? AppColors.text : AppColors.textMuted,
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
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                children: [
                  TextSpan(text: r.network, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  const TextSpan(text: '  via  '),
                  TextSpan(text: r.gateway, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  if (r.interfaceDevice.isNotEmpty) TextSpan(text: '  dev ${r.interfaceDevice}', style: TextStyle(color: AppColors.textFaint)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 16, color: Colors.cyanAccent),
            tooltip: tr('routes.redigera_rutt'),
            onPressed: () => _showEditRouteDialog(context, provider, cfg, idx),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
            tooltip: tr('routes.ta_bort_rutt'),
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
        backgroundColor: AppColors.surface,
        title: Text(tr('routes.ta_bort_rutten'), style: TextStyle(color: AppColors.text, fontSize: 14)),
        content: Text(
          trp('routes.delete_confirm_body', {'name': r.name.isEmpty ? r.network : r.name}),
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(tr('routes.avbryt'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(tr('routes.ta_bort')),
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
          backgroundColor: AppColors.surface,
          title: Text(
            isEditing ? tr('routes.redigera_rutt') : tr('routes.ny_statisk_rutt'),
            style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 420.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogField(tr('routes.namn_valfritt'), nameCtrl, hint: tr('routes.namn_hint')),
                const SizedBox(height: 10),
                _dialogField(tr('routes.nat_cidr'), networkCtrl, hint: tr('routes.nat_hint')),
                const SizedBox(height: 10),
                _dialogField(tr('routes.gateway'), gatewayCtrl, hint: tr('routes.gateway_hint')),
                const SizedBox(height: 10),
                Text(tr('routes.granssnitt_valfritt'), style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: selectedDevice,
                  dropdownColor: AppColors.surface,
                  style: TextStyle(color: AppColors.text, fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  hint: Text(tr('routes.lat_karnan_valja_rekommenderas'), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  items: [
                    DropdownMenuItem(value: null, child: Text(tr('routes.lat_karnan_valja_rekommenderas'))),
                    for (final d in devices) DropdownMenuItem(value: d, child: Text(d)),
                  ],
                  onChanged: (v) => setState(() => selectedDevice = v),
                ),
                const SizedBox(height: 10),
                _dialogField(tr('routes.beskrivning_valfritt'), descCtrl),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: enabled,
                      activeColor: Colors.tealAccent,
                      checkColor: Colors.black,
                      onChanged: (v) => setState(() => enabled = v ?? true),
                    ),
                    Text(tr('routes.aktiverad'), style: TextStyle(color: AppColors.text, fontSize: 12)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('routes.avbryt'))),
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
                  setState(() => formError = tr('routes.error_cidr'));
                  return;
                }
                if (gateway.isEmpty) {
                  setState(() => formError = tr('routes.error_gateway'));
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
              child: Text(tr('routes.spara'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
