import 'dart:async';
import '../theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../localization.dart';

class InterfaceMetricHistory {
  final String device;
  final String label;
  int lastRxBytes;
  int lastTxBytes;
  double curRxRateKBps;
  double curTxRateKBps;
  final List<double> rxHistory;
  final List<double> txHistory;

  InterfaceMetricHistory({
    required this.device,
    required this.label,
    this.lastRxBytes = 0,
    this.lastTxBytes = 0,
    this.curRxRateKBps = 0.0,
    this.curTxRateKBps = 0.0,
    List<double>? rxHistory,
    List<double>? txHistory,
  })  : rxHistory = rxHistory ?? List.generate(20, (_) => 0.0),
        txHistory = txHistory ?? List.generate(20, (_) => 0.0);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _metricsTimer;
  Timer? _statusTimer;
  final Map<String, InterfaceMetricHistory> _metrics = {};

  @override
  void initState() {
    super.initState();
    _startMetricsPoll();
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _startMetricsPoll() {
    _pollBandwidth();
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollBandwidth();
    });

    // Separat, glesare timer för CPU/RAM/uptime (systemStatus) — annars
    // stod dessa siffror still efter första inloggningen (bara hämtade en
    // gång i ConfigProvider.fetchAll), trots att gränssnittet såg ut att
    // vara "live". 3 sekunder räcker gott för värden som ändå bara ändras
    // sakta, och håller nere belastningen från backendens CPU-provtagning
    // (blockerar ~100ms per anrop, se readCPUPercent).
    Provider.of<ConfigProvider>(context, listen: false).refreshSystemStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      Provider.of<ConfigProvider>(context, listen: false).refreshSystemStatus();
    });
  }

  Future<void> _pollBandwidth() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    final stats = await provider.api.fetchBandwidthStats();
    final cfg = provider.candidateConfig ?? provider.runningConfig;

    if (!mounted) return;

    // Lista över alla konfigurerade gränssnitt/VLAN
    final List<Map<String, String>> targetIfaces = [];
    if (cfg != null && cfg.interfaces.isNotEmpty) {
      for (final i in cfg.interfaces) {
        final id = i.id;
        final dev = i.device.isNotEmpty ? i.device : i.id;
        final zone = i.zone.isNotEmpty ? i.zone : tr('dashboard.okonfigurerad');
        targetIfaces.add({'key': id, 'dev': dev, 'label': '$id ($zone)'});
      }
    } else {
      targetIfaces.addAll([
        {'key': 'ens18', 'dev': 'ens18', 'label': 'ens18 (WAN)'},
        {'key': 'ens19', 'dev': 'ens19', 'label': 'ens19 (LAN)'},
        {'key': 'vlan10', 'dev': 'vlan10', 'label': 'vlan10 (SERVERS)'},
        {'key': 'vlan20', 'dev': 'vlan20', 'label': 'vlan20 (IOT)'},
      ]);
    }

    setState(() {
      final bool isLive = stats.isNotEmpty;

      for (final target in targetIfaces) {
        final key = target['key']!;
        final dev = target['dev']!;
        final label = target['label']!;

        int rx = 0;
        int tx = 0;
        bool found = false;

        if (isLive) {
          for (final s in stats) {
            final sDev = s['device']?.toString() ?? '';
            if (sDev == dev || sDev == key || sDev.endsWith('.10') && key.contains('10') || sDev.endsWith('.20') && key.contains('20')) {
              rx = (s['rx_bytes'] as num?)?.toInt() ?? 0;
              tx = (s['tx_bytes'] as num?)?.toInt() ?? 0;
              found = true;
              break;
            }
          }
        }

        if (!_metrics.containsKey(key)) {
          _metrics[key] = InterfaceMetricHistory(
            device: dev,
            label: label,
            lastRxBytes: rx,
            lastTxBytes: tx,
          );
        } else {
          final item = _metrics[key]!;

          double rxRate = 0.0;
          double txRate = 0.0;

          if (isLive && found) {
            final deltaRx = (rx >= item.lastRxBytes && item.lastRxBytes > 0) ? (rx - item.lastRxBytes) : 0;
            final deltaTx = (tx >= item.lastTxBytes && item.lastTxBytes > 0) ? (tx - item.lastTxBytes) : 0;

            item.lastRxBytes = rx;
            item.lastTxBytes = tx;
            rxRate = deltaRx / 1024.0;
            txRate = deltaTx / 1024.0;
          } else if (!isLive) {
            // Simulera levande testtrafik för utvecklingsläge
            rxRate = 12.0 + (DateTime.now().millisecondsSinceEpoch % 35);
            txRate = 5.0 + (DateTime.now().millisecondsSinceEpoch % 20);
          }

          item.curRxRateKBps = rxRate;
          item.curTxRateKBps = txRate;

          item.rxHistory.add(rxRate);
          if (item.rxHistory.length > 20) item.rxHistory.removeAt(0);

          item.txHistory.add(txRate);
          if (item.txHistory.length > 20) item.txHistory.removeAt(0);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final status = provider.systemStatus;

    // Ingen fabricerad platshållardata (tidigare "1h 42m"/"14.5%"/"38.2%"/
    // "Kärnor: 4"/"RAM: 8 GB" hårdkodat och visat oavsett om brandväggen
    // faktiskt svarat) — visar "—" ärligt när status inte hämtats än.
    final sysName = status?['hostname'] ?? '—';
    final sysVersion = status?['version'] ?? '—';
    final uptime = status?['uptime'] ?? '—';
    final cpuUsage = (status?['cpu'] as num?)?.toDouble();
    final cpuCores = status?['cpu_cores'];
    final memUsage = (status?['memory'] as num?)?.toDouble();
    final memTotalGB = status?['memory_total_gb'];
    final memFreePct = status?['memory_free_pct'];
    final diskUsage = (status?['disk'] as num?)?.toDouble();
    final diskTotalGB = status?['disk_total_gb'];
    final diskFreeGB = status?['disk_free_gb'];
    // Färga disk-rutan efter fyllnadsgrad så en full disk (som gör
    // brandväggen oanvändbar) syns direkt: >90% fara, >75% varning.
    final diskColor = diskUsage == null
        ? AppColors.info
        : (diskUsage >= 90 ? AppColors.danger : (diskUsage >= 75 ? AppColors.warn : AppColors.info));

    final metricsList = _metrics.values.toList();

    return Container(
      color: AppColors.bg,
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Status-översikt (Kompakta kort). Fyra kort i EN rad tvingar
            // varje kort ner till en fjärdedel av bredden — på en smal
            // telefonskärm blev det så trångt att texten radbröts en
            // bokstav i taget (upptäckt 2026-08-24 av en administratör som
            // testade på riktigt). LayoutBuilder växlar till en 2x2-Wrap
            // under 500px bredd, där varje kort i stället får halva bredden.
            LayoutBuilder(builder: (context, constraints) {
              final cards = [
                _buildCompactStatCard(tr('dashboard.system'), sysName, trp('dashboard.ver', {'v': sysVersion}), Icons.dns, AppColors.accent),
                _buildCompactStatCard(tr('dashboard.uptime'), uptime, tr('dashboard.driftstatus_aktiv'), Icons.timer_outlined, AppColors.ok),
                _buildCompactStatCard(
                  tr('dashboard.cpu'),
                  cpuUsage == null ? '—' : '${cpuUsage.toStringAsFixed(1)}%',
                  cpuCores == null ? '—' : trp('dashboard.karnor', {'n': '$cpuCores'}),
                  Icons.memory,
                  AppColors.warn,
                ),
                _buildCompactStatCard(
                  tr('dashboard.minne'),
                  memUsage == null ? '—' : '${memUsage.toStringAsFixed(1)}%',
                  (memTotalGB == null || memFreePct == null) ? '—' : trp('dashboard.ram_ledigt', {'gb': '$memTotalGB', 'pct': '$memFreePct'}),
                  Icons.pie_chart_outline,
                  AppColors.info,
                ),
                _buildCompactStatCard(
                  tr('dashboard.disk'),
                  diskUsage == null ? '—' : '${diskUsage.toStringAsFixed(1)}%',
                  (diskTotalGB == null || diskFreeGB == null) ? '—' : trp('dashboard.disk_ledigt', {'gb': '$diskTotalGB', 'free': '$diskFreeGB'}),
                  Icons.storage,
                  diskColor,
                ),
              ];
              if (constraints.maxWidth >= 500) {
                return Row(children: [for (final c in cards) ...[Expanded(child: c), if (c != cards.last) const SizedBox(width: 10)]]);
              }
              const gap = 10.0;
              final cardWidth = (constraints.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [for (final c in cards) SizedBox(width: cardWidth, child: c)],
              );
            }),
            const SizedBox(height: 16),

            // Realtids Bandbreddsgrafer per Nätverkskort & VLAN (Uppdateras 1 ggr/sek)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(tr('dashboard.realtid_trafik_bandbredd_per_interface_vlan'),
                    style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.ok, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(tr('dashboard.in_rx'), style: TextStyle(color: AppColors.ok, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.warn, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(tr('dashboard.ut_tx'), style: TextStyle(color: AppColors.warn, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            metricsList.isEmpty
                ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: metricsList.length,
                    itemBuilder: (ctx, i) {
                      final item = metricsList[i];
                      return _buildBandwidthGraphCard(item);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildBandwidthGraphCard(InterfaceMetricHistory item) {
    final rxFormatted = _formatSpeed(item.curRxRateKBps);
    final txFormatted = _formatSpeed(item.curTxRateKBps);
    final isVLAN = item.device.toLowerCase().contains('vlan');

    return Container(
      padding: const EdgeInsets.all(10),
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
              Icon(
                isVLAN ? Icons.alt_route : Icons.router,
                size: 15,
                color: isVLAN ? AppColors.info : AppColors.ok,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: AppColors.ok.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                child: Text('IN: $rxFormatted', style: TextStyle(color: AppColors.ok, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: AppColors.warn.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                child: Text('UT: $txFormatted', style: TextStyle(color: AppColors.warn, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                color: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: BandwidthGraphPainter(
                    rxData: item.rxHistory,
                    txData: item.txHistory,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSpeed(double kbps) {
    if (kbps >= 1024) {
      return '${(kbps / 1024.0).toStringAsFixed(2)} MB/s';
    }
    return '${kbps.toStringAsFixed(1)} KB/s';
  }

  // OBS: returnerar INTE längre en Expanded här (den kräver en direkt
  // Row/Column-förälder) — anroparen (LayoutBuilder ovan) avgör själv om
  // kortet ska wrappas i Expanded (bred skärm, en rad) eller SizedBox
  // (smal skärm, 2x2-Wrap), så samma kort funkar i båda layouterna.
  Widget _buildCompactStatCard(String title, String mainValue, String subValue, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(mainValue, style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(subValue, style: TextStyle(color: accentColor, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BandwidthGraphPainter extends CustomPainter {
  final List<double> rxData;
  final List<double> txData;

  BandwidthGraphPainter({required this.rxData, required this.txData});

  @override
  void paint(Canvas canvas, Size size) {
    if (rxData.isEmpty || txData.isEmpty) return;

    double maxVal = 10.0;
    for (final v in rxData) {
      if (v > maxVal) maxVal = v;
    }
    for (final v in txData) {
      if (v > maxVal) maxVal = v;
    }

    const double yAxisWidth = 58.0;
    final graphWidth = size.width - yAxisWidth;
    final graphHeight = size.height - 14.0;

    // Gridlinjer och Skala (100%, 50%, 0%)
    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final double topY = 6.0;
    final double midY = topY + (graphHeight / 2.0);
    final double botY = topY + graphHeight;

    // Rita 3 horisontella skalgaller-linjer
    canvas.drawLine(Offset(yAxisWidth, topY), Offset(size.width, topY), gridPaint);
    canvas.drawLine(Offset(yAxisWidth, midY), Offset(size.width, midY), gridPaint);
    canvas.drawLine(Offset(yAxisWidth, botY), Offset(size.width, botY), gridPaint);

    // Rita Y-axelns skala med enhet (KB/s, MB/s, GB/s)
    _drawYText(canvas, _formatScaleVal(maxVal), topY);
    _drawYText(canvas, _formatScaleVal(maxVal / 2.0), midY);
    _drawYText(canvas, '0 KB/s', botY);

    if (graphWidth <= 0) return;

    final rxPaint = Paint()
      ..color = AppColors.ok
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..isAntiAlias = true;

    final rxFillPaint = Paint()
      ..color = AppColors.ok.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final txPaint = Paint()
      ..color = AppColors.warn
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..isAntiAlias = true;

    final stepX = graphWidth / (rxData.length - 1);

    // Rita RX Kurva & Area Fill
    final rxPath = Path();
    final rxFillPath = Path();
    rxFillPath.moveTo(yAxisWidth, botY);

    for (int i = 0; i < rxData.length; i++) {
      final x = yAxisWidth + (i * stepX);
      final y = botY - ((rxData[i] / maxVal) * graphHeight);
      if (i == 0) {
        rxPath.moveTo(x, y);
        rxFillPath.lineTo(x, y);
      } else {
        rxPath.lineTo(x, y);
        rxFillPath.lineTo(x, y);
      }
    }
    rxFillPath.lineTo(yAxisWidth + graphWidth, botY);
    rxFillPath.close();

    canvas.drawPath(rxFillPath, rxFillPaint);
    canvas.drawPath(rxPath, rxPaint);

    // Rita TX Kurva
    final txPath = Path();
    for (int i = 0; i < txData.length; i++) {
      final x = yAxisWidth + (i * stepX);
      final y = botY - ((txData[i] / maxVal) * graphHeight);
      if (i == 0) {
        txPath.moveTo(x, y);
      } else {
        txPath.lineTo(x, y);
      }
    }
    canvas.drawPath(txPath, txPaint);
  }

  void _drawYText(Canvas canvas, String text, double yPos) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: AppColors.textFaint, fontSize: 8, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(2, yPos - (tp.height / 2.0)));
  }

  String _formatScaleVal(double kbps) {
    if (kbps >= 1024 * 1024) {
      return '${(kbps / (1024.0 * 1024.0)).toStringAsFixed(1)} GB/s';
    } else if (kbps >= 1024) {
      return '${(kbps / 1024.0).toStringAsFixed(1)} MB/s';
    }
    return '${kbps.toStringAsFixed(0)} KB/s';
  }

  @override
  bool shouldRepaint(covariant BandwidthGraphPainter oldDelegate) => true;
}
