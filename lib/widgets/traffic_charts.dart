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
  PieChartPainter(this.slices);

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
    for (final s in slices) {
      final sweep = 2 * math.pi * (s.value / total);
      paint.color = s.color;
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
  bool shouldRepaint(covariant PieChartPainter old) => old.slices != slices;
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
  if (bits < 1000) return '$bits bps';
  const units = ['kbit/s', 'Mbit/s', 'Gbit/s'];
  var v = bits / 1000.0;
  var i = 0;
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}
