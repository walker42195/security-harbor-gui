import 'dart:async';
import '../theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../localization.dart';

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

  // Filter (samma mönster som Loggning-sidan) — ett fält per kolumn.
  final _fTid = TextEditingController();
  final _fSignatur = TextEditingController();
  final _fKategori = TextEditingController();
  final _fKalla = TextEditingController();
  final _fMal = TextEditingController();
  final _fProtokoll = TextEditingController();
  String _fSeverity = 'ALL'; // ALL, 1, 2, 3

  List<SecurityEventModel> get _filteredEvents {
    bool has(TextEditingController c, String v) {
      final f = c.text.trim().toLowerCase();
      return f.isEmpty || v.toLowerCase().contains(f);
    }

    return _events.where((e) {
      if (_fSeverity != 'ALL' && '${e.severity}' != _fSeverity) return false;
      return has(_fTid, e.timestamp) &&
          has(_fSignatur, e.signature) &&
          has(_fKategori, e.category) &&
          has(_fKalla, '${e.srcIp}:${e.srcPort}') &&
          has(_fMal, '${e.dstIp}:${e.dstPort}') &&
          has(_fProtokoll, e.protocol);
    }).toList();
  }

  bool get _hasActiveFilter =>
      _fSeverity != 'ALL' ||
      [_fTid, _fSignatur, _fKategori, _fKalla, _fMal, _fProtokoll].any((c) => c.text.trim().isNotEmpty);

  void _clearFilters() => setState(() {
        _fTid.clear();
        _fSignatur.clear();
        _fKategori.clear();
        _fKalla.clear();
        _fMal.clear();
        _fProtokoll.clear();
        _fSeverity = 'ALL';
      });

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
    _fTid.dispose();
    _fSignatur.dispose();
    _fKategori.dispose();
    _fKalla.dispose();
    _fMal.dispose();
    _fProtokoll.dispose();
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
        return AppColors.danger;
      case 2:
        return AppColors.caution;
      default:
        return AppColors.warn;
    }
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
          children: [
            Row(
              children: [
                Icon(Icons.gpp_maybe_outlined, color: AppColors.danger, size: 22),
                const SizedBox(width: 10),
                Text(tr('sec.sakerhetshandelser_ids'), style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: _loading
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                      : Icon(Icons.refresh, size: 18, color: AppColors.accent),
                  onPressed: _loading ? null : _poll,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(tr('sec.passiv_overvakning_suricata_af_packet_lage'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 14),

            if (provider.isAdmin) _buildIdsSettingsCard(provider),
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (context) {
                    final filtered = _filteredEvents;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Text(
                                _hasActiveFilter
                                    ? '${filtered.length} av ${_events.length} larm (filtrerat)'
                                    : '${_events.length} larm (senaste 1000 raderna i eve.json)',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              // Info-overlay: vad IDS är, hur det fungerar, länk till Suricata.
                              InkWell(
                                onTap: () => _showIdsInfo(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Icon(Icons.help_outline, size: 18, color: AppColors.accent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(color: AppColors.border, height: 1),
                        _buildIdsFilterBar(),
                        Divider(color: AppColors.border, height: 1),
                        if (_events.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(tr('sec.inga_larm_annu'), style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                          )
                        else if (filtered.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(tr('sec.inga_larm_matchar_filtret'), style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                          )
                        else
                          // Samma skäl som i Loggning-vyn: man vill kunna
                          // dra ut en IP-adress eller ett signaturnamn ur
                          // tabellen med musen. SelectionArea hoppas över på
                          // web, där den renderar tabellen som en tom ruta.
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _maybeSelectable(DataTable(
                              headingRowHeight: 34,
                              dataRowMinHeight: 32,
                              dataRowMaxHeight: 32,
                              showCheckboxColumn: false,
                              columns: [
                                DataColumn(label: Text(tr('sec.tid'), style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                DataColumn(label: Text(tr('sec.allvarlighet'), style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                DataColumn(label: Text(tr('sec.signatur'), style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                DataColumn(label: Text(tr('sec.kategori'), style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                DataColumn(label: Text(tr('sec.kalla'), style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                DataColumn(label: Text(tr('sec.mal'), style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                DataColumn(label: Text(tr('sec.protokoll'), style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                              ],
                              rows: filtered
                                  .map((e) => DataRow(
                                        onSelectChanged: (_) => _showEventDetail(e),
                                        cells: [
                                          DataCell(Text(e.timestamp, style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                          DataCell(Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _severityColor(e.severity).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: _severityColor(e.severity)),
                                            ),
                                            child: Text('${e.severity}', style: TextStyle(color: _severityColor(e.severity), fontSize: 11, fontWeight: FontWeight.bold)),
                                          )),
                                          DataCell(SizedBox(width: 320, child: Text(e.signature, style: TextStyle(color: AppColors.text, fontSize: 11), overflow: TextOverflow.ellipsis))),
                                          DataCell(Text(e.category, style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                          DataCell(Text('${e.srcIp}:${e.srcPort}', style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                          DataCell(Text('${e.dstIp}:${e.dstPort}', style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                          DataCell(Text(e.protocol, style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                                        ],
                                      ))
                                  .toList(),
                            )),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdsFilterBar() {
    Widget field(String label, TextEditingController c, double width) => SizedBox(
          width: width,
          height: 32,
          child: TextField(
            controller: c,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 11, color: Colors.white),
            decoration: InputDecoration(
              isDense: true,
              labelText: label,
              labelStyle: TextStyle(fontSize: 10, color: AppColors.textMuted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: const OutlineInputBorder(),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          field(tr('sec.tid'), _fTid, 150),
          SizedBox(
            height: 32,
            child: DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                child: DropdownButton<String>(
                  value: _fSeverity,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  items: [
                    DropdownMenuItem(value: 'ALL', child: Text(tr('sec.allvarlighet_alla'))),
                    DropdownMenuItem(value: '1', child: Text(tr('sec.allvarlighet_1_hog'))),
                    DropdownMenuItem(value: '2', child: Text(tr('sec.allvarlighet_2_medel'))),
                    DropdownMenuItem(value: '3', child: Text(tr('sec.allvarlighet_3_lag'))),
                  ],
                  onChanged: (v) => setState(() => _fSeverity = v ?? 'ALL'),
                ),
              ),
            ),
          ),
          field(tr('sec.signatur'), _fSignatur, 220),
          field(tr('sec.kategori'), _fKategori, 180),
          field(tr('sec.kalla_ip_port'), _fKalla, 150),
          field(tr('sec.mal_ip_port'), _fMal, 150),
          field(tr('sec.protokoll'), _fProtokoll, 100),
          TextButton.icon(
            icon: Icon(Icons.clear, size: 14, color: AppColors.textMuted),
            label: Text(tr('sec.rensa_filter'), style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            onPressed: _hasActiveFilter ? _clearFilters : null,
          ),
        ],
      ),
    );
  }

  void _showEventDetail(SecurityEventModel e) {
    Widget row(String k, String v, {Color? valueColor}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: Text(k, style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
              Expanded(child: SelectableText(v.isEmpty ? '—' : v, style: TextStyle(color: valueColor ?? AppColors.text, fontSize: 12))),
            ],
          ),
        );

    showDialog(
      context: context,
      builder: (dctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.gpp_maybe_outlined, color: _severityColor(e.severity), size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr('sec.larmdetaljer'), style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold))),
                    IconButton(icon: Icon(Icons.close, color: AppColors.textMuted, size: 18), onPressed: () => Navigator.pop(dctx)),
                  ],
                ),
                Divider(color: AppColors.border),
                const SizedBox(height: 4),
                row(tr('sec.signatur'), e.signature),
                row(tr('sec.allvarlighet'), '${e.severity}  (${e.severity == 1 ? tr('sec.hog') : e.severity == 2 ? tr('sec.medel') : tr('sec.lag')})', valueColor: _severityColor(e.severity)),
                row(tr('sec.kategori'), e.category),
                row(tr('sec.tidpunkt'), e.timestamp),
                row(tr('sec.protokoll'), e.protocol),
                row(tr('sec.kalla'), '${e.srcIp}${e.srcPort != 0 ? ":${e.srcPort}" : ""}'),
                row(tr('sec.mal'), '${e.dstIp}${e.dstPort != 0 ? ":${e.dstPort}" : ""}'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.category.toLowerCase().contains('generic protocol command decode')
                              ? tr('sec.decoder_alert_note')
                              : tr('sec.signature_alert_note'),
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: Icon(Icons.open_in_new, size: 14, color: AppColors.accent),
                    label: Text(tr('sec.sok_signaturen_pa_suricata_io'), style: TextStyle(color: AppColors.accent, fontSize: 11)),
                    onPressed: _openSuricata,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSuricata() async {
    final uri = Uri.parse('https://suricata.io/');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('sec.kunde_inte_oppna_lanken_adress_https'))),
        );
      }
    }
  }

  void _showIdsInfo(BuildContext context) {
    Widget para(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(s, style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
        );
    Widget head(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 2),
          child: Text(s, style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold)),
        );

    showDialog(
      context: context,
      builder: (dctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tr('sec.vad_ar_ids_och_vad_betyder'),
                          style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppColors.textMuted, size: 18),
                      onPressed: () => Navigator.pop(dctx),
                    ),
                  ],
                ),
                Divider(color: AppColors.border),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        head(tr('sec.help_head_1')),
                        para(tr('sec.help_para_1')),
                        head(tr('sec.help_head_2')),
                        para(tr('sec.help_para_2')),
                        head(tr('sec.help_head_3')),
                        para(tr('sec.help_para_3')),
                        head(tr('sec.help_head_4')),
                        para(tr('sec.help_para_4')),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: _openSuricata,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_new, size: 14, color: AppColors.accent),
                              SizedBox(width: 6),
                              Text(tr('sec.las_mer_pa_suricata_io'),
                                  style: TextStyle(color: AppColors.accent, fontSize: 12, decoration: TextDecoration.underline)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    if (_objectIdController.text.isEmpty) {
      if (ids.autoBlockObjectId.isNotEmpty) {
        _objectIdController.text = ids.autoBlockObjectId;
      } else {
        // Förifyll standard-objektet "IPS - Auto block" om det finns, så
        // fältet är redo direkt (Auto-block är fortfarande avstängt tills
        // användaren själv slår på det).
        final ips = (cfg?.objects ?? []).where((o) => o.name == 'IPS - Auto block');
        if (ips.isNotEmpty) _objectIdController.text = ips.first.id;
      }
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
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radar, color: AppColors.danger, size: 16),
              const SizedBox(width: 8),
              Text(tr('sec.ids_installningar'), style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Switch(
                value: ids.enabled,
                activeThumbColor: AppColors.ok,
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
              decoration: InputDecoration(
                labelText: tr('sec.granssnitt_att_overvaka'),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                border: OutlineInputBorder(),
              ),
              items: interfaces
                  .map((i) => DropdownMenuItem(value: i.device, child: Text('${i.device} (${i.zone})', style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (v) => setState(() => _ifaceController.text = v ?? ''),
            ),
          ),
          Divider(color: AppColors.divider, height: 28),
          Row(
            children: [
              Switch(
                value: ids.autoBlock,
                activeThumbColor: AppColors.caution,
                onChanged: (v) => save(ids.copyWith(autoBlock: v, autoBlockObjectId: _objectIdController.text, autoBlockSeverity: _autoBlockSeverity)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(tr('sec.auto_block_kall_ip_n_fran'),
                  style: TextStyle(color: AppColors.text, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: (cfg?.objects.any((o) => o.id == _objectIdController.text) ?? false)
                      ? _objectIdController.text
                      : null,
                  isDense: true,
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  style: TextStyle(color: AppColors.text, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: tr('sec.objekt_att_blockera_ip_i'),
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: (cfg?.objects ?? <ObjectModel>[])
                      .map((o) => DropdownMenuItem(
                            value: o.id,
                            child: Text(o.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _objectIdController.text = v ?? ''),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<int>(
                  initialValue: _autoBlockSeverity,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: tr('sec.max_allvarlighetsgrad'),
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
            label: Text(tr('sec.spara'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onStatus),
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

/// SelectionArea överallt utom på web (där CanvasKit renderar den anpassade
/// tabellen som en tom ljusgrå ruta i stället för innehållet).
Widget _maybeSelectable(Widget child) => kIsWeb ? child : SelectionArea(child: child);
