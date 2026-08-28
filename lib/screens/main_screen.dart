import 'dart:async';
import '../theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization.dart';
import '../config_diff.dart';
import '../models/config_model.dart';
import '../providers/config_provider.dart';
import 'dashboard_screen.dart';
import 'interfaces_screen.dart';
import 'routes_screen.dart';
import 'policies_screen.dart';
import 'objects_screen.dart';
import 'sni_routes_screen.dart';
import 'settings_screen.dart';
import 'connections_screen.dart';
import 'vpn_screen.dart';
import 'dns_screen.dart';
import 'dns_devices_screen.dart';
import 'dhcp_screen.dart';
import 'device_dashboard_screen.dart';
import 'ids_rules_screen.dart';
import 'security_events_screen.dart';
import 'services_screen.dart';

import 'tools_screen.dart';
import 'tactical_hud_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// Under denna bredd (dp) räknas fönstret som "smalt" (telefon i stående
// läge) — NavigationRailen (som ensam tar ~60-90px + text) lämnar då för
// lite kvar åt innehållet, vilket t.ex. dashboardens statistik-kort visade
// tydligt (text radbruten till en bokstav per rad, upptäckt 2026-08-24 av
// en administratör som testade Android-appen på riktigt). Under
// brytpunkten döljs NavigationRailen helt till förmån för en Drawer
// (hamburgermeny), så innehållet får hela bredden.
const double _kNarrowBreakpoint = 700;

class _MainScreenState extends State<MainScreen> {
  /// Enhets-dashboarden är STARTVYN och nås därefter via loggan. Den ligger
  /// utanför menyn, så ett negativt index betyder "ingen menypost markerad" —
  /// NavigationRail tar null som selectedIndex för just det.
  static const int _kDeviceDashboardIndex = -1;

  int _selectedIndex = _kDeviceDashboardIndex;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Larmbanner för tjänster i "failed"-läge — pollas globalt här (inte bara
  // på Tjänster-fliken, se services_screen.dart) så en administratör ser
  // det oavsett vilken vy de råkar stå på. Efterfrågat 2026-08-24, samma
  // dag Kea DHCP fastnade i "failed" utan att synas förrän man själv
  // klickade in på Tjänster-fliken.
  List<ServiceStatusModel> _failedServices = [];
  Timer? _servicesPollTimer;

  @override
  void initState() {
    super.initState();
    _pollServices();
    _servicesPollTimer = Timer.periodic(const Duration(seconds: 20), (_) => _pollServices());
  }

  @override
  void dispose() {
    _servicesPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollServices() async {
    final provider = Provider.of<ConfigProvider>(context, listen: false);
    if (!provider.isAuthenticated) return;
    final services = await provider.api.getServicesStatus();
    if (!mounted) return;
    setState(() => _failedServices = services.where((s) => s.active == 'failed').toList());
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);

    // Enkelkorts-/värddator-läge (Fas 13): VPN-server, DHCP/DNS-resolver
    // och IDS är gateway-/router-roller som aldrig är relevanta för en
    // enskild dator — döljs helt istället för att visa tomma/meningslösa
    // skärmar. Interfaces/Policies/Objekt/Loggning/Verktyg/Settings gäller
    // fortfarande (INPUT/OUTPUT-hårdning är precis vad host-läget gör).
    final isHostMode = provider.runningConfig?.settings.isHostMode ?? false;

    final screens = <Widget>[
      const DashboardScreen(),
      const TacticalHudScreen(),
      const InterfacesScreen(),
      const PoliciesScreen(),
      const ObjectsScreen(),
      // Routing ligger under Objekt: det är en sällan rörd inställning, och
      // Policies/Objekt är det man arbetar i dagligen.
      const RoutesScreen(),
      if (!isHostMode) const SniRoutesScreen(),
      if (!isHostMode) const VpnScreen(),
      if (!isHostMode) const DnsScreen(),
      if (!isHostMode) const DnsDevicesScreen(),
      if (!isHostMode) const DhcpScreen(),
      const ConnectionsScreen(),
      if (!isHostMode) const SecurityEventsScreen(),
      if (!isHostMode) const IdsRulesScreen(),
      const ServicesScreen(),
      const ToolsScreen(),
      const SettingsScreen(),
    ];
    final destinations = <NavigationRailDestination>[
      NavigationRailDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: Text(tr('nav.dashboard'))),
      NavigationRailDestination(icon: const Icon(Icons.radar_outlined), selectedIcon: const Icon(Icons.radar), label: Text(tr('nav.tactical_hud'))),
      NavigationRailDestination(icon: const Icon(Icons.router_outlined), selectedIcon: const Icon(Icons.router), label: Text(tr('nav.interfaces'))),
      NavigationRailDestination(icon: const Icon(Icons.shield_outlined), selectedIcon: const Icon(Icons.shield), label: Text(tr('nav.policies'))),
      NavigationRailDestination(icon: const Icon(Icons.category_outlined), selectedIcon: const Icon(Icons.category), label: Text(tr('nav.objects'))),
      NavigationRailDestination(icon: const Icon(Icons.route_outlined), selectedIcon: const Icon(Icons.route), label: Text(tr('nav.routing'))),
      if (!isHostMode) NavigationRailDestination(icon: const Icon(Icons.alt_route_outlined), selectedIcon: const Icon(Icons.alt_route), label: Text(tr('nav.sni'))),
      if (!isHostMode) NavigationRailDestination(icon: const Icon(Icons.vpn_lock_outlined), selectedIcon: const Icon(Icons.vpn_lock), label: Text(tr('nav.vpn'))),
      if (!isHostMode) NavigationRailDestination(icon: const Icon(Icons.dns_outlined), selectedIcon: const Icon(Icons.dns), label: Text(tr('nav.dns'))),
      if (!isHostMode) NavigationRailDestination(icon: const Icon(Icons.devices_outlined), selectedIcon: const Icon(Icons.devices), label: Text(tr('nav.dns_devices'))),
      if (!isHostMode) NavigationRailDestination(icon: const Icon(Icons.devices_other_outlined), selectedIcon: const Icon(Icons.devices_other), label: Text(tr('nav.dhcp'))),
      NavigationRailDestination(icon: const Icon(Icons.list_alt_outlined), selectedIcon: const Icon(Icons.list_alt), label: Text(tr('nav.logging'))),
      if (!isHostMode) NavigationRailDestination(icon: const Icon(Icons.gpp_maybe_outlined), selectedIcon: const Icon(Icons.gpp_maybe), label: Text(tr('nav.ids'))),
      if (!isHostMode) NavigationRailDestination(icon: const Icon(Icons.rule_outlined), selectedIcon: const Icon(Icons.rule), label: Text(tr('nav.ids_rules'))),
      NavigationRailDestination(icon: const Icon(Icons.miscellaneous_services_outlined), selectedIcon: const Icon(Icons.miscellaneous_services), label: Text(tr('nav.services'))),
      NavigationRailDestination(icon: const Icon(Icons.build_circle_outlined), selectedIcon: const Icon(Icons.build_circle), label: Text(tr('nav.tools'))),
      NavigationRailDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: Text(tr('nav.settings'))),
    ];
    if (_selectedIndex >= screens.length) {
      _selectedIndex = 0;
    }

    return LayoutBuilder(builder: (context, outerConstraints) {
      final isNarrow = outerConstraints.maxWidth < _kNarrowBreakpoint;
      return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      // Drawer ersätter NavigationRailen på smala skärmar (se _kNarrowBreakpoint)
      // — byggs av samma `destinations`-lista så menyn alltid är i synk.
      drawer: isNarrow ? _buildDrawer(destinations) : null,
      body: SafeArea(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Slank Huvud-topplist (Top Header Bar) harmoniserad med Slate-temat.
          // Höjden är inte längre fast (42px) på smala skärmar — badgen med
          // servens URL kan bli lång, och en fast höjd gav då en overflow-
          // varning (gult/svart randigt mönster) i stället för att bara växa.
          Container(
            constraints: const BoxConstraints(minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              children: [
                if (isNarrow) ...[
                  IconButton(
                    icon: Icon(Icons.menu, color: AppColors.text, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: tr('main.menu_tooltip'),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  Icon(Icons.shield, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                ],
                // Flexible+ellipsis i stället för en obegränsad Text: på en
                // smal skärm fick titeln + badgar tidigare bara skjuta över
                // varandra (osynligt overflow) i stället för att synligt
                // krympa/klippas.
                if (!isNarrow)
                  Text(
                    tr('main.title'),
                    style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                if (!isNarrow) const SizedBox(width: 6),
                if (!isNarrow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'FIREWALL OS ${provider.systemStatus?['version'] ?? '—'}',
                      style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (!isNarrow && isHostMode) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.caution.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: AppColors.caution.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      tr('main.mode_host'),
                      style: TextStyle(color: AppColors.caution, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const Spacer(),
                // Anslutningsstatusen är den enda badgen som alltid syns
                // (även smalt) — men utan servens URL i klartext där, som
                // annars var det som fick raden att svälla ut mest.
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: provider.isAuthenticated ? AppColors.ok.withValues(alpha: 0.4) : AppColors.warn.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: provider.isAuthenticated ? AppColors.ok : AppColors.warn,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            provider.isAuthenticated
                                ? (isNarrow ? tr('main.online') : trp('main.online_with_url', {'url': provider.api.baseUrl}))
                                : tr('main.not_connected'),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: provider.isAuthenticated ? AppColors.ok : AppColors.warn,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Temaväxling i toppraden: snabbåtkomst till alla teman.
                const SizedBox(width: 8),
                PopupMenuButton<AppThemeMode>(
                  tooltip: tr('main.theme_toggle'),
                  color: AppColors.surface,
                  icon: Icon(
                    AppTheme.isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    size: 17,
                    color: AppColors.accent,
                  ),
                  splashRadius: 16,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  initialValue: AppTheme.mode,
                  onSelected: (mode) => AppTheme.instance.setMode(mode),
                  itemBuilder: (ctx) => AppThemeMode.values
                      .map((mode) => _themeMenuItem(
                            mode,
                            tr(mode.translationKey),
                            mode.icon,
                            mode.themeColor,
                          ))
                      .toList(),
                ),
                // WAN-adressen bredvid anslutningsindikatorn. Den är det man
                // oftast behöver läsa av snabbt (DNS-pekare, port forwards,
                // "har ISP:n bytt adress?") och låg annars begravd under
                // Gränssnitt. Adressen fylls i av agenten från kortets
                // faktiska tillstånd, även när WAN kör DHCP.
                if (_wanAddress(provider) case final wan?) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: tr('main.wan_ip_tooltip'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public, size: 11, color: AppColors.accent),
                          const SizedBox(width: 5),
                          Text(
                            isNarrow ? wan : '${tr('main.wan_ip')} $wan',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                if (provider.isAuthenticated)
                  IconButton(
                    icon: Icon(Icons.refresh, size: 16, color: AppColors.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: tr('main.refresh_tooltip'),
                    onPressed: provider.isLoading ? null : () => provider.refreshAll(),
                  ),
                if (provider.isAuthenticated) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.logout, size: 16, color: AppColors.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: tr('main.logout_tooltip'),
                    onPressed: () => provider.logout(),
                  ),
                ],
                // Användarnamnet döljs på smala skärmar — statusfärgen/
                // anslutningsbadgen är det som spelar roll där, och raden
                // hade annars fortsatt svälla ut trots allt ovan.
                if (!isNarrow) ...[
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(provider.api.username ?? '—', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Tjänstelarm — visas på ALLA vyer (inte bara Tjänster-fliken) så
          // en administratör märker det direkt, oavsett var de står.
          // Degraderade backends: appliceringen gick igenom, men en icke-
          // trafikstyrande funktion (i praktiken IDS) kunde inte startas.
          // Ska synas — annars försvinner det tyst i agentloggen.
          if ((provider.systemStatus?['degraded_backends'] as List?)?.isNotEmpty ?? false)
            Container(
              color: AppColors.warnSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warn, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (provider.systemStatus!['degraded_backends'] as List)
                          .map((w) => (w as Map)['message']?.toString() ?? '')
                          .where((m) => m.isNotEmpty)
                          .join('\n'),
                      style: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          if (_failedServices.isNotEmpty)
            Container(
              color: AppColors.dangerBanner,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _failedServices.length == 1
                            ? trp('main.service_alarm_one', {'name': _failedServices.first.name})
                            : trp('main.service_alarm_many', {'count': '${_failedServices.length}', 'names': _failedServices.map((s) => s.name).join(", ")}),
                        style: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.build_circle_outlined, size: 14),
                    label: Text(tr('main.show_services'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.text, side: BorderSide(color: AppColors.text), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                    onPressed: () {
                      final idx = screens.indexWhere((w) => w is ServicesScreen);
                      if (idx >= 0) setState(() => _selectedIndex = idx);
                    },
                  ),
                ],
              ),
            ),

          // Loading Status Banner
          if (provider.isLoading && provider.statusMessage != null)
            Container(
              color: AppColors.infoSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.text),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      provider.statusMessage!,
                      style: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Safe Apply Status Bar (Syns när konfigurationen är applicerad i
          // unconfirmed-läge). Text ovanför knappar (Column) i stället för
          // allt i EN Row — en lång brödtext i en Expanded bredvid två breda
          // knappar klämdes tidigare ihop till nästan 0px bredd på en
          // telefonskärm, vilket radbröt texten en bokstav i taget
          // (upptäckt 2026-08-24).
          if (provider.applyStatus == ApplyStatus.unconfirmed)
            Container(
              color: AppColors.cautionSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer, color: AppColors.warn, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          trp('main.safe_apply_banner', {'seconds': '${provider.rollbackSecondsRemaining}'}),
                          style: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle, size: 14),
                        label: Text(tr('main.confirm_commit'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.ok, foregroundColor: AppColors.onStatus, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                        onPressed: () async {
                          final ok = await provider.confirmChanges();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? tr('main.confirm_success') : tr('main.confirm_failed')),
                                backgroundColor: ok ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.undo, size: 14),
                        label: Text(tr('main.rollback'), style: const TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.text, side: BorderSide(color: AppColors.text), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                        onPressed: () async {
                          await provider.rollbackChanges();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(tr('main.rollback_success')),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            )
          else if (provider.hasUnappliedChanges ||
              (provider.candidateConfig != null &&
                  provider.runningConfig != null &&
                  provider.candidateConfig!.revision > provider.runningConfig!.revision))
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.accent, width: 1)),
              ),
              // Se kommentaren på Safe Apply-bannern ovan — samma
              // Column(text ovanför, Wrap(knappar) under) i stället för allt
              // i en Row, av samma anledning (2026-08-24).
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_note, color: AppColors.accent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr('main.unapplied_banner'),
                          style: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Ångra: kastar bort de oapplicerade ändringarna och
                      // återställer kandidaten till körande config. Räddar t.ex.
                      // en råkad borttagning av en regel innan Applicera tryckts.
                      OutlinedButton.icon(
                        icon: const Icon(Icons.undo, size: 14),
                        label: Text(tr('main.undo_changes'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.text, side: BorderSide(color: AppColors.textFaint), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              backgroundColor: AppColors.surface,
                              title: Text(tr('main.undo_dialog_title'), style: TextStyle(color: AppColors.text, fontSize: 14)),
                              content: Text(
                                tr('main.undo_dialog_body'),
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(tr('main.cancel'))),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(dctx, true),
                                  child: Text(tr('main.undo_confirm_button')),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          final ok = await provider.discardChanges();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? tr('main.undo_success')
                                    : (provider.errorMessage ?? tr('main.undo_failed_fallback'))),
                                backgroundColor: ok ? Colors.teal : Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      // Visa ändringar FÖRE Applicera. Att applicera en
                      // brandväggskonfiguration är en handling med
                      // konsekvenser — GUI:t visade tidigare bara ATT det
                      // fanns oapplicerade ändringar, aldrig vilka.
                      OutlinedButton.icon(
                        icon: const Icon(Icons.difference_outlined, size: 14),
                        label: Text(tr('main.show_changes'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent, side: BorderSide(color: AppColors.accent), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                        onPressed: () => _showPendingChanges(context, provider),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow, size: 14),
                        label: Text(tr('main.apply_safe'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBg, foregroundColor: AppColors.onAccentBg, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                        onPressed: () async {
                          final ok = await provider.applyChanges();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? tr('main.apply_success')
                                    // Visar servers faktiska felmeddelande (t.ex. ett
                                    // valideringsfel om en policys zon inte matchar
                                    // något gränssnitt) istället för en generisk text
                                    // utan detaljer - upptäckt 2026-08-19 att den
                                    // gamla generiska texten gjorde det omöjligt att
                                    // förstå VARFÖR Apply misslyckades.
                                    : (provider.errorMessage ?? tr('main.apply_failed_fallback'))),
                                backgroundColor: ok ? Colors.teal : Colors.red,
                                duration: Duration(seconds: ok ? 4 : 8),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

          Expanded(
            child: Row(
              // start i stället för Row:ens default (center): sidomenyn
              // krymper till sin egen innehållshöjd (den ligger i en
              // SingleChildScrollView, se kommentaren nedan) och hamnade då
              // mitt i fönstret på en hög skärm i stället för högst upp
              // (upptäckt 2026-08-24). Påverkar inte innehållspanelen till
              // höger, som redan fyller hela höjden oavsett.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Navigation Sidebar — bara på breda skärmar (se
                // _kNarrowBreakpoint); på smala ersätts den helt av en Drawer
                // (_buildDrawer), annars lämnar den för lite bredd kvar åt
                // innehållet (upptäckt 2026-08-24: en administratörs
                // Android-telefon fick t.ex. dashboardens statistik-kort så
                // smala att texten radbröts en bokstav i taget).
                //
                // VisualDensity.compact + mindre ikoner/etiketter/leading-
                // logga krymper var post radikalt (upptäckt samma dag: med
                // standardstorlek och 13 menyposter + leading-logga tog
                // listan över 1000px höjd, vilket inte fick plats under
                // 1080px hög skärm minus topplist/webbläsarchrome — de sista
                // posterna klipptes bort utan att NavigationRail scrollar).
                // SingleChildScrollView är dessutom ett strukturellt
                // skyddsnät: om listan ändå skulle bli för hög (fler
                // menyposter i framtiden, eller en ännu lägre skärm) går den
                // att scrolla i stället för att klippas/overflowa tyst.
                if (!isNarrow) ...[
                  Theme(
                    data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
                    child: SingleChildScrollView(
                      child: IntrinsicHeight(
                        child: NavigationRail(
                            backgroundColor: AppColors.sidebarBg,
                            selectedIndex: _selectedIndex < 0 ? null : _selectedIndex,
                            onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                            labelType: NavigationRailLabelType.all,
                            useIndicator: true,
                            indicatorColor: AppColors.accent.withValues(alpha: 0.15),
                            indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            minWidth: 56,
                            selectedIconTheme: IconThemeData(color: AppColors.accent, size: 18),
                            selectedLabelTextStyle: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 9),
                            unselectedIconTheme: IconThemeData(color: AppColors.textMuted, size: 18),
                            unselectedLabelTextStyle: TextStyle(color: AppColors.textMuted, fontSize: 9),
                            leading: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                children: [
                                  // Loggan är en genväg tillbaka till
                                  // dashboarden, samma konvention som en
                                  // hem-knapp i en webbtjänst.
                                  Tooltip(
                                    message: tr('devdash.rubrik'),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(5),
                                      onTap: () => setState(() => _selectedIndex = _kDeviceDashboardIndex),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(5),
                                        child: Image.asset(
                                          'assets/logo.png',
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Icon(Icons.shield, color: AppColors.accent, size: 22),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            destinations: destinations,
                          ),
                        ),
                      ),
                    ),
                  VerticalDivider(thickness: 1, width: 1, color: AppColors.border),
                ],
                Expanded(
                  child: _selectedIndex < 0
                      ? const DeviceDashboardScreen()
                      : screens[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
    });
  }

  // Drawer-versionen av navigationen (smala skärmar) — byggd av samma
  // `destinations`-lista (NavigationRailDestination) som den vanliga
  // NavigationRailen, så de två alltid visar exakt samma menyval i samma
  // ordning utan att någon lista kan glömmas bort att uppdatera för sig.
  Widget _buildDrawer(List<NavigationRailDestination> destinations) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(Icons.shield, color: AppColors.accent, size: 26),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(tr('main.title'), style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ],
              ),
            ),
            Divider(color: AppColors.divider, height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: destinations.length,
                itemBuilder: (context, idx) {
                  final selected = idx == _selectedIndex;
                  final dest = destinations[idx];
                  return ListTile(
                    leading: selected ? dest.selectedIcon : dest.icon,
                    title: DefaultTextStyle.merge(
                      style: TextStyle(color: selected ? AppColors.accent : AppColors.text, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13),
                      child: dest.label,
                    ),
                    iconColor: selected ? AppColors.accent : AppColors.textMuted,
                    selected: selected,
                    selectedTileColor: AppColors.accent.withValues(alpha: 0.08),
                    onTap: () {
                      setState(() => _selectedIndex = idx);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// WAN-gränssnittets adress, utan CIDR-suffix — toppraden ska visa adressen,
/// inte nätmasken. Returnerar null om ingen WAN-zon är konfigurerad eller om
/// kortet ännu inte fått någon adress (t.ex. DHCP som inte svarat).
String? _wanAddress(ConfigProvider provider) {
  final cfg = provider.runningConfig ?? provider.candidateConfig;
  for (final iface in cfg?.interfaces ?? const <InterfaceModel>[]) {
    if (!iface.enabled || iface.zone.toUpperCase() != 'WAN') continue;
    final ip = iface.ipv4.trim();
    if (ip.isEmpty) continue;
    return ip.split('/').first;
  }
  return null;
}

/// Overlay som visar skillnaden mellan körande config och kandidaten.
///
/// Grupperas per sektion (Gränssnitt, Policyer, ...) med posten som rubrik
/// och fälten under. Före/efter visas sida vid sida — vid en ändring är det
/// nästan alltid det gamla värdet man behöver för att avgöra om det nya är
/// rätt.
void _showPendingChanges(BuildContext context, ConfigProvider provider) {
  final changes = diffConfigs(
    provider.runningConfig?.toJson(),
    provider.candidateConfig?.toJson(),
  );

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(Icons.difference_outlined, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tr('main.changes_title'),
                style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          if (changes.isNotEmpty)
            Text(trp('main.changes_count', {'n': '${changes.length}'}),
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: changes.isEmpty
            ? Text(tr('main.changes_none'),
                style: TextStyle(color: AppColors.textMuted, fontSize: 12))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final section in _groupBySection(changes).entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Text(
                          (sectionLabels[section.key] ?? section.key).toUpperCase(),
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.6),
                        ),
                      ),
                      ...section.value.map(_changeRow),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 13, color: AppColors.warn),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(tr('main.changes_apply_hint'),
                              style: TextStyle(color: AppColors.warn, fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
      ],
    ),
  );
}

/// Behåller sektionernas ordning från diffen (viktigast först) i stället för
/// att sortera om dem alfabetiskt.
Map<String, List<ConfigChange>> _groupBySection(List<ConfigChange> changes) {
  final grouped = <String, List<ConfigChange>>{};
  for (final c in changes) {
    grouped.putIfAbsent(c.section, () => []).add(c);
  }
  return grouped;
}

Widget _changeRow(ConfigChange c) {
  final (color, label) = switch (c.kind) {
    ChangeKind.added => (AppColors.ok, tr('main.change_added')),
    ChangeKind.removed => (AppColors.danger, tr('main.change_removed')),
    ChangeKind.modified => (AppColors.warn, tr('main.change_modified')),
  };

  return Padding(
    padding: const EdgeInsets.only(bottom: 6, left: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 78,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(children: [
                if (c.item.isNotEmpty)
                  TextSpan(
                      text: c.item,
                      style: TextStyle(
                          color: AppColors.text, fontSize: 11.5, fontWeight: FontWeight.w600)),
                if (c.field.isNotEmpty)
                  TextSpan(
                      text: '${c.item.isEmpty ? '' : ' · '}${fieldLabels[c.field] ?? c.field}',
                      style: TextStyle(color: AppColors.accent, fontSize: 11.5)),
              ])),
              if (c.kind == ChangeKind.modified)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: (c.before?.isEmpty ?? true) ? '—' : c.before,
                        style: TextStyle(
                            color: AppColors.textFaint,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            decoration: TextDecoration.lineThrough)),
                    TextSpan(
                        text: '  →  ',
                        style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
                    TextSpan(
                        text: (c.after?.isEmpty ?? true) ? '—' : c.after,
                        style: TextStyle(
                            color: AppColors.text, fontSize: 11, fontFamily: 'monospace')),
                  ])),
                )
              else if ((c.after ?? c.before ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(c.after ?? c.before ?? '',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace')),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

PopupMenuItem<AppThemeMode> _themeMenuItem(
  AppThemeMode mode,
  String label,
  IconData icon,
  Color accentColor,
) {
  final isSelected = AppTheme.mode == mode;
  return PopupMenuItem<AppThemeMode>(
    value: mode,
    child: Row(
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? accentColor : AppColors.text,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        if (isSelected) ...[
          const SizedBox(width: 6),
          Icon(Icons.check, size: 14, color: accentColor),
        ],
      ],
    ),
  );
}
