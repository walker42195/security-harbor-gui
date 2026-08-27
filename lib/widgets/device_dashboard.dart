import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../theme.dart';
import 'traffic_charts.dart';

/// Enhetsvyn på dashboarden: realtidsbandbredd, historik och säkerhetssignaler
/// per enhet, med sorterbar tabell och cirkeldiagram över de största
/// förbrukarna.
class DeviceDashboard extends StatefulWidget {
  const DeviceDashboard({super.key});

  @override
  State<DeviceDashboard> createState() => _DeviceDashboardState();
}

enum _SortCol { name, ip, zone, vendor, rxBps, txBps, rx, tx, blocked, alerts, lastSeen }

class _DeviceDashboardState extends State<DeviceDashboard> {
  DashboardDataModel? _data;
  bool _loading = true;
  Timer? _timer;

  String _res = '5m';
  _SortCol _sort = _SortCol.rx;
  bool _asc = false;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
    // Realtidssiffrorna samplas var 10:e sekund i agenten; att hämta oftare
    // ger inget nytt.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<ConfigProvider>().api;
    final d = await api.getDashboardDevices(res: _res, spark: 30);
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  void _setSort(_SortCol c) {
    setState(() {
      if (_sort == c) {
        _asc = !_asc;
      } else {
        _sort = c;
        // Text sorteras naturligt stigande, mängder mest-först.
        _asc = c == _SortCol.name || c == _SortCol.ip || c == _SortCol.zone || c == _SortCol.vendor;
      }
    });
  }

  List<DeviceStatModel> get _rows {
    final all = _data?.devices ?? const <DeviceStatModel>[];
    final q = _filter.trim().toLowerCase();
    final filtered = q.isEmpty
        ? [...all]
        : all.where((d) =>
            d.displayName.toLowerCase().contains(q) ||
            d.ip.contains(q) ||
            d.mac.contains(q) ||
            d.vendor.toLowerCase().contains(q) ||
            d.zone.toLowerCase().contains(q)).toList();

    int cmp(DeviceStatModel a, DeviceStatModel b) {
      switch (_sort) {
        case _SortCol.name:
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        case _SortCol.ip:
          return _ipKey(a.ip).compareTo(_ipKey(b.ip));
        case _SortCol.zone:
          return a.zone.compareTo(b.zone);
        case _SortCol.vendor:
          return a.vendor.toLowerCase().compareTo(b.vendor.toLowerCase());
        case _SortCol.rxBps:
          return a.rxBps.compareTo(b.rxBps);
        case _SortCol.txBps:
          return a.txBps.compareTo(b.txBps);
        case _SortCol.rx:
          return a.rxBytes.compareTo(b.rxBytes);
        case _SortCol.tx:
          return a.txBytes.compareTo(b.txBytes);
        case _SortCol.blocked:
          return a.blockedConnections.compareTo(b.blockedConnections);
        case _SortCol.alerts:
          return a.idsAlerts.compareTo(b.idsAlerts);
        case _SortCol.lastSeen:
          return a.lastSeen.compareTo(b.lastSeen);
      }
    }

    filtered.sort((a, b) => _asc ? cmp(a, b) : cmp(b, a));
    return filtered;
  }

  /// Sorterar IP numeriskt per oktett — annars hamnar 10.0.0.100 före 10.0.0.9.
  int _ipKey(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return 0;
    var k = 0;
    for (final p in parts) {
      k = (k << 8) | (int.tryParse(p) ?? 0);
    }
    return k;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final d = _data;
    if (d == null) {
      return _card(child: Text(tr('devdash.ingen_data'),
          style: TextStyle(color: AppColors.textFaint, fontSize: 12)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(d),
        const SizedBox(height: 12),
        _buildPies(d),
        const SizedBox(height: 12),
        _buildTable(),
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );

  Widget _buildHeader(DashboardDataModel d) {
    final online = d.devices.where((e) => e.online).length;
    final newDevices = d.devices.where((e) => e.isNew).length;

    // Wrap i stället för Row med Expanded: fyra Expanded plus fönsterväljaren
    // i samma rad pressade korten till någon enstaka teckens bredd på smalare
    // fönster, och texten radbröts lodrätt till oläslighet. Med fasta bredder
    // flyttas kort som inte får plats ned på nästa rad i stället.
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        SizedBox(width: 190, child: _stat(tr('devdash.enheter'), '${d.devices.length}',
            '$online ${tr('devdash.online')}', Icons.devices, AppColors.accent)),
        SizedBox(width: 190, child: _stat(tr('devdash.ned_nu'), formatBps(d.totalRxBps),
            formatBytes(d.totalRx), Icons.download, AppColors.ok)),
        SizedBox(width: 190, child: _stat(tr('devdash.upp_nu'), formatBps(d.totalTxBps),
            formatBytes(d.totalTx), Icons.upload, AppColors.warn)),
        SizedBox(width: 190, child: _stat(tr('devdash.nya_enheter'), '$newDevices',
            tr('devdash.senaste_dygnet'), Icons.fiber_new,
            newDevices > 0 ? AppColors.warn : AppColors.textMuted)),
        _buildResolutionPicker(),
      ],
    );
  }

  Widget _stat(String title, String main, String sub, IconData icon, Color color) => _card(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(title,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Text(main, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(sub, style: TextStyle(color: AppColors.textFaint, fontSize: 10)),
          ],
        ),
      );

  Widget _buildResolutionPicker() {
    const options = {'1m': '3 h', '5m': '48 h', '1h': '90 d', '1d': '2 år'};
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.entries.map((e) {
          final sel = _res == e.key;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () {
                setState(() => _res = e.key);
                _load();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: sel ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: sel ? AppColors.accent : AppColors.border),
                ),
                child: Text(e.value,
                    style: TextStyle(
                        color: sel ? AppColors.accent : AppColors.textMuted, fontSize: 10)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPies(DashboardDataModel d) {
    final down = buildSlices(
      d.devices.map((e) => (label: e.displayName, value: e.rxBytes)).toList(),
      otherLabel: tr('devdash.ovriga'),
    );
    final up = buildSlices(
      d.devices.map((e) => (label: e.displayName, value: e.txBytes)).toList(),
      otherLabel: tr('devdash.ovriga'),
    );
    final zones = buildSlices(
      d.zones.entries
          .map((e) => (label: e.key.isEmpty ? '—' : e.key, value: e.value.rx + e.value.tx))
          .toList(),
      top: 8,
      otherLabel: tr('devdash.ovriga'),
    );

    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 900;
      final children = [
        Expanded(child: _pieCard(tr('devdash.mest_nedladdat'), down, formatBytes(d.totalRx))),
        SizedBox(width: narrow ? 0 : 10, height: narrow ? 10 : 0),
        Expanded(child: _pieCard(tr('devdash.mest_uppladdat'), up, formatBytes(d.totalTx))),
        SizedBox(width: narrow ? 0 : 10, height: narrow ? 10 : 0),
        Expanded(child: _pieCard(tr('devdash.per_zon'), zones, formatBytes(d.totalRx + d.totalTx))),
      ];
      return narrow ? Column(children: children) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    });
  }

  Widget _pieCard(String title, List<PieSlice> slices, String centerLabel) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (slices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(tr('devdash.ingen_trafik_annu'),
                    style: TextStyle(color: AppColors.textFaint, fontSize: 11))),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InteractivePieChart(slices: slices, size: 110, centerLabel: centerLabel),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: slices.take(10).map((s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Row(children: [
                              Container(width: 8, height: 8,
                                  decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 6),
                              Expanded(child: Text(s.label,
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                                  overflow: TextOverflow.ellipsis)),
                              Text(formatBytes(s.value),
                                  style: TextStyle(color: AppColors.textFaint, fontSize: 10)),
                            ]),
                          )).toList(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );

  Widget _buildTable() {
    final rows = _rows;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('${tr('devdash.enheter')} (${rows.length})',
                style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
            const Spacer(),
            SizedBox(
              width: 220,
              height: 30,
              child: TextField(
                style: TextStyle(color: AppColors.text, fontSize: 11),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: tr('devdash.sok'),
                  hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 11),
                  prefixIcon: Icon(Icons.search, size: 14, color: AppColors.textFaint),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 34,
              columnSpacing: 18,
              columns: [
                _col(tr('devdash.enhet'), _SortCol.name),
                _col('IP', _SortCol.ip),
                _col(tr('devdash.zon'), _SortCol.zone),
                _col(tr('devdash.tillverkare'), _SortCol.vendor),
                _col('↓ ${tr('devdash.nu')}', _SortCol.rxBps, numeric: true),
                _col('↑ ${tr('devdash.nu')}', _SortCol.txBps, numeric: true),
                _col('↓ ${tr('devdash.totalt')}', _SortCol.rx, numeric: true),
                _col('↑ ${tr('devdash.totalt')}', _SortCol.tx, numeric: true),
                DataColumn(label: Text(tr('devdash.senaste_timmen'),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                _col(tr('devdash.blockerat_fw'), _SortCol.blocked, numeric: true),
                _col(tr('devdash.ids_larm'), _SortCol.alerts, numeric: true),
              ],
              rows: rows.map(_row).toList(),
            ),
          ),
        ],
      ),
    );
  }

  DataColumn _col(String label, _SortCol c, {bool numeric = false}) => DataColumn(
        numeric: numeric,
        onSort: (_, _) => _setSort(c),
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(
              color: _sort == c ? AppColors.accent : AppColors.textMuted,
              fontSize: 11,
              fontWeight: _sort == c ? FontWeight.bold : FontWeight.normal)),
          if (_sort == c)
            Icon(_asc ? Icons.arrow_upward : Icons.arrow_downward, size: 11, color: AppColors.accent),
        ]),
      );

  DataRow _row(DeviceStatModel d) => DataRow(cells: [
        DataCell(Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(
              color: d.online ? AppColors.ok : AppColors.textFaint, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(d.displayName,
                style: TextStyle(color: AppColors.text, fontSize: 11), overflow: TextOverflow.ellipsis),
          ),
          if (d.isNew) ...[
            const SizedBox(width: 4),
            Tooltip(message: tr('devdash.ny_enhet_tooltip'),
                child: Icon(Icons.fiber_new, size: 13, color: AppColors.warn)),
          ],
          if (d.randomizedMac) ...[
            const SizedBox(width: 4),
            Tooltip(message: tr('devdash.slumpad_mac_tooltip'),
                child: Icon(Icons.privacy_tip_outlined, size: 12, color: AppColors.textFaint)),
          ],
        ])),
        DataCell(Text(d.ip, style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
        DataCell(Text(d.zone, style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(d.vendor,
              style: TextStyle(color: AppColors.textFaint, fontSize: 11), overflow: TextOverflow.ellipsis),
        )),
        DataCell(Text(formatBps(d.rxBps),
            style: TextStyle(color: d.rxBps > 0 ? AppColors.ok : AppColors.textFaint, fontSize: 11))),
        DataCell(Text(formatBps(d.txBps),
            style: TextStyle(color: d.txBps > 0 ? AppColors.warn : AppColors.textFaint, fontSize: 11))),
        DataCell(Text(formatBytes(d.rxBytes), style: TextStyle(color: AppColors.text, fontSize: 11))),
        DataCell(Text(formatBytes(d.txBytes), style: TextStyle(color: AppColors.text, fontSize: 11))),
        DataCell(SizedBox(
          width: 70, height: 22,
          child: CustomPaint(painter: SparklinePainter(
            d.sparkline.map((p) => p.rx).toList(),
            d.sparkline.map((p) => p.tx).toList(),
          )),
        )),
        DataCell(Text('${d.blockedConnections}',
            style: TextStyle(
                color: d.blockedConnections > 0 ? AppColors.warn : AppColors.textFaint, fontSize: 11))),
        DataCell(Text('${d.idsAlerts}',
            style: TextStyle(
                color: d.idsAlerts > 0 ? AppColors.danger : AppColors.textFaint, fontSize: 11))),
      ]);
}
