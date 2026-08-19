import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';

/// Säkerhetshändelser (Fas 9) — visar Suricata-larm och låter admin styra
/// IDS-läge/auto-block. Inline-IPS (aktiv realtidsblockering) byggs INTE
/// här — bara passiv övervakning + valfri eftersläpande auto-block mot ett
/// objekt användaren själv skapat, se IDSConfigModel.
class SecurityEventsScreen extends StatefulWidget {
  const SecurityEventsScreen({super.key});

  @override
  State<SecurityEventsScreen> createState() => _SecurityEventsScreenState();
}

class _SecurityEventsScreenState extends State<SecurityEventsScreen> {
  List<SecurityEventModel> _events = [];
  bool _loading = false;
  Timer? _pollTimer;

  final _ifaceController = TextEditingController();
  final _objectIdController = TextEditingController();
  int _autoBlockSeverity = 2;
  bool _isSavingIds = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _ifaceController.dispose();
    _objectIdController.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    if (!provider.isAuthenticated) return;
    setState(() => _loading = true);
    final events = await provider.api.getSecurityEvents();
    if (!mounted) return;
    setState(() {
      _events = events.reversed.toList(); // nyast först
      _loading = false;
    });
  }

  Color _severityColor(int severity) {
    switch (severity) {
      case 1:
        return Colors.redAccent;
      case 2:
        return Colors.orangeAccent;
      default:
        return Colors.amberAccent;
    }
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
          children: [
            Row(
              children: [
                const Icon(Icons.gpp_maybe_outlined, color: Colors.redAccent, size: 22),
                const SizedBox(width: 10),
                const Text('Säkerhetshändelser (IDS)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: _loading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                      : const Icon(Icons.refresh, size: 18, color: Colors.cyanAccent),
                  onPressed: _loading ? null : _poll,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Passiv övervakning (Suricata, af-packet-läge) — larmar men blockerar inte trafik i realtid. Se inställningarna nedan för valfri eftersläpande auto-blockering.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 14),

            if (provider.isAdmin) _buildIdsSettingsCard(provider),
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                border: Border.all(color: const Color(0xFF334155)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('${_events.length} larm (senaste 1000 raderna i eve.json)',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(color: Color(0xFF334155), height: 1),
                  if (_events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Inga larm ännu.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 34,
                        dataRowMinHeight: 32,
                        dataRowMaxHeight: 32,
                        columns: const [
                          DataColumn(label: Text('Tid', style: TextStyle(color: Colors.grey, fontSize: 11))),
                          DataColumn(label: Text('Allvarlighet', style: TextStyle(color: Colors.grey, fontSize: 11))),
                          DataColumn(label: Text('Signatur', style: TextStyle(color: Colors.grey, fontSize: 11))),
                          DataColumn(label: Text('Kategori', style: TextStyle(color: Colors.grey, fontSize: 11))),
                          DataColumn(label: Text('Källa', style: TextStyle(color: Colors.grey, fontSize: 11))),
                          DataColumn(label: Text('Mål', style: TextStyle(color: Colors.grey, fontSize: 11))),
                          DataColumn(label: Text('Protokoll', style: TextStyle(color: Colors.grey, fontSize: 11))),
                        ],
                        rows: _events
                            .map((e) => DataRow(cells: [
                                  DataCell(Text(e.timestamp, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _severityColor(e.severity).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: _severityColor(e.severity)),
                                    ),
                                    child: Text('${e.severity}', style: TextStyle(color: _severityColor(e.severity), fontSize: 11, fontWeight: FontWeight.bold)),
                                  )),
                                  DataCell(SizedBox(width: 320, child: Text(e.signature, style: const TextStyle(color: Colors.white, fontSize: 11)))),
                                  DataCell(Text(e.category, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                  DataCell(Text('${e.srcIp}:${e.srcPort}', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                  DataCell(Text('${e.dstIp}:${e.dstPort}', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                  DataCell(Text(e.protocol, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                ]))
                            .toList(),
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

  Widget _buildIdsSettingsCard(ConfigProvider provider) {
    final ConfigModel? cfg = provider.candidateConfig ?? provider.runningConfig;
    final ids = cfg?.ids ?? IDSConfigModel(enabled: false);
    final interfaces = cfg?.interfaces ?? <InterfaceModel>[];
    if (_ifaceController.text.isEmpty && ids.interfaceDevice.isNotEmpty) {
      _ifaceController.text = ids.interfaceDevice;
    }
    if (_objectIdController.text.isEmpty && ids.autoBlockObjectId.isNotEmpty) {
      _objectIdController.text = ids.autoBlockObjectId;
    }
    _autoBlockSeverity = ids.autoBlockSeverity == 0 ? 2 : ids.autoBlockSeverity;
    String? selectedIface = interfaces.any((i) => i.device == _ifaceController.text) ? _ifaceController.text : null;

    Future<void> save(IDSConfigModel updated) async {
      if (cfg == null) return;
      setState(() => _isSavingIds = true);
      await provider.updateCandidate(cfg.copyWith(ids: updated));
      if (mounted) setState(() => _isSavingIds = false);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border.all(color: const Color(0xFF334155)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, color: Colors.redAccent, size: 16),
              const SizedBox(width: 8),
              const Text('IDS-inställningar', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(
                value: ids.enabled,
                activeThumbColor: Colors.tealAccent,
                onChanged: selectedIface == null && !ids.enabled
                    ? null
                    : (v) => save(ids.copyWith(enabled: v, interfaceDevice: _ifaceController.text)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              initialValue: selectedIface,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Gränssnitt att övervaka',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                border: OutlineInputBorder(),
              ),
              items: interfaces
                  .map((i) => DropdownMenuItem(value: i.device, child: Text('${i.device} (${i.zone})', style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (v) => setState(() => _ifaceController.text = v ?? ''),
            ),
          ),
          const Divider(color: Colors.white10, height: 28),
          Row(
            children: [
              Switch(
                value: ids.autoBlock,
                activeThumbColor: Colors.orangeAccent,
                onChanged: (v) => save(ids.copyWith(autoBlock: v, autoBlockObjectId: _objectIdController.text, autoBlockSeverity: _autoBlockSeverity)),
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Auto-block: lägg käll-IP från larm till ett objekt (kräver en egen Deny-policy som refererar objektet för att faktiskt blockera)',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _objectIdController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Objekt-ID (från Objekt-vyn)',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<int>(
                  initialValue: _autoBlockSeverity,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Max allvarlighetsgrad',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    border: OutlineInputBorder(),
                  ),
                  items: const [1, 2, 3].map((n) => DropdownMenuItem(value: n, child: Text('$n', style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setState(() => _autoBlockSeverity = v ?? 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: _isSavingIds
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.save, size: 14),
            label: const Text('Spara', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () => save(ids.copyWith(
              interfaceDevice: _ifaceController.text,
              autoBlockObjectId: _objectIdController.text,
              autoBlockSeverity: _autoBlockSeverity,
            )),
          ),
        ],
      ),
    );
  }
}
