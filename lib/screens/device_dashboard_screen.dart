import 'package:flutter/material.dart';

import '../localization.dart';
import '../theme.dart';
import '../widgets/device_dashboard.dart';
import '../widgets/traffic_types_view.dart';

/// Egen helskärmsvy nåbar genom att klicka på loggan, med två flikar.
///
/// Medvetet skild från den vanliga dashboarden: den visar brandväggens eget
/// tillstånd (CPU, minne, bandbredd per nätverkskort), medan de här svarar på
/// andra frågor — VILKA enheter som använder nätet, och VAD de använder det
/// till.
class DeviceDashboardScreen extends StatefulWidget {
  const DeviceDashboardScreen({super.key});

  @override
  State<DeviceDashboardScreen> createState() => _DeviceDashboardScreenState();
}

class _DeviceDashboardScreenState extends State<DeviceDashboardScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _tabButton(0, Icons.devices_other, tr('devdash.rubrik')),
            const SizedBox(width: 8),
            _tabButton(1, Icons.donut_small, tr('traftype.rubrik')),
          ]),
          const SizedBox(height: 6),
          Text(_tab == 0 ? tr('devdash.underrubrik') : tr('traftype.underrubrik'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4)),
          const SizedBox(height: 14),
          // Vyerna byggs om vid flikbyte i stället för att hållas vid liv:
          // båda pollar backend, och den som inte syns ska inte trafikera.
          if (_tab == 0) const DeviceDashboard() else const TrafficTypesView(),
        ],
      ),
    );
  }

  Widget _tabButton(int index, IconData icon, String label) {
    final sel = _tab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: sel ? AppColors.accent : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: sel ? AppColors.accent : AppColors.textMuted),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: sel ? AppColors.accent : AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}
