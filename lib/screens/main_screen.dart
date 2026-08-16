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
        children: [
          // Safe Apply Status Bar (Syns om konfigurationen har obekräftade ändringar)
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
                      'ÄNDRINGAR APPLICERADE (SAFE APPLY): Automatisk rollback sker om ${provider.rollbackSecondsRemaining} sekunder om du inte bekräftar!',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                    onPressed: () => provider.confirmChanges(),
                    child: const Text('BEKRÄFTA (COMMIT)'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                    onPressed: () => provider.rollbackChanges(),
                    child: const Text('RULLA TILLBAKA'),
                  ),
                ],
              ),
            )
          else if (provider.candidateConfig != null &&
              provider.runningConfig != null &&
              provider.candidateConfig!.revision > provider.runningConfig!.revision)
            Container(
              color: Colors.blueGrey[900],
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: Colors.cyanAccent),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Du har kandidat-ändringar redo att testas.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                    onPressed: () => provider.applyChanges(),
                    child: const Text('APPLICERA (SAFE APPLY)'),
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
