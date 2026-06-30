import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'stats_screen.dart';
import 'track_list_screen.dart';

/// Wurzel-Screen mit Bottom-Navigation (Konzept Kap. 5.5): Home · Sprint · Statistik.
///
/// Hält den aktiven Tab-Index und zeigt die passende Seite. Die aktive Seite
/// wird bei jedem Tab-Wechsel neu gebaut, damit sie frische Daten lädt
/// (z. B. aktualisierte XP nach einem Sprint).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goToTab(int index) => setState(() => _index = index);

  Widget _currentPage() {
    return switch (_index) {
      1 => const TrackListScreen(),
      2 => const StatsScreen(),
      _ => HomeScreen(onGoToTab: _goToTab),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        backgroundColor: Colors.grey[900],
        indicatorColor: Colors.amber.withValues(alpha: 0.25),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Colors.amber),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bolt_outlined),
            selectedIcon: Icon(Icons.bolt, color: Colors.amber),
            label: 'Sprint',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: Colors.amber),
            label: 'Statistik',
          ),
        ],
      ),
    );
  }
}
