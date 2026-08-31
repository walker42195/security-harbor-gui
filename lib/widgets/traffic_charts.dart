import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// En skiva i cirkeldiagrammet.
class PieSlice {
  final String label;
  final int value;
  final Color color;
  const PieSlice(this.label, this.value, this.color);
}

/// Paletten ligger i theme.dart — projektet tillåter inga hårdkodade färger
/// utanför den filen, och ett cirkeldiagram är inget undantag.
const List<Color> kPiePalette = AppColors.piePalette;
const Color kPieOtherColor = AppColors.pieOther;

/// Bygger skivor av en lista, där bara de [top] största visas var för sig och
/// resten slås ihop till "Övriga". Utan hopslagningen blir diagrammet
/// oläsbart på ett nät med fyrtio enheter, vilket är helt vanligt.
List<PieSlice> buildSlices(
  List<({String label, int value})> items, {
  int top = 10,
  String otherLabel = 'Övriga',
}) {
  final sorted = [...items]..sort((a, b) => b.value.compareTo(a.value));
  final withData = sorted.where((e) => e.value > 0).toList();
  final slices = <PieSlice>[];
  for (var i = 0; i < withData.length && i < top; i++) {
    slices.add(PieSlice(withData[i].label, withData[i].value, kPiePalette[i % kPiePalette.length]));
  }
  if (withData.length > top) {
    final rest = withData.skip(top).fold<int>(0, (a, e) => a + e.value);
    if (rest > 0) slices.add(PieSlice(otherLabel, rest, kPieOtherColor));
  }
  return slices;
}

class PieChartPainter extends CustomPainter {
  final List<PieSlice> slices;

  /// Index på skivan under muspekaren, eller -1. Den ritas tjockare och något
  /// utanför de andra, så det syns vilken som är vald även när färgerna
  /// ligger nära varandra.
  final int highlighted;

  PieChartPainter(this.slices, {this.highlighted = -1});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (a, s) => a + s.value);
    if (total <= 0) return;

    final radius = math.min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    // Donut i stället för hel cirkel: mitten blir plats för totalsumman, och
    // små skivor blir lättare att skilja åt vid ytterkanten.
    final stroke = radius * 0.42;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    var start = -math.pi / 2; // börja i klockan tolv
    for (var i = 0; i < slices.length; i++) {
      final s = slices[i];
      final sweep = 2 * math.pi * (s.value / total);
      final isHot = i == highlighted;
      paint.color = s.color;
      paint.strokeWidth = isHot ? stroke * 1.18 : stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - stroke / 2),
        start,
        // Lämna en hårfin lucka mellan skivorna så gränserna syns.
        math.max(sweep - 0.01, 0.001),
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter old) =>
      old.slices != slices || old.highlighted != highlighted;
}

/// Minigraf för en tabellrad: nedladdning uppåt, uppladdning nedåt, med en
/// gemensam skala så att de två riktningarna går att jämföra med ögat.
class SparklinePainter extends CustomPainter {
  final List<int> rx;
  final List<int> tx;
  SparklinePainter(this.rx, this.tx);

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.max(rx.length, tx.length);
    if (n == 0) return;
    var peak = 1;
    for (final v in rx) {
      if (v > peak) peak = v;
    }
    for (final v in tx) {
      if (v > peak) peak = v;
    }

    final mid = size.height / 2;
    final dx = size.width / n;

    void drawSeries(List<int> data, Color color, bool up) {
      if (data.isEmpty) return;
      final p = Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final h = (data[i] / peak) * (mid - 1);
        final y = up ? mid - h : mid + h;
        final x = i * dx;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, p);
    }

    drawSeries(rx, AppColors.ok, true);
    drawSeries(tx, AppColors.warn, false);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter old) => old.rx != rx || old.tx != tx;
}

/// Formaterar byte som människor läser dem.
String formatBytes(int b) {
  if (b < 1024) return '$b B';
  const units = ['kB', 'MB', 'GB', 'TB', 'PB'];
  var v = b / 1024.0;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

/// Bandbredd anges i bit per sekund — det är så anslutningar säljs och mäts,
/// medan volym anges i byte. Att blanda ihop dem ger en faktor 8 fel.
String formatBps(int bytesPerSecond) {
  final bits = bytesPerSecond * 8;
  // Samma enhetsskrivning som stegen ovanför ('kbit/s'), inte 'bps' —
  // annars byter samma kolumn benämning beroende på hastigheten.
  if (bits < 1000) return '$bits bit/s';
  const units = ['kbit/s', 'Mbit/s', 'Gbit/s'];
  var v = bits / 1000.0;
  var i = 0;
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

/// Vilken skiva ligger under punkten [p] i ett diagram med sidan [size]?
/// Returnerar -1 utanför ringen, i mitthålet eller när diagrammet är tomt.
///
/// Bruten ut ur widgeten för att kunna testas: träffdetektering på vinkel och
/// radie är precis den sortens geometri som blir tyst fel — ett diagram som
/// börjar i klockan tolv men mäts från klockan tre pekar ut fel skiva utan att
/// något kraschar.
int sliceIndexAt(List<PieSlice> slices, Offset p, double size) {
  final total = slices.fold<int>(0, (a, s) => a + s.value);
  if (total <= 0) return -1;

  final r = size / 2;
  final d = p - Offset(r, r);
  final dist = d.distance;
  final stroke = r * 0.42;
  // Bara själva ringen är träffbar — inte hålet i mitten och inte hörnen
  // utanför cirkeln.
  if (dist > r || dist < r - stroke) return -1;

  // atan2 ger -pi..pi med noll åt höger; diagrammet börjar i klockan tolv.
  var angle = math.atan2(d.dy, d.dx) + math.pi / 2;
  if (angle < 0) angle += 2 * math.pi;

  var start = 0.0;
  for (var i = 0; i < slices.length; i++) {
    final sweep = 2 * math.pi * (slices[i].value / total);
    if (angle >= start && angle < start + sweep) return i;
    start += sweep;
  }
  return -1;
}

/// Cirkeldiagram som lyfter fram skivan under muspekaren och visar dess
/// etikett, mängd och andel.
///
/// CustomPaint har ingen träffdetektering, så pekarens position räknas om till
/// vinkel och radie och jämförs mot skivornas gränser. Det är enda sättet att
/// veta vilken skiva som pekas på utan att lägga en widget per skiva.
class InteractivePieChart extends StatefulWidget {
  final List<PieSlice> slices;
  final double size;

  /// Visas mitt i ringen när ingen skiva pekas på — typiskt totalsumman.
  final String centerLabel;

  /// Formaterar en skivas värde. Bytes som standard.
  final String Function(int) formatValue;

  const InteractivePieChart({
    super.key,
    required this.slices,
    required this.size,
    required this.centerLabel,
    this.formatValue = formatBytes,
  });

  @override
  State<InteractivePieChart> createState() => _InteractivePieChartState();
}

class _InteractivePieChartState extends State<InteractivePieChart> {
  int _hovered = -1;
  Offset _cursor = Offset.zero;

  int _sliceAt(Offset p) => sliceIndexAt(widget.slices, p, widget.size);

  @override
  Widget build(BuildContext context) {
    final total = widget.slices.fold<int>(0, (a, s) => a + s.value);
    final hovered = _hovered >= 0 && _hovered < widget.slices.length ? widget.slices[_hovered] : null;

    return MouseRegion(
      onHover: (e) {
        final i = _sliceAt(e.localPosition);
        if (i != _hovered || _cursor != e.localPosition) {
          setState(() {
            _hovered = i;
            _cursor = e.localPosition;
          });
        }
      },
      onExit: (_) => setState(() => _hovered = -1),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: PieChartPainter(widget.slices, highlighted: _hovered),
            ),
            // Mitten byter till den pekade skivans andel: informationen hamnar
            // där blicken redan är, utan att ett verktygstips skymmer ringen.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size * 0.18),
              child: Text(
                hovered == null
                    ? widget.centerLabel
                    : '${(100 * hovered.value / (total == 0 ? 1 : total)).toStringAsFixed(hovered.value * 100 / (total == 0 ? 1 : total) < 10 ? 1 : 0)} %',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: hovered == null ? AppColors.text : hovered.color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
            ),
            if (hovered != null)
              Positioned(
                left: _cursor.dx + 12,
                top: _cursor.dy + 12,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDeep,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: hovered.color),
                    ),
                    child: Text('${hovered.label}: ${widget.formatValue(hovered.value)}',
                        style: TextStyle(color: AppColors.text, fontSize: 11)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
