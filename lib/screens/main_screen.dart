import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'security_events_screen.dart';
import 'services_screen.dart';

import 'tools_screen.dart';

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
  int _selectedIndex = 0;
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
      const InterfacesScreen(),
      const RoutesScreen(),
      const PoliciesScreen(),
      const ObjectsScreen(),
      if (!isHostMode) const SniRoutesScreen(),
      if (!isHostMode) const VpnScreen(),
      if (!isHostMode) const DnsScreen(),
      if (!isHostMode) const DnsDevicesScreen(),
      if (!isHostMode) const DhcpScreen(),
      const ConnectionsScreen(),
      if (!isHostMode) const SecurityEventsScreen(),
      const ServicesScreen(),
      const ToolsScreen(),
      const SettingsScreen(),
    ];
    final destinations = <NavigationRailDestination>[
      const NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
      const NavigationRailDestination(icon: Icon(Icons.router_outlined), selectedIcon: Icon(Icons.router), label: Text('Interfaces')),
      const NavigationRailDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: Text('Routing')),
      const NavigationRailDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: Text('Policies')),
      const NavigationRailDestination(icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category), label: Text('Objekt')),
      if (!isHostMode) const NavigationRailDestination(icon: Icon(Icons.alt_route_outlined), selectedIcon: Icon(Icons.alt_route), label: Text('SNI')),
      if (!isHostMode) const NavigationRailDestination(icon: Icon(Icons.vpn_lock_outlined), selectedIcon: Icon(Icons.vpn_lock), label: Text('VPN')),
      if (!isHostMode) const NavigationRailDestination(icon: Icon(Icons.dns_outlined), selectedIcon: Icon(Icons.dns), label: Text('DNS')),
      if (!isHostMode) const NavigationRailDestination(icon: Icon(Icons.devices_outlined), selectedIcon: Icon(Icons.devices), label: Text('DNS-enheter')),
      if (!isHostMode) const NavigationRailDestination(icon: Icon(Icons.devices_other_outlined), selectedIcon: Icon(Icons.devices_other), label: Text('DHCP')),
      const NavigationRailDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: Text('Loggning')),
      if (!isHostMode) const NavigationRailDestination(icon: Icon(Icons.gpp_maybe_outlined), selectedIcon: Icon(Icons.gpp_maybe), label: Text('IDS')),
      const NavigationRailDestination(icon: Icon(Icons.miscellaneous_services_outlined), selectedIcon: Icon(Icons.miscellaneous_services), label: Text('Tjänster')),
      const NavigationRailDestination(icon: Icon(Icons.build_circle_outlined), selectedIcon: Icon(Icons.build_circle), label: Text('Verktyg')),
      const NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
    ];
    if (_selectedIndex >= screens.length) {
      _selectedIndex = 0;
    }

    return LayoutBuilder(builder: (context, outerConstraints) {
      final isNarrow = outerConstraints.maxWidth < _kNarrowBreakpoint;
      return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0F172A),
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
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
            ),
            child: Row(
              children: [
                if (isNarrow) ...[
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Meny',
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  const Icon(Icons.shield, color: Colors.cyanAccent, size: 18),
                  const SizedBox(width: 8),
                ],
                // Flexible+ellipsis i stället för en obegränsad Text: på en
                // smal skärm fick titeln + badgar tidigare bara skjuta över
                // varandra (osynligt overflow) i stället för att synligt
                // krympa/klippas.
                if (!isNarrow)
                  const Text(
                    'SECURITY HARBOR',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                if (!isNarrow) const SizedBox(width: 6),
                if (!isNarrow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'FIREWALL OS ${provider.systemStatus?['version'] ?? '—'}',
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (!isNarrow && isHostMode) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'LÄGE: VÄRDDATOR',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold),
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
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: provider.isAuthenticated ? Colors.tealAccent.withValues(alpha: 0.4) : Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: provider.isAuthenticated ? Colors.tealAccent : Colors.amber,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            provider.isAuthenticated ? (isNarrow ? 'ONLINE' : 'ONLINE (${provider.api.baseUrl})') : 'EJ ANSLUTEN',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: provider.isAuthenticated ? Colors.tealAccent : Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (provider.isAuthenticated)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Uppdatera allt (hämta om status och konfiguration)',
                    onPressed: provider.isLoading ? null : () => provider.refreshAll(),
                  ),
                if (provider.isAuthenticated) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 16, color: Colors.white54),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Logga ut',
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
                      const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(provider.api.username ?? '—', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Tjänstelarm — visas på ALLA vyer (inte bara Tjänster-fliken) så
          // en administratör märker det direkt, oavsett var de står.
          if (_failedServices.isNotEmpty)
            Container(
              color: const Color(0xFF7F1D1D),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _failedServices.length == 1
                            ? 'Tjänsten "${_failedServices.first.name}" har fastnat i ett fel-läge (failed).'
                            : '${_failedServices.length} tjänster har fastnat i ett fel-läge (failed): ${_failedServices.map((s) => s.name).join(", ")}.',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.build_circle_outlined, size: 14),
                    label: const Text('Visa Tjänster', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
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
              color: const Color(0xFF0284C7),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      provider.statusMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
              color: const Color(0xFF9A3412),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.amberAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ÄNDRINGAR APPLICERADE PÅ BRANDVÄGGEN (SAFE APPLY): Automatisk rollback sker om ${provider.rollbackSecondsRemaining} sekunder om du inte bekräftar!',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                        label: const Text('BEKRÄFTA (COMMIT)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                        onPressed: () async {
                          final ok = await provider.confirmChanges();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? 'Konfiguration bekräftad och committad till running.json!' : 'Misslyckades bekräfta'),
                                backgroundColor: ok ? Colors.green : Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.undo, size: 14),
                        label: const Text('RULLA TILLBAKA', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                        onPressed: () async {
                          await provider.rollbackChanges();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Konfigurationen återställd till senast säkra tillstånd.'),
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
              color: const Color(0xFF1E293B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.cyanAccent, width: 1)),
              ),
              // Se kommentaren på Safe Apply-bannern ovan — samma
              // Column(text ovanför, Wrap(knappar) under) i stället för allt
              // i en Row, av samma anledning (2026-08-24).
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.edit_note, color: Colors.cyanAccent, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Du har obekräftade ändringar redo att testas på brandväggen.',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
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
                        label: const Text('ÅNGRA ÄNDRINGAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E293B),
                              title: const Text('Ångra ändringar?', style: TextStyle(color: Colors.white, fontSize: 14)),
                              content: const Text(
                                'Alla ändringar du gjort sedan senaste applicering kastas bort och '
                                'konfigurationen återställs till den som just nu kör på brandväggen. '
                                'Detta går inte att ångra.',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Avbryt')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                  onPressed: () => Navigator.pop(dctx, true),
                                  child: const Text('Ångra ändringar'),
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
                                    ? 'Ändringarna återställdes till körande konfiguration.'
                                    : (provider.errorMessage ?? 'Kunde inte återställa ändringarna.')),
                                backgroundColor: ok ? Colors.teal : Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow, size: 14),
                        label: const Text('APPLICERA (SAFE APPLY)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                        onPressed: () async {
                          final ok = await provider.applyChanges();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Ändringar applicerade på brandväggen! Bekräfta (Commit) inom 30s för att behålla dem.'
                                    // Visar servers faktiska felmeddelande (t.ex. ett
                                    // valideringsfel om en policys zon inte matchar
                                    // något gränssnitt) istället för en generisk text
                                    // utan detaljer - upptäckt 2026-08-19 att den
                                    // gamla generiska texten gjorde det omöjligt att
                                    // förstå VARFÖR Apply misslyckades.
                                    : (provider.errorMessage ?? 'Misslyckades applicera konfiguration på brandväggen')),
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
                            backgroundColor: const Color(0xFF1E293B),
                            selectedIndex: _selectedIndex,
                            onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                            labelType: NavigationRailLabelType.all,
                            minWidth: 56,
                            selectedIconTheme: const IconThemeData(color: Colors.cyanAccent, size: 18),
                            selectedLabelTextStyle: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 9),
                            unselectedIconTheme: const IconThemeData(color: Colors.grey, size: 18),
                            unselectedLabelTextStyle: const TextStyle(color: Colors.grey, fontSize: 9),
                            leading: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: Image.asset(
                                      'assets/logo.png',
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(Icons.shield, color: Colors.cyanAccent, size: 22),
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
                  const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),
                ],
                Expanded(child: screens[_selectedIndex]),
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
      backgroundColor: const Color(0xFF1E293B),
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
                      errorBuilder: (_, _, _) => const Icon(Icons.shield, color: Colors.cyanAccent, size: 26),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('SECURITY HARBOR', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
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
                      style: TextStyle(color: selected ? Colors.cyanAccent : Colors.white, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13),
                      child: dest.label,
                    ),
                    iconColor: selected ? Colors.cyanAccent : Colors.grey,
                    selected: selected,
                    selectedTileColor: Colors.cyanAccent.withValues(alpha: 0.08),
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
