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
          // Loading & Status Banner
          if (provider.isLoading && provider.statusMessage != null)
            Container(
              color: Colors.cyan[900],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      provider.statusMessage!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Safe Apply Status Bar (Syns när konfigurationen är applicerad i unconfirmed-läge)
          if (provider.applyStatus == ApplyStatus.unconfirmed)
            Container(
              color: Colors.amber[900],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ÄNDRINGAR APPLICERADE PÅ BRANDVÄGGEN (SAFE APPLY): Automatisk rollback sker om ${provider.rollbackSecondsRemaining} sekunder om du inte bekräftar!',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('BEKRÄFTA (COMMIT)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
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
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('RULLA TILLBAKA'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
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
              color: Colors.blueGrey[900],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: Colors.cyanAccent),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Du har obekräftade ändringar redo att testas på brandväggen.',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('APPLICERA (SAFE APPLY)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
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
                  selectedLabelTextStyle: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                  unselectedIconTheme: const IconThemeData(color: Colors.grey),
                  unselectedLabelTextStyle: const TextStyle(color: Colors.grey),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.cyanAccent, size: 36),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('HARBOR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Dashboard')),
                    NavigationRailDestination(icon: Icon(Icons.router), label: Text('Interfaces')),
                    NavigationRailDestination(icon: Icon(Icons.shield), label: Text('Policies')),
                    NavigationRailDestination(icon: Icon(Icons.category), label: Text('Objekt')),
                    NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Settings')),
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
