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
/// IDS-läge/auto-block. Ger möjlighet att växla mellan realtidslarm (eve.json)
/// och larmhistorik (fast.log) med avancerad tids- och blockeringsfiltrering.
class SecurityEventsScreen extends StatefulWidget {
  const SecurityEventsScreen({super.key});

  @override
  State<SecurityEventsScreen> createState() => _SecurityEventsScreenState();
}

class _SecurityEventsScreenState extends State<SecurityEventsScreen> {
  List<SecurityEventModel> _events = [];
  bool _loading = false;
  Timer? _pollTimer;

  // Källa: 'live' (eve.json) eller 'history' (fast.log)
  String _source = 'live';

  final _ifaceController = TextEditingController();
  final _objectIdController = TextEditingController();
  int _autoBlockSeverity = 2;
  bool _isSavingIds = false;

  // Filter — tidsfönster, autoblock och kolumnfilter.
  String _timeWindow = 'ALL'; // ALL, 15m, 1h, 6h, 24h, 7d
  bool _onlyAutoBlockCandidates = false;
  final _fTid = TextEditingController();
  final _fSignatur = TextEditingController();
  final _fKategori = TextEditingController();
  final _fKalla = TextEditingController();
  final _fMal = TextEditingController();
  final _fProtokoll = TextEditingController();
  String _fSeverity = 'ALL'; // ALL, 1, 2, 3

  bool _matchesTimeWindow(String ts) {
    if (_timeWindow == 'ALL') return true;
    try {
      DateTime? dt;
      if (ts.contains('-') && ts.contains('T')) {
        final clean = ts.replaceAllMapped(RegExp(r'([+-]\d{2})(\d{2})$'), (m) => '${m[1]}:${m[2]}');
        dt = DateTime.tryParse(clean);
      } else if (ts.length >= 19 && ts.contains('/')) {
        final parts = ts.split('-');
        final dateParts = parts[0].split('/');
        if (dateParts.length == 3) {
          final m = int.tryParse(dateParts[0]) ?? 1;
          final d = int.tryParse(dateParts[1]) ?? 1;
          final y = int.tryParse(dateParts[2]) ?? 2026;
          final timeParts = parts[1].split(':');
          final hh = int.tryParse(timeParts[0]) ?? 0;
          final mm = int.tryParse(timeParts[1]) ?? 0;
          final ssParts = timeParts[2].split('.');
          final ss = int.tryParse(ssParts[0]) ?? 0;
          dt = DateTime(y, m, d, hh, mm, ss);
        }
      }
      if (dt == null) return true;
      final now = DateTime.now();
      Duration window;
      switch (_timeWindow) {
        case '15m':
          window = const Duration(minutes: 15);
          break;
        case '1h':
          window = const Duration(hours: 1);
          break;
        case '6h':
          window = const Duration(hours: 6);
          break;
        case '24h':
          window = const Duration(hours: 24);
          break;
        case '7d':
          window = const Duration(days: 7);
          break;
        default:
          return true;
      }
      return now.difference(dt) <= window;
    } catch (_) {
      return true;
    }
  }

  List<SecurityEventModel> get _filteredEvents {
    bool has(TextEditingController c, String v) {
      final f = c.text.trim().toLowerCase();
      return f.isEmpty || v.toLowerCase().contains(f);
    }

    return _events.where((e) {
      if (_onlyAutoBlockCandidates && e.severity > 2) return false;
      if (_fSeverity != 'ALL' && '${e.severity}' != _fSeverity) return false;
      if (!_matchesTimeWindow(e.timestamp)) return false;
      return has(_fTid, e.timestamp) &&
          has(_fSignatur, e.signature) &&
          has(_fKategori, e.category) &&
          has(_fKalla, '${e.srcIp}:${e.srcPort}') &&
          has(_fMal, '${e.dstIp}:${e.dstPort}') &&
          has(_fProtokoll, e.protocol);
    }).toList();
  }

  bool get _hasActiveFilter =>
      _onlyAutoBlockCandidates ||
      _timeWindow != 'ALL' ||
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
        _timeWindow = 'ALL';
        _onlyAutoBlockCandidates = false;
      });

  @override
  void initState() {
    super.initState();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_source == 'live') _poll();
    });
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
    final events = await provider.api.getSecurityEvents(
      source: _source,
      limit: _source == 'history' ? 2000 : 1000,
    );
    if (!mounted) return;
    setState(() {
      _events = events.reversed.toList(); // nyast först
      _loading = false;
    });
  }

  void _switchSource(String newSource) {
    if (_source == newSource) return;
    setState(() {
      _source = newSource;
      _events = [];
    });
    _poll();
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
            Text(
              tr('sec.passiv_overvakning_suricata_af_packet_lage'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 14),

            if (provider.isAdmin) _buildIdsSettingsCard(provider),
            const SizedBox(height: 14),

            // Källväljare / Flikar: Realtid vs Historik
            _buildSourceTabs(),
            const SizedBox(height: 10),

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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _source == 'live' ? AppColors.danger.withValues(alpha: 0.15) : AppColors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: _source == 'live' ? AppColors.danger : AppColors.accent),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _source == 'live' ? Icons.fiber_manual_record : Icons.history,
                                      size: 11,
                                      color: _source == 'live' ? AppColors.danger : AppColors.accent,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _source == 'live' ? tr('sec.mode_live') : tr('sec.mode_history'),
                                      style: TextStyle(
                                        color: _source == 'live' ? AppColors.danger : AppColors.accent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _hasActiveFilter
                                    ? '${filtered.length} av ${_events.length} larm (filtrerat)'
                                    : _source == 'live'
                                        ? '${_events.length} larm (realtidsström eve.json)'
                                        : '${_events.length} larm (larmhistorik fast.log)',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              // Info-overlay: vad IDS är, hur det fungerar, länk till Suricata.
                              InkWell(
                                onTap: () => _showIdsInfo(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(Icons.help_outline, size: 18, color: AppColors.accent),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(color: AppColors.border, height: 1),
                        _buildIdsFilterBar(),
                        Divider(color: AppColors.border, height: 1),
                        if (_events.isEmpty && !_loading)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(tr('sec.inga_larm_annu'), style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                          )
                        else if (filtered.isEmpty && !_loading)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(tr('sec.inga_larm_matchar_filtret'), style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                          )
                        else
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
                                          DataCell(Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _severityColor(e.severity).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: _severityColor(e.severity)),
                                                ),
                                                child: Text('${e.severity}', style: TextStyle(color: _severityColor(e.severity), fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                              if (e.severity <= 2) ...[
                                                const SizedBox(width: 4),
                                                Tooltip(
                                                  message: tr('sec.autoblock_candidate'),
                                                  child: Icon(Icons.shield, size: 13, color: e.severity == 1 ? AppColors.danger : AppColors.caution),
                                                ),
                                              ],
                                            ],
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

  Widget _buildSourceTabs() {
    Widget tab(String label, IconData icon, Color color, String mode) {
      final active = _source == mode;
      return InkWell(
        onTap: () => _switchSource(mode),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            border: Border.all(color: active ? AppColors.accent : Colors.transparent),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? color : AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.text : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tab(tr('sec.mode_live'), Icons.fiber_manual_record, AppColors.danger, 'live'),
          const SizedBox(width: 4),
          tab(tr('sec.mode_history'), Icons.history, AppColors.accent, 'history'),
        ],
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
            style: TextStyle(fontSize: 11, color: AppColors.text),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rad 1: Tidsfönster & Auto-block snabbfilter
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${tr('sec.time_window')}:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 30,
                    child: DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(4)),
                        child: DropdownButton<String>(
                          value: _timeWindow,
                          dropdownColor: AppColors.surface,
                          style: TextStyle(fontSize: 11, color: AppColors.text),
                          items: [
                            DropdownMenuItem(value: 'ALL', child: Text(tr('sec.time_all'))),
                            DropdownMenuItem(value: '15m', child: Text(tr('sec.time_15m'))),
                            DropdownMenuItem(value: '1h', child: Text(tr('sec.time_1h'))),
                            DropdownMenuItem(value: '6h', child: Text(tr('sec.time_6h'))),
                            DropdownMenuItem(value: '24h', child: Text(tr('sec.time_24h'))),
                            DropdownMenuItem(value: '7d', child: Text(tr('sec.time_7d'))),
                          ],
                          onChanged: (v) => setState(() => _timeWindow = v ?? 'ALL'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _onlyAutoBlockCandidates = !_onlyAutoBlockCandidates),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: _onlyAutoBlockCandidates ? AppColors.caution.withValues(alpha: 0.15) : AppColors.surface,
                    border: Border.all(color: _onlyAutoBlockCandidates ? AppColors.caution : AppColors.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _onlyAutoBlockCandidates ? Icons.shield : Icons.shield_outlined,
                        size: 13,
                        color: _onlyAutoBlockCandidates ? AppColors.caution : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tr('sec.filter_autoblock_only'),
                        style: TextStyle(
                          fontSize: 11,
                          color: _onlyAutoBlockCandidates ? AppColors.caution : AppColors.text,
                          fontWeight: _onlyAutoBlockCandidates ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Rad 2: Kolumnfilter
          Wrap(
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
                      style: TextStyle(fontSize: 11, color: AppColors.text),
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
        ],
      ),
    );
  }

  /// Bekräftar och tystar EN signatur. Regeluppdateringen tar ~40–60 s och
  /// kör i bakgrunden på brandväggen — vyn behöver inte vänta in den.
  Future<void> _confirmSilence(SecurityEventModel e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr('sec.tysta_signaturen'), style: TextStyle(color: AppColors.text, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.signature, style: TextStyle(color: AppColors.text, fontSize: 12)),
            const SizedBox(height: 8),
            Text('SID ${e.sid}', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 12),
            Text(tr('sec.tysta_signaturen_forklaring'),
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(tr('main.cancel'), style: TextStyle(color: AppColors.textMuted))),
          TextButton(onPressed: () => Navigator.pop(dctx, true), child: Text(tr('sec.tysta'), style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final err = await context.read<ConfigProvider>().api.postIdsRuleChange({'silence_sid': e.sid});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err == null ? tr('sec.signaturen_tystas_regeluppdatering_pagar') : '${tr('sec.kunde_inte_tysta')}: $err'),
    ));
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
                if (e.sid > 0) row('SID', '${e.sid}'),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (e.sid > 0 && context.read<ConfigProvider>().isAdmin)
                      TextButton.icon(
                        icon: Icon(Icons.notifications_off_outlined, size: 14, color: AppColors.textMuted),
                        label: Text(tr('sec.tysta_signaturen'), style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        onPressed: () {
                          Navigator.pop(dctx);
                          _confirmSilence(e);
                        },
                      ),
                    TextButton.icon(
                      icon: Icon(Icons.open_in_new, size: 14, color: AppColors.accent),
                      label: Text(tr('sec.sok_signaturen_pa_suricata_io'), style: TextStyle(color: AppColors.accent, fontSize: 11)),
                      onPressed: _openSuricata,
                    ),
                  ],
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                border: const OutlineInputBorder(),
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
                child: Text(
                  tr('sec.auto_block_kall_ip_n_fran'),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    border: const OutlineInputBorder(),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    border: const OutlineInputBorder(),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBg, foregroundColor: AppColors.onAccentBg),
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
