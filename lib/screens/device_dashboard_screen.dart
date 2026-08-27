import 'package:flutter/material.dart';

import '../localization.dart';
import '../theme.dart';
import '../widgets/device_dashboard.dart';

/// Egen helskärmsvy för trafik per enhet, nåbar genom att klicka på loggan.
///
/// Medvetet skild från den vanliga dashboarden: den visar brandväggens eget
/// tillstånd (CPU, minne, bandbredd per nätverkskort), medan den här svarar på
/// en annan fråga — vad enheterna på nätet gör.
class DeviceDashboardScreen extends StatelessWidget {
  const DeviceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices_other, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(tr('devdash.rubrik'),
                  style: TextStyle(
                      color: AppColors.text, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr('devdash.underrubrik'),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4)),
          const SizedBox(height: 14),
          const DeviceDashboard(),
        ],
      ),
    );
  }
}
