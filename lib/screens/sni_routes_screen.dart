import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../widgets/dialog_helpers.dart';
import '../localization.dart';

/// Namnbaserad routning (SNI passthrough). En regel = en lyssnarport där
/// flera värdnamn dirigeras till olika interna servrar utan att TLS
/// termineras. Fallback (sista instans) kan vara en intern server eller
/// brandväggens egen OpenVPN.
class SniRoutesScreen extends StatelessWidget {
  const SniRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final cfg = provider.candidateConfig ?? provider.runningConfig;
    final routes = cfg?.sniRoutes ?? [];

    return Container(
      color: AppColors.bg,
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(tr('sni.namnbaserad_routning_sni'),
                      style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 14),
                  label: Text(tr('sni.ny_regel'), style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                  onPressed: cfg == null ? null : () => _showEditDialog(context, provider, cfg, null),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              tr('sni.intro_body'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            if (cfg == null)
              Text(tr('sni.laddar'), style: TextStyle(color: AppColors.textMuted))
            else if (routes.isEmpty)
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text('Inga regler ännu. Skapa en med "+ Ny regel".', style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                ),
              )
            else
              ...routes.asMap().entries.map((e) => _buildRouteCard(context, provider, cfg, e.key, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, ConfigProvider provider, ConfigModel cfg, int idx, SNIRouteModel r) {
    String targetLabel(SNIBackendModel b) => b.isLocalOpenVPN ? tr('sni.lokal_openvpn') : '${b.targetIp}:${b.targetPort}';
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        dense: true,
        leading: Icon(Icons.alt_route, size: 18, color: r.enabled ? Colors.tealAccent : AppColors.textMuted),
        title: Text('${r.name.isNotEmpty ? r.name : r.id}  ·  TCP ${r.listenPort}${r.externalIp.isNotEmpty ? " @ ${r.externalIp}" : ""}',
            style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
        subtitle: Text(trp('sni.namn_mal_count', {'n': '${r.backends.length}'}) + (r.defaultBackend != null ? trp('sni.fallback_suffix', {'target': targetLabel(r.defaultBackend!)}) : ''),
            style: const TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.cyanAccent, size: 16),
              tooltip: tr('sni.redigera'),
              onPressed: () => _showEditDialog(context, provider, cfg, idx),
            ),
            Switch(
              value: r.enabled,
              activeThumbColor: Colors.tealAccent,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) {
                final updated = List<SNIRouteModel>.from(cfg.sniRoutes);
                updated[idx] = r.copyWith(enabled: v);
                provider.updateCandidate(cfg.copyWith(sniRoutes: updated));
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 16),
              tooltip: tr('sni.ta_bort'),
              onPressed: () {
                final updated = List<SNIRouteModel>.from(cfg.sniRoutes)..removeAt(idx);
                provider.updateCandidate(cfg.copyWith(sniRoutes: updated));
              },
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final b in r.backends)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• ${b.hostnames.join(", ")}  →  ${targetLabel(b)}',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ),
                if (r.defaultBackend != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• (fallback / sista instans)  →  ${targetLabel(r.defaultBackend!)}',
                        style: const TextStyle(color: Colors.amber, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, ConfigProvider provider, ConfigModel cfg, int? idx) {
    final existing = idx != null ? cfg.sniRoutes[idx] : null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final portCtrl = TextEditingController(text: '${existing?.listenPort ?? 443}');
    final extIpCtrl = TextEditingController(text: existing?.externalIp ?? '');

    final backends = <_BackendEdit>[];
    if (existing != null) {
      for (final b in existing.backends) {
        backends.add(_BackendEdit.fromModel(b));
      }
    }
    if (backends.isEmpty) {
      backends.add(_BackendEdit());
    }

    bool fallbackOn = existing?.defaultBackend != null;
    final fallback = existing?.defaultBackend != null
        ? _BackendEdit.fromModel(existing!.defaultBackend!)
        : _BackendEdit(type: 'openvpn');

    final ovpnEnabled = cfg.openvpn?.enabled ?? false;
    final ovpnTcp = (cfg.openvpn?.protocol ?? '').toLowerCase() == 'tcp';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          child: Container(
            width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 560.0),
            constraints: const BoxConstraints(maxHeight: 680),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  dialogTitleRow(context, existing == null ? tr('sni.ny_sni_regel') : tr('sni.redigera_sni_regel'), () => Navigator.pop(ctx)),
                  const SizedBox(height: 12),
                  dialogSection(title: tr('sni.section_regel'), children: [
                    dialogField(nameCtrl, tr('sni.namn'), hint: tr('sni.namn_hint')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: dialogField(portCtrl, tr('sni.lyssnarport'), hint: '443')),
                        const SizedBox(width: 12),
                        Expanded(child: dialogField(extIpCtrl, tr('sni.extern_ip_valfri'), hint: tr('sni.bind_alla_om_tom'))),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 12),
                  dialogSection(title: tr('sni.section_namn_till_server'), children: [
                    for (int i = 0; i < backends.length; i++)
                      _buildBackendEditor(context, setState, backends[i], ovpnEnabled, ovpnTcp, allowLocal: true, onRemove: backends.length > 1 ? () => setState(() => backends.removeAt(i)) : null),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(Icons.add, size: 14, color: Colors.cyanAccent),
                        label: Text(tr('sni.lagg_till_mal'), style: TextStyle(fontSize: 11, color: Colors.cyanAccent)),
                        onPressed: () => setState(() => backends.add(_BackendEdit())),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  dialogSection(title: tr('sni.section_fallback'), children: [
                    Row(
                      children: [
                        Switch(
                          value: fallbackOn,
                          activeThumbColor: Colors.tealAccent,
                          onChanged: (v) => setState(() => fallbackOn = v),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(tr('sni.trafik_utan_matchande_namn_t_ex'),
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ),
                      ],
                    ),
                    if (fallbackOn) ...[
                      const SizedBox(height: 8),
                      _buildBackendEditor(context, setState, fallback, ovpnEnabled, ovpnTcp, allowLocal: true, isFallback: true, onRemove: null),
                    ],
                  ]),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('sni.avbryt'), style: TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                        child: Text(tr('sni.spara'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          final port = int.tryParse(portCtrl.text.trim()) ?? 0;
                          final route = SNIRouteModel(
                            id: existing?.id ?? 'sni_${DateTime.now().millisecondsSinceEpoch}',
                            name: nameCtrl.text.trim(),
                            enabled: existing?.enabled ?? true,
                            listenPort: port,
                            externalIp: extIpCtrl.text.trim(),
                            backends: backends.map((b) => b.toModel()).toList(),
                            defaultBackend: fallbackOn ? fallback.toModel() : null,
                          );
                          final updated = List<SNIRouteModel>.from(cfg.sniRoutes);
                          if (idx != null) {
                            updated[idx] = route;
                          } else {
                            updated.add(route);
                          }
                          provider.updateCandidate(cfg.copyWith(sniRoutes: updated));
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackendEditor(BuildContext context, void Function(void Function()) setState, _BackendEdit b, bool ovpnEnabled, bool ovpnTcp,
      {required bool allowLocal, bool isFallback = false, VoidCallback? onRemove}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: b.type,
                  dropdownColor: AppColors.surface,
                  style: TextStyle(color: AppColors.text, fontSize: 12),
                  decoration: InputDecoration(labelText: tr('sni.maltyp'), isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  items: [
                    DropdownMenuItem(value: 'internal', child: Text(tr('sni.intern_server'))),
                    if (allowLocal) DropdownMenuItem(value: 'openvpn', child: Text(tr('sni.lokal_openvpn'))),
                  ],
                  onChanged: (v) => setState(() => b.type = v ?? 'internal'),
                ),
              ),
              if (onRemove != null)
                IconButton(icon: Icon(Icons.close, size: 16, color: Colors.redAccent), onPressed: onRemove, tooltip: tr('sni.ta_bort_mal')),
            ],
          ),
          if (b.type == 'openvpn' && (!ovpnEnabled || !ovpnTcp))
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(tr('sni.obs_kraver_att_openvpn_ar_aktiverat'), style: TextStyle(color: Colors.amber, fontSize: 10)),
            ),
          if (b.type != 'openvpn') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(flex: 3, child: dialogField(b.ip, tr('sni.intern_ip'), hint: '192.168.1.10')),
                const SizedBox(width: 8),
                Expanded(flex: 2, child: dialogField(b.port, tr('sni.port'), hint: '8006')),
              ],
            ),
          ],
          if (!isFallback) ...[
            const SizedBox(height: 8),
            dialogField(b.hostnames, tr('sni.vardnamn_label'), hint: tr('sni.vardnamn_hint')),
          ],
        ],
      ),
    );
  }
}

/// Muterbart redigeringstillstånd för en backend i editor-dialogen.
class _BackendEdit {
  final TextEditingController hostnames;
  final TextEditingController ip;
  final TextEditingController port;
  String type; // 'internal' | 'openvpn'

  _BackendEdit({String hostnames = '', String ip = '', int port = 443, this.type = 'internal'})
      : hostnames = TextEditingController(text: hostnames),
        ip = TextEditingController(text: ip),
        port = TextEditingController(text: port == 0 ? '' : '$port');

  factory _BackendEdit.fromModel(SNIBackendModel b) => _BackendEdit(
        hostnames: b.hostnames.join(', '),
        ip: b.targetIp,
        port: b.targetPort,
        type: b.isLocalOpenVPN ? 'openvpn' : 'internal',
      );

  SNIBackendModel toModel() {
    final names = hostnames.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (type == 'openvpn') {
      return SNIBackendModel(hostnames: names, localService: 'openvpn');
    }
    return SNIBackendModel(hostnames: names, targetIp: ip.text.trim(), targetPort: int.tryParse(port.text.trim()) ?? 0);
  }
}
