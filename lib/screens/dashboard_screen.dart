import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';

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
  final Map<String, InterfaceMetricHistory> _metrics = {};

  @override
  void initState() {
    super.initState();
    _startMetricsPoll();
  }

  @override
  void dispose() {
    _metricsTimer?.cancel();
    super.dispose();
  }

  void _startMetricsPoll() {
    _pollBandwidth();
    _metricsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollBandwidth();
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
        final zone = i.zone.isNotEmpty ? i.zone : 'Okonfigurerad';
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

    final metricsList = _metrics.values.toList();

    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Status-översikt (Kompakta kort)
            Row(
              children: [
                _buildCompactStatCard('System', sysName, 'Ver: $sysVersion', Icons.dns, Colors.cyanAccent),
                const SizedBox(width: 10),
                _buildCompactStatCard('Uptime', uptime, 'Driftstatus: Aktiv', Icons.timer_outlined, Colors.tealAccent),
                const SizedBox(width: 10),
                _buildCompactStatCard(
                  'CPU',
                  cpuUsage == null ? '—' : '${cpuUsage.toStringAsFixed(1)}%',
                  cpuCores == null ? '—' : 'Kärnor: $cpuCores',
                  Icons.memory,
                  Colors.amber,
                ),
                const SizedBox(width: 10),
                _buildCompactStatCard(
                  'Minne',
                  memUsage == null ? '—' : '${memUsage.toStringAsFixed(1)}%',
                  (memTotalGB == null || memFreePct == null) ? '—' : 'RAM: $memTotalGB GB (LEDIGT $memFreePct%)',
                  Icons.pie_chart_outline,
                  Colors.lightBlueAccent,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Realtids Bandbreddsgrafer per Nätverkskort & VLAN (Uppdateras 1 ggr/sek)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Realtid Trafik & Bandbredd per Interface / VLAN (1ggr/sek)',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.tealAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('IN (RX)', style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('UT (TX)', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            metricsList.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
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
        color: const Color(0xFF1E293B),
        border: Border.all(color: const Color(0xFF334155)),
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
                color: isVLAN ? Colors.lightBlueAccent : Colors.tealAccent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: Colors.tealAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                child: Text('IN: $rxFormatted', style: const TextStyle(color: Colors.tealAccent, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: Colors.amberAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                child: Text('UT: $txFormatted', style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                color: const Color(0xFF0F172A),
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

  Widget _buildCompactStatCard(String title, String mainValue, String subValue, IconData icon, Color accentColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          border: Border.all(color: const Color(0xFF334155)),
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
                  Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(mainValue, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(subValue, style: TextStyle(color: accentColor, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
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
      ..color = const Color(0xFF334155)
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
      ..color = Colors.tealAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..isAntiAlias = true;

    final rxFillPaint = Paint()
      ..color = Colors.tealAccent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final txPaint = Paint()
      ..color = Colors.amberAccent
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
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 8, fontWeight: FontWeight.bold),
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
