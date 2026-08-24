import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

import 'tools_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

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
      const NavigationRailDestination(icon: Icon(Icons.build_circle_outlined), selectedIcon: Icon(Icons.build_circle), label: Text('Verktyg')),
      const NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
    ];
    if (_selectedIndex >= screens.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Slank Huvud-topplist (Top Header Bar) harmoniserad med Slate-temat
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'SECURITY HARBOR',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(width: 6),
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
                if (isHostMode) ...[
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: provider.isAuthenticated ? Colors.tealAccent.withValues(alpha: 0.4) : Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
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
                      Text(
                        provider.isAuthenticated ? 'ONLINE (${provider.api.baseUrl})' : 'EJ ANSLUTEN',
                        style: TextStyle(
                          color: provider.isAuthenticated ? Colors.tealAccent : Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (provider.isAuthenticated)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
                    tooltip: 'Uppdatera allt (hämta om status och konfiguration)',
                    onPressed: provider.isLoading ? null : () => provider.refreshAll(),
                  ),
                if (provider.isAuthenticated)
                  IconButton(
                    icon: const Icon(Icons.logout, size: 16, color: Colors.white54),
                    tooltip: 'Logga ut',
                    onPressed: () => provider.logout(),
                  ),
                const SizedBox(width: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(provider.api.username ?? '—', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
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

          // Safe Apply Status Bar (Syns när konfigurationen är applicerad i unconfirmed-läge)
          if (provider.applyStatus == ApplyStatus.unconfirmed)
            Container(
              color: const Color(0xFF9A3412),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.amberAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ÄNDRINGAR APPLICERADE PÅ BRANDVÄGGEN (SAFE APPLY): Automatisk rollback sker om ${provider.rollbackSecondsRemaining} sekunder om du inte bekräftar!',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
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
                  const SizedBox(width: 8),
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
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: Colors.cyanAccent, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Du har obekräftade ändringar redo att testas på brandväggen.',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
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
                  const SizedBox(width: 8),
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
            ),

          Expanded(
            child: Row(
              children: [
                // Navigation Sidebar. VisualDensity.compact + mindre
                // ikoner/etiketter/leading-logga krymper var post radikalt
                // (upptäckt 2026-08-24: med standardstorlek och 13
                // menyposter + leading-logga tog listan över 1000px höjd,
                // vilket inte fick plats under 1080px hög skärm minus
                // topplist/webbläsarchrome — de sista posterna klipptes
                // bort utan att NavigationRail scrollar). SingleChildScrollView
                // är dessutom ett strukturellt skyddsnät: om listan ändå
                // skulle bli för hög (fler menyposter i framtiden, eller en
                // ännu lägre skärm) går den att scrolla i stället för att
                // klippas/overflowa tyst.
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
                Expanded(child: screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
