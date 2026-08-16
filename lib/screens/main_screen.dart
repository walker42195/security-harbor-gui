import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import 'dashboard_screen.dart';
import 'interfaces_screen.dart';
import 'policies_screen.dart';
import 'objects_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    InterfacesScreen(),
    PoliciesScreen(),
    ObjectsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ConfigProvider>(context);

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
                  child: const Text('FIREWALL OS v0.2.2', style: TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
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
                const SizedBox(width: 12),
                Row(
                  children: const [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('admin', style: TextStyle(color: Colors.grey, fontSize: 11)),
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
                                : 'Misslyckades applicera konfiguration på brandväggen'),
                            backgroundColor: ok ? Colors.teal : Colors.red,
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
                // Navigation Sidebar
                NavigationRail(
                  backgroundColor: const Color(0xFF1E293B),
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: Colors.cyanAccent),
                  selectedLabelTextStyle: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 11),
                  unselectedIconTheme: const IconThemeData(color: Colors.grey),
                  unselectedLabelTextStyle: const TextStyle(color: Colors.grey, fontSize: 11),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.cyanAccent, size: 32),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text('HARBOR', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.router_outlined), selectedIcon: Icon(Icons.router), label: Text('Interfaces')),
                    NavigationRailDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: Text('Policies')),
                    NavigationRailDestination(icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category), label: Text('Objekt')),
                    NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Settings')),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1, color: Colors.white10),
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
