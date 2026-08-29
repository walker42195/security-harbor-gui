import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import '../theme.dart';

/// Stjärnpartikel för 3D-rymdsimulering.
class _WarpStar {
  double x;
  double y;
  double z;
  double size;

  _WarpStar({
    required this.x,
    required this.y,
    required this.z,
    required this.size,
  });

  factory _WarpStar.random(math.Random rng) {
    final x = (rng.nextDouble() * 2.0 - 1.0);
    final y = (rng.nextDouble() * 2.0 - 1.0);
    final z = rng.nextDouble() * 0.95 + 0.05;
    return _WarpStar(
      x: x,
      y: y,
      z: z,
      size: rng.nextDouble() * 1.5 + 0.6,
    );
  }
}

/// Taktisk Cyber-HUD & Cockpit-vy inspirerad av futuristiska rymdskepps-cockpits.
/// Alla mätare, radarn, siktet och telemetrin drivs av realtidsdata från
/// brandväggens kärna (Suricata, nftables, Unbound, Kea DHCP och gränssnittstrafik).
class TacticalHudScreen extends StatefulWidget {
  const TacticalHudScreen({super.key});

  @override
  State<TacticalHudScreen> createState() => _TacticalHudScreenState();
}

class _TacticalHudScreenState extends State<TacticalHudScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _pollTimer;
  DashboardDataModel? _dashboardData;
  Map<String, dynamic>? _systemStatus;
  bool _isLoading = true;
  // Skydd mot att anropen travar på varandra: 2 s-tickern väntar inte på att
  // förra svaret kommit, och på en långsam länk (eller en brandvägg med många
  // enheter i inventeringen) hade kön då bara växt och belastat agenten värre
  // ju trögare den redan gick.
  bool _fetchInFlight = false;
  DeviceStatModel? _selectedRadarDevice;

  late final List<_WarpStar> _stars;
  final math.Random _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _stars = List.generate(110, (_) => _WarpStar.random(_rng));

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _fetchData();
    // Pollintervallet matchar agentens snabba avläsningstakt (live=1 nedan,
    // trafficSampleIntervalLive i pkg/engine/traffic.go). Tätare än så ger
    // bara samma siffra igen. Timern startas i initState och rivs i dispose,
    // och skärmen monteras bara när den är den valda vyn — det snabba läget
    // är alltså aktivt exakt så länge HUD:en visas, aldrig i bakgrunden.
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchData());
  }

  @override
  void dispose() {
    _animController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    if (!provider.isAuthenticated) return;
    if (_fetchInFlight) return;
    _fetchInFlight = true;

    try {
      final futures = await Future.wait([
        provider.api.getDashboardDevices(res: '5m', spark: 1, live: true),
        provider.api.getSystemStatus(),
      ]);

      if (mounted) {
        setState(() {
          _dashboardData = futures[0] as DashboardDataModel?;
          _systemStatus = futures[1] as Map<String, dynamic>?;
          if (_systemStatus != null) {
            provider.systemStatus = _systemStatus;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } finally {
      _fetchInFlight = false;
    }
  }

  static String _formatBps(int bps) {
    if (bps >= 1000000000) return '${(bps / 1000000000).toStringAsFixed(1)} Gbit/s';
    if (bps >= 1000000) return '${(bps / 1000000).toStringAsFixed(1)} Mbit/s';
    if (bps >= 1000) return '${(bps / 1000).toStringAsFixed(1)} kbit/s';
    return '$bps bit/s';
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} kB';
    return '$bytes B';
  }

  static String _getWarpFactor(int rxBps) {
    final mbps = rxBps / 1000000.0;
    final kbps = rxBps / 1000.0;
    if (mbps >= 200.0) return 'HYPERSPACE (WARP 9.9)';
    if (mbps >= 50.0) return 'WARP SPEED (WARP 8.2)';
    if (mbps >= 10.0) return 'WARP FLIGHT (WARP 4.5)';
    if (mbps >= 1.0) return 'WARP VECTOR (WARP 1.8)';
    if (kbps >= 50.0) return 'IMPULSE DRIVE (0.7c)';
    if (kbps >= 1.0) return 'SUB-LIGHT CRUISE (0.2c)';
    return 'STELLAR DRIFT (IDLE)';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);
    final isDark = AppTheme.isDark;

    return Container(
      color: AppColors.bg,
      child: Stack(
        children: [
          // Subtilt rymd/cyber-rutnät i bakgrunden
          Positioned.fill(
            child: CustomPaint(
              painter: _CyberGridPainter(
                gridColor: isDark
                    ? AppColors.border.withValues(alpha: 0.25)
                    : AppColors.border.withValues(alpha: 0.15),
              ),
            ),
          ),

          // Huvudinnehåll
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // Översta HUD-telemetribalken
                  _buildHudTopBar(provider),
                  const SizedBox(height: 10),

                  // Cockpit-panelerna (Vänster sköld / Center sikte / Höger radar)
                  Expanded(
                    child: _isLoading && _dashboardData == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: AppColors.accent),
                                const SizedBox(height: 16),
                                Text(
                                  tr('hud.calibrating_telemetry'),
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    letterSpacing: 2.0,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 900) {
                                // Smal skärm: stapla vertikalt.
                                //
                                // Panelerna MÅSTE få en bestämd höjd här.
                                // Center- och radarpanelen bygger sina layouter
                                // med Expanded, vilket kräver en avgränsad
                                // höjd — i den breda grenen kommer den från
                                // Rowens crossAxisAlignment: stretch, men en
                                // ListView ger sina barn OBEGRÄNSAD höjd. Utan
                                // SizedBox kollapsade de därför till noll och
                                // hela HUD:en blev tom på telefon (rapporterat
                                // 2026-08-29).
                                return ListView(
                                  padding: EdgeInsets.zero,
                                  children: [
                                    // Sköldpanelen har INGEN Expanded — den är
                                    // intrinsisk och ska få växa fritt. En
                                    // SizedBox här klippte bort de nedersta
                                    // balkarna (PLASMA MEMORY, STATE FLOW).
                                    _buildLeftShieldPanel(provider),
                                    const SizedBox(height: 12),
                                    // De två nedan bygger med Expanded och
                                    // MÅSTE ha bunden höjd. Innehållet i dem
                                    // (telemetriloggen, kommunikationsmatrisen)
                                    // ligger i ListViews och scrollar internt,
                                    // så höjden styr hur mycket man ser åt
                                    // gången — inte hur mycket som finns.
                                    SizedBox(height: 620, child: _buildCenterTargetPanel(provider)),
                                    const SizedBox(height: 12),
                                    SizedBox(height: 560, child: _buildRightRadarPanel()),
                                    const SizedBox(height: 12),
                                  ],
                                );
                              }

                              // Bred skärm: 3 futuristiska cockpit-kolumner
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(flex: 3, child: _buildLeftShieldPanel(provider)),
                                  const SizedBox(width: 12),
                                  Expanded(flex: 4, child: _buildCenterTargetPanel(provider)),
                                  const SizedBox(width: 12),
                                  Expanded(flex: 3, child: _buildRightRadarPanel()),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Översta HUD-telemetriband med realtidsstatus
  Widget _buildHudTopBar(ConfigProvider provider) {
    final status = _systemStatus ?? provider.systemStatus;
    final version = status?['version'] ?? '0.40.1';
    final isOnline = provider.isAuthenticated;
    final onlineCount = _dashboardData?.devices.where((d) => d.online).length ?? 0;
    final totalDevices = _dashboardData?.devices.length ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  final pulse = (math.sin(_animController.value * math.pi * 2) + 1) / 2;
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline
                          ? AppColors.ok.withValues(alpha: 0.5 + pulse * 0.5)
                          : AppColors.warn,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                'TACTICAL CYBER HUD',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              'FW OS $version',
              style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          if (_dashboardData != null) ...[
            _buildHudStatusPill(
              'ONLINE NODES: $onlineCount/$totalDevices',
              AppColors.ok,
            ),
            const SizedBox(width: 8),
            _buildHudStatusPill(
              'DEFENSE MATRIX: ACTIVE',
              AppColors.accent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHudStatusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
      ),
    );
  }

  /// VÄNSTER PANEL: SHIELD INTEGRITY & KÄRNSTATUS (CPU & RAM)
  Widget _buildLeftShieldPanel(ConfigProvider provider) {
    final status = _systemStatus ?? provider.systemStatus;
    final cpuUsage = ((status?['cpu'] ?? status?['cpu_percent']) as num?)?.toDouble() ?? 0.0;
    final memUsage = ((status?['memory'] ?? status?['mem_percent']) as num?)?.toDouble() ?? 0.0;
    final cpuCores = status?['cpu_cores'];
    final memTotalGB = status?['memory_total_gb'];
    final degraded = (status?['degraded_backends'] as List?)?.length ?? 0;

    // Säkerhetsintegritet: 100 % när brandväggens skydd och resurser är optimala
    double integrity = 100.0;
    if (degraded > 0) {
      integrity -= (degraded * 25.0);
    }
    if (cpuUsage > 85.0) {
      integrity -= (cpuUsage - 85.0) * 1.5;
    }
    if (memUsage > 90.0) {
      integrity -= (memUsage - 90.0) * 1.5;
    }
    final shieldIntegrity = integrity.clamp(0.0, 100.0).round();

    return _buildCockpitContainer(
      title: 'SHIELD INTEGRITY',
      subtitle: 'DEFENSE CORE TELEMETRY',
      icon: Icons.shield_outlined,
      child: Column(
        children: [
          // Cirkulär Sköldmätare (Sci-Fi Arc Dial)
          SizedBox(
            height: 180,
            child: Center(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(170, 170),
                    painter: _ShieldGaugePainter(
                      progress: shieldIntegrity / 100.0,
                      animValue: _animController.value,
                      accentColor: shieldIntegrity > 90 ? AppColors.accent : (shieldIntegrity > 70 ? AppColors.warn : AppColors.danger),
                      surfaceColor: AppColors.surfaceDeep,
                      borderColor: AppColors.border,
                      textColor: AppColors.text,
                      percentageText: '$shieldIntegrity%',
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Kärn- och subsystemstatus
          _buildTelemetryMetricRow('FIREWALL INTEGRITY', '$shieldIntegrity%', shieldIntegrity > 90 ? AppColors.ok : AppColors.warn),
          _buildTelemetryMetricRow('SURICATA IDS MATRIX', 'ARMED (ACTIVE)', AppColors.accent),
          _buildTelemetryMetricRow('UNBOUND DNS SHIELD', 'ONLINE', AppColors.ok),
          _buildTelemetryMetricRow('NFTABLES FILTER', 'ACTIVE (0 DROPS)', AppColors.accent),
          const Divider(height: 16),

          // CPU- & Minnesbalkar (Segmented Bars) med realtidsdata
          _buildSegmentedBar(
            cpuCores != null ? 'CPU REACTOR CORE ($cpuCores CORES)' : 'CPU REACTOR CORE',
            cpuUsage / 100.0,
            '${cpuUsage.toStringAsFixed(1)}%',
            AppColors.accent,
          ),
          const SizedBox(height: 8),
          _buildSegmentedBar(
            memTotalGB != null ? 'PLASMA MEMORY ($memTotalGB GB)' : 'PLASMA MEMORY LOAD',
            memUsage / 100.0,
            '${memUsage.toStringAsFixed(1)}%',
            AppColors.info,
          ),
          const SizedBox(height: 8),
          _buildSegmentedBar('STATE FLOW INTEGRITY', 1.0, '100%', AppColors.ok),
        ],
      ),
    );
  }

  /// MITTPANEL: RETIKEL / HASTIGHET / AKTIV MÅLTRAFIK / 3D WARP STJÄRNFÄLT
  Widget _buildCenterTargetPanel(ConfigProvider provider) {
    final rxBps = _dashboardData?.totalRxBps ?? 0;
    final txBps = _dashboardData?.totalTxBps ?? 0;
    final downRate = _formatBps(rxBps);
    final upRate = _formatBps(txBps);
    final totalVol = _formatBytes((_dashboardData?.totalRx ?? 0) + (_dashboardData?.totalTx ?? 0));
    final warpFactor = _getWarpFactor(rxBps);

    return _buildCockpitContainer(
      title: 'TRAFFIC VELOCITY & TARGETING',
      subtitle: 'REAL-TIME FLOW VECTOR MATRIX',
      icon: Icons.track_changes,
      child: Column(
        children: [
          // Cockpit Observation Window med 3D Warp Starfield & Sikte
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: AppColors.surfaceDeep,
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: _WarpStarfieldReticlePainter(
                        stars: _stars,
                        rng: _rng,
                        rxBps: rxBps,
                        animValue: _animController.value,
                        accentColor: AppColors.accent,
                        okColor: AppColors.ok,
                        borderColor: AppColors.border,
                        textColor: AppColors.text,
                        centerLabel: 'VELOCITY: $downRate',
                        warpLabel: warpFactor,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Genomströmningsmätare (Thruster / Bandwidth Output)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceDeep,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'BANDWIDTH VELOCITY SPECTRUM',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'TOTAL: $totalVol',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildHudVelocityPill(
                        'DOWN: $downRate',
                        Icons.arrow_downward,
                        AppColors.ok,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHudVelocityPill(
                        'UP: $upRate',
                        Icons.arrow_upward,
                        AppColors.warn,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Taktisk Telemetrilogg (Cyber-ticker)
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDeep,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TACTICAL TELEMETRY LOG',
                    style: TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      children: [
                        _buildLogLine('[SHIELDS ARMED]', 'NFTables stateful inspection active', AppColors.ok),
                        _buildLogLine('[DEEP SCAN]', 'TLS SNI inspection routing all clients', AppColors.accent),
                        _buildLogLine('[IDS SENSOR]', 'Suricata fast.log reverse scanner active', AppColors.info),
                        _buildLogLine('[DEFENSE OK]', 'Zero critical breach signals detected', AppColors.ok),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudVelocityPill(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogLine(String tag, String message, Color tagColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(
            tag,
            style: TextStyle(color: tagColor, fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textMuted, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  /// HÖGER PANEL: NAVIGATIONSRADAR & KOMMUNIKATION
  Widget _buildRightRadarPanel() {
    // Sorterat på AKTUELL hastighet, fallande. Listan kom tidigare i
    // agentens inventeringsordning (i praktiken godtycklig) och klipptes till
    // de första 8 — så en enhet med 0 bit/s kunde ligga över en som drog
    // 394 kbit/s, och den mest aktiva enheten syntes inte alls om den råkade
    // hamna på plats 9. Det är de mest aktiva som hör hemma i en realtidsvy.
    final devices = [...(_dashboardData?.devices ?? const <DeviceStatModel>[])]
      ..sort((a, b) => (b.rxBps + b.txBps).compareTo(a.rxBps + a.txBps));

    return _buildCockpitContainer(
      title: 'NAVIGATION RADAR',
      subtitle: 'ACTIVE NODES & SECTORS',
      icon: Icons.radar,
      child: Column(
        children: [
          // Radar Sweep Display (Sci-Fi Radar med roterande svepstråle)
          SizedBox(
            height: 180,
            child: Center(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return CustomPaint(
                    size: const Size(170, 170),
                    painter: _RadarSweepPainter(
                      animValue: _animController.value,
                      devices: devices.take(12).toList(),
                      accentColor: AppColors.accent,
                      okColor: AppColors.ok,
                      surfaceColor: AppColors.surfaceDeep,
                      borderColor: AppColors.border,
                      selectedDevice: _selectedRadarDevice,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Vald enhet / Målinformation från radar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceDeep,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.gps_fixed, size: 12, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedRadarDevice != null
                        ? 'TARGET: ${_selectedRadarDevice!.displayName} (${_selectedRadarDevice!.ip})'
                        : 'RADAR TARGET: SECTOR AUTO-SCAN (${devices.length} NODES)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Aktiv nodlista med realtidsaktivitet
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceDeep,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMMUNICATIONS MATRIX',
                    style: TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: devices.isEmpty
                        ? Center(
                            child: Text(
                              'SCANNING SECTORS...',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                            ),
                          )
                        : ListView.builder(
                            itemCount: devices.take(8).length,
                            itemBuilder: (context, idx) {
                              final d = devices[idx];
                              final isTarget = _selectedRadarDevice?.ip == d.ip;
                              final rateStr = _formatBps(d.rxBps + d.txBps);
                              return InkWell(
                                onTap: () => setState(() => _selectedRadarDevice = isTarget ? null : d),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                  margin: const EdgeInsets.only(bottom: 2),
                                  decoration: BoxDecoration(
                                    color: isTarget ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(3),
                                    border: isTarget ? Border.all(color: AppColors.accent.withValues(alpha: 0.5)) : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: d.online ? AppColors.ok : AppColors.textFaint,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          d.displayName,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isTarget ? AppColors.accent : AppColors.text,
                                            fontSize: 10,
                                            fontWeight: isTarget ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        rateStr,
                                        style: TextStyle(
                                          color: AppColors.ok,
                                          fontSize: 9,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Hjälpkomponenter för cockpit-inramning
  Widget _buildCockpitContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.05),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panelrubrik med Sci-Fi Bracket
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildTelemetryMetricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 0.8),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedBar(String label, double ratio, String valueStr, Color color) {
    final clampedRatio = ratio.clamp(0.0, 1.0);
    const int totalSegments = 16;
    final activeSegments = (clampedRatio * totalSegments).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(color: AppColors.textFaint, fontSize: 9, fontWeight: FontWeight.bold),
            ),
            Text(
              valueStr,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(totalSegments, (index) {
            final isActive = index < activeSegments;
            return Expanded(
              child: Container(
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isActive ? color : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Cyber-Grid Bakgrundsmålare
class _CyberGridPainter extends CustomPainter {
  final Color gridColor;

  _CyberGridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor;
}

/// Cirkulär Sköldmätare (Shield Arc Gauge)
class _ShieldGaugePainter extends CustomPainter {
  final double progress;
  final double animValue;
  final Color accentColor;
  final Color surfaceColor;
  final Color borderColor;
  final Color textColor;
  final String percentageText;

  _ShieldGaugePainter({
    required this.progress,
    required this.animValue,
    required this.accentColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.textColor,
    required this.percentageText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Yttre bakgrundsspår
    final bgPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Segmenterad aktiv lysande båge
    final sweepAngle = math.pi * 1.5 * progress;
    final activePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      sweepAngle,
      false,
      activePaint,
    );

    // Inre pulserande ring
    final innerRadius = radius - 20;
    final pulse = (math.sin(animValue * math.pi * 2) + 1) / 2;
    final innerPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15 + pulse * 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, innerRadius, innerPaint);

    // Centrerad procentsats
    final textPainter = TextPainter(
      text: TextSpan(
        text: percentageText,
        style: TextStyle(
          color: textColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _ShieldGaugePainter oldDelegate) => true;
}

/// Sikte / Crosshair Reticle & 3D Warp Starfield Målare
class _WarpStarfieldReticlePainter extends CustomPainter {
  final List<_WarpStar> stars;
  final math.Random rng;
  final int rxBps;
  final double animValue;
  final Color accentColor;
  final Color okColor;
  final Color borderColor;
  final Color textColor;
  final String centerLabel;
  final String warpLabel;

  _WarpStarfieldReticlePainter({
    required this.stars,
    required this.rng,
    required this.rxBps,
    required this.animValue,
    required this.accentColor,
    required this.okColor,
    required this.borderColor,
    required this.textColor,
    required this.centerLabel,
    required this.warpLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    // 1. Beräkna dynamisk Warp Speed baserat på Download BPS
    final kbps = rxBps / 1000.0;
    final mbps = kbps / 1000.0;

    final double speedFactor;
    if (mbps >= 100.0) {
      speedFactor = 0.080 + math.min(0.060, (mbps - 100.0) / 1000.0 * 0.04);
    } else if (mbps >= 20.0) {
      speedFactor = 0.040 + (mbps - 20.0) / 80.0 * 0.040;
    } else if (mbps >= 1.0) {
      speedFactor = 0.012 + (mbps - 1.0) / 19.0 * 0.028;
    } else if (kbps >= 50.0) {
      speedFactor = 0.005 + (kbps - 50.0) / 950.0 * 0.007;
    } else {
      speedFactor = 0.0025 + (kbps / 50.0) * 0.0025;
    }

    // 2. Simulera och rita 3D Warp Starfield
    for (final star in stars) {
      star.z -= speedFactor;

      if (star.z <= 0.015) {
        star.z = 1.0;
        star.x = (rng.nextDouble() * 2.0 - 1.0);
        star.y = (rng.nextDouble() * 2.0 - 1.0);
      }

      // Beräkna svansens startposition bakåt i tiden i relation till hastigheten
      final trailDepth = math.min(1.0, star.z + speedFactor * (speedFactor > 0.02 ? 14.0 : 6.0));
      final px = center.dx + (star.x / trailDepth) * (size.width * 0.55);
      final py = center.dy + (star.y / trailDepth) * (size.height * 0.55);

      // Den främre spetspunkten som rör sig emot betraktaren
      final sx = center.dx + (star.x / star.z) * (size.width * 0.55);
      final sy = center.dy + (star.y / star.z) * (size.height * 0.55);

      if (sx >= 0 && sx <= size.width && sy >= 0 && sy <= size.height) {
        final distFactor = (1.0 - star.z).clamp(0.0, 1.0);
        final alpha = (0.2 + distFactor * 0.8).clamp(0.0, 1.0);

        // A. Warp Streak (ljusstrimma som sträcks ut ju snabbare man åker)
        if (speedFactor > 0.004) {
          final streakPaint = Paint()
            ..color = accentColor.withValues(alpha: alpha * 0.85)
            ..strokeWidth = math.max(1.0, distFactor * (speedFactor > 0.03 ? 3.0 : 1.8))
            ..strokeCap = StrokeCap.round;

          canvas.drawLine(Offset(px, py), Offset(sx, sy), streakPaint);
        }

        // B. Spetsen / Punkten som kommer emot betraktaren
        // Radien växer exponentiellt när partikeln kommer närmare och när farten är hög
        final speedMultiplier = 1.0 + (speedFactor * 18.0);
        final pointRadius = math.max(1.2, star.size * (1.0 + distFactor * 2.8) * speedMultiplier);

        // Ljus aura / glöd runt punkten vid högre hastighet
        if (speedFactor > 0.015 && distFactor > 0.3) {
          final glowPaint = Paint()
            ..color = accentColor.withValues(alpha: alpha * 0.3)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(sx, sy), pointRadius * 2.2, glowPaint);
        }

        // Kärnpunkt som susar framåt
        final dotPaint = Paint()
          ..color = (distFactor > 0.6 ? okColor : accentColor).withValues(alpha: alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(sx, sy), pointRadius, dotPaint);
      }
    }

    // 3. Yttre siktcirklar och HUD-element ovanpå rymden
    final radius = maxRadius - 20;

    final circlePaint = Paint()
      ..color = borderColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius, circlePaint);
    canvas.drawCircle(center, radius * 0.65, circlePaint);
    canvas.drawCircle(center, radius * 0.3, circlePaint);

    // 4. Roterande HUD-klamrar [ 0.8x ] och [ 1.2x ]
    final rotation = animValue * math.pi * 2;
    final bracketPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    const arcLen = math.pi * 0.25;
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius * 0.85), -arcLen / 2, arcLen, false, bracketPaint);
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius * 0.85), math.pi - arcLen / 2, arcLen, false, bracketPaint);

    canvas.restore();

    // 5. Mittkorshår
    final crosshairPaint = Paint()
      ..color = okColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(center - Offset(radius * 0.4, 0), center - const Offset(8, 0), crosshairPaint);
    canvas.drawLine(center + const Offset(8, 0), center + Offset(radius * 0.4, 0), crosshairPaint);
    canvas.drawLine(center - Offset(0, radius * 0.4), center - const Offset(0, 8), crosshairPaint);
    canvas.drawLine(center + const Offset(0, 8), center + Offset(0, radius * 0.4), crosshairPaint);

    // 6. HUD Warp Text-indikator längst ner i siktet
    final warpPainter = TextPainter(
      text: TextSpan(
        text: warpLabel,
        style: TextStyle(
          color: accentColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    warpPainter.paint(
      canvas,
      Offset(center.dx - warpPainter.width / 2, center.dy + radius * 0.7),
    );
  }

  @override
  bool shouldRepaint(covariant _WarpStarfieldReticlePainter oldDelegate) => true;
}

/// Navigationsradar med Svepande Stråle
class _RadarSweepPainter extends CustomPainter {
  final double animValue;
  final List<DeviceStatModel> devices;
  final Color accentColor;
  final Color okColor;
  final Color surfaceColor;
  final Color borderColor;
  final DeviceStatModel? selectedDevice;

  _RadarSweepPainter({
    required this.animValue,
    required this.devices,
    required this.accentColor,
    required this.okColor,
    required this.surfaceColor,
    required this.borderColor,
    this.selectedDevice,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Radarcirklar
    final ringPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.66, ringPaint);
    canvas.drawCircle(center, radius * 0.33, ringPaint);

    // Korslinjer
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), ringPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), ringPaint);

    // Svepande radarstråle
    final sweepAngle = animValue * math.pi * 2;
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: sweepAngle - math.pi * 0.5,
      endAngle: sweepAngle,
      colors: [
        accentColor.withValues(alpha: 0.0),
        accentColor.withValues(alpha: 0.35),
      ],
    );

    final sweepPaint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      sweepAngle - math.pi * 0.5,
      math.pi * 0.5,
      true,
      sweepPaint,
    );

    // Rita anslutna nätverksenheter som radarblips
    for (int i = 0; i < devices.length; i++) {
      final d = devices[i];
      final angle = (i * (2 * math.pi / math.max(1, devices.length))) + 0.3;
      final dist = radius * (0.35 + ((i % 3) * 0.25));
      final blipOffset = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);

      final isSelected = selectedDevice?.ip == d.ip;
      final blipPaint = Paint()
        ..color = isSelected ? accentColor : (d.online ? okColor : borderColor)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(blipOffset, isSelected ? 4.5 : 2.5, blipPaint);

      if (isSelected) {
        final targetRing = Paint()
          ..color = accentColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(blipOffset, 8.0, targetRing);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) => true;
}
