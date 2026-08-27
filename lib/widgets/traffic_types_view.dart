import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../theme.dart';
import 'traffic_charts.dart';

/// Vad nätet används TILL: streaming, sociala medier, spel, uppdateringar och
/// så vidare, per kategori och per enhet.
///
/// Klassificeringen bygger på servernamnet i TLS-handskakningen (SNI) och på
/// DNS-uppslagen — båda i klartext, inget certifikat och ingen uppbrytning av
/// krypteringen behövs.
class TrafficTypesView extends StatefulWidget {
  const TrafficTypesView({super.key});

  @override
  State<TrafficTypesView> createState() => _TrafficTypesViewState();
}

class _TrafficTypesViewState extends State<TrafficTypesView> {
  TrafficTypesModel? _data;
  bool _loading = true;
  String _res = '1h';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await context.read<ConfigProvider>().api.getTrafficTypes(res: _res);
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
    });
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    final d = _data;
    if (d == null) {
      return _card(child: Text(tr('traftype.ingen_data'),
          style: TextStyle(color: AppColors.textFaint, fontSize: 12)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!d.idsOnInside) ...[
          _buildWanWarning(),
          const SizedBox(height: 12),
        ],
        _buildRangePicker(),
        const SizedBox(height: 12),
        _buildOverview(d),
        const SizedBox(height: 12),
        _buildDomains(d),
        const SizedBox(height: 12),
        _buildPerDevice(d),
      ],
    );
  }

  /// Utan trafik på insidan är vyn strukturellt tom. Säg varför, i stället för
  /// att låta användaren undra om funktionen är trasig.
  Widget _buildWanWarning() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warnSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.warn),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tr('traftype.ids_pa_wan'),
                style: TextStyle(color: AppColors.text, fontSize: 11, height: 1.4)),
          ),
        ]),
      );

  Widget _buildRangePicker() {
    const options = {'1h': '48 h', '1d': '90 d'};
    return Row(
      children: options.entries.map((e) {
        final sel = _res == e.key;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            onTap: () {
              setState(() => _res = e.key);
              _load();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: sel ? AppColors.accent : AppColors.border),
              ),
              child: Text(e.value,
                  style: TextStyle(
                      color: sel ? AppColors.accent : AppColors.textMuted, fontSize: 11)),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _catLabel(String c) => tr('traftype.cat_$c');

  /// Kategoriernas ordning, delad av färgvalet och hjälprutan så att båda
  /// alltid visar samma uppsättning i samma ordning.
  static const List<String> _categoryOrder = [
    'streaming', 'social', 'messaging', 'gaming', 'work',
    'cloud', 'updates', 'smarthome', 'ads', 'web', 'other',
  ];

  /// Förklarar vad som räknas till vilken kategori. Listan i backend är
  /// medvetet kort och kan aldrig bli komplett, så användaren behöver kunna
  /// se vad den faktiskt bygger på i stället för att gissa.
  void _showCategoryHelp() {
    showDialog(
      context: context,
      builder: (dctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Icon(Icons.help_outline, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(tr('traftype.hjalp_titel'),
                          style: TextStyle(
                              color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold))),
                  IconButton(
                      icon: Icon(Icons.close, color: AppColors.textMuted, size: 18),
                      onPressed: () => Navigator.pop(dctx)),
                ]),
                Divider(color: AppColors.border),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('traftype.hjalp_metod'),
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 11, height: 1.5)),
                        const SizedBox(height: 14),
                        for (final c in _categoryOrder)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color: _colorForCategory(c),
                                        borderRadius: BorderRadius.circular(2)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_catLabel(c),
                                          style: TextStyle(
                                              color: AppColors.text,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(tr('traftype.help_$c'),
                                          style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                              height: 1.45)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Divider(color: AppColors.border),
                        const SizedBox(height: 6),
                        Text(tr('traftype.hjalp_okand'),
                            style: TextStyle(
                                color: AppColors.textFaint, fontSize: 11, height: 1.5)),
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

  Widget _buildOverview(TrafficTypesModel d) {
    final slices = buildSlices(
      d.categories.map((c) => (label: _catLabel(c.category), value: c.total)).toList(),
      top: 11,
      otherLabel: tr('devdash.ovriga'),
    );
    final total = d.categories.fold<int>(0, (a, c) => a + c.total);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(tr('traftype.fordelning'),
                style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Tooltip(
              message: tr('traftype.hjalp_titel'),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _showCategoryHelp,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.help_outline, size: 15, color: AppColors.accent),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (slices.isEmpty)
            Text(tr('traftype.ingen_trafik'),
                style: TextStyle(color: AppColors.textFaint, fontSize: 11))
          else
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              InteractivePieChart(
                slices: slices,
                size: 140,
                centerLabel: formatBytes(total),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < d.categories.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                  color: kPiePalette[i % kPiePalette.length],
                                  borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_catLabel(d.categories[i].category),
                                  style: TextStyle(color: AppColors.text, fontSize: 11))),
                          Text('↓ ${formatBytes(d.categories[i].rx)}',
                              style: TextStyle(color: AppColors.ok, fontSize: 10)),
                          const SizedBox(width: 10),
                          Text('↑ ${formatBytes(d.categories[i].tx)}',
                              style: TextStyle(color: AppColors.warn, fontSize: 10)),
                        ]),
                      ),
                  ],
                ),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildDomains(TrafficTypesModel d) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('traftype.toppdomaner'),
                style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (d.topDomains.isEmpty)
              Text(tr('traftype.ingen_trafik'),
                  style: TextStyle(color: AppColors.textFaint, fontSize: 11))
            else
              Wrap(
                spacing: 24,
                runSpacing: 4,
                children: d.topDomains.map((dom) => SizedBox(
                      width: 260,
                      child: Row(children: [
                        Expanded(
                            child: Text(dom.domain,
                                style: TextStyle(color: AppColors.text, fontSize: 11),
                                overflow: TextOverflow.ellipsis)),
                        Text(formatBytes(dom.bytes),
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ]),
                    )).toList(),
              ),
          ],
        ),
      );

  Widget _buildPerDevice(TrafficTypesModel d) {
    final entries = d.perDevice.entries.toList()
      ..sort((a, b) {
        final sa = a.value.fold<int>(0, (x, c) => x + c.total);
        final sb = b.value.fold<int>(0, (x, c) => x + c.total);
        return sb.compareTo(sa);
      });

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('traftype.per_enhet'),
              style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(tr('traftype.per_enhet_hjalp'),
              style: TextStyle(color: AppColors.textFaint, fontSize: 10)),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(tr('traftype.ingen_trafik'),
                style: TextStyle(color: AppColors.textFaint, fontSize: 11))
          else
            for (final e in entries)
              _deviceRow(d.deviceNames[e.key] ?? e.key, e.key, e.value),
        ],
      ),
    );
  }

  /// Staplad andelsstapel per enhet: färgerna följer kategoriernas ordning i
  /// legenden ovan, så samma färg betyder samma sak i hela vyn.
  Widget _deviceRow(String name, String ip, List<TrafficCategoryModel> cats) {
    final total = cats.fold<int>(0, (a, c) => a + c.total);
    if (total == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 150,
          // IP:n i verktygstipset så den fortfarande går att se när ett namn
          // visas i stället.
          child: Tooltip(
            message: ip,
            child: Text(name,
                style: TextStyle(color: AppColors.text, fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  for (var i = 0; i < cats.length; i++)
                    Expanded(
                      flex: cats[i].total,
                      child: Tooltip(
                        message: '${_catLabel(cats[i].category)}: ${formatBytes(cats[i].total)}',
                        child: Container(color: _colorForCategory(cats[i].category)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
            width: 70,
            child: Text(formatBytes(total),
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
      ]),
    );
  }

  /// Färgen härleds ur kategorinamnet i stället för ur listans ordning, så att
  /// "streaming" har samma färg på varje rad även när enheter har olika många
  /// kategorier.
  Color _colorForCategory(String c) {
    final i = _categoryOrder.indexOf(c);
    return i < 0 ? kPieOtherColor : kPiePalette[i % kPiePalette.length];
  }
}
