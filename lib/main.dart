import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/gps_test_screen.dart';
import 'screens/measure_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/track_list_screen.dart';

/// Einstiegspunkt der App.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Konzept S. 11: BOLT ist nur fürs Hochformat (Portrait) gedacht.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const BoltApp());
}

/// Wurzel-Widget der gesamten App.
class BoltApp extends StatelessWidget {
  const BoltApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOLT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Vorläufiger HomeScreen – wird in Phase 7 durch das Mockup-Hauptmenü ersetzt.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt, size: 96, color: Colors.amber),
            const Text(
              'B.O.L.T.',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'BREAK OLD LIMITS TODAY',
              style: TextStyle(letterSpacing: 2),
            ),
            const SizedBox(height: 32),
            _btn(
              context,
              icon: Icons.straighten,
              label: 'Strecke vermessen',
              screen: const MeasureScreen(),
            ),
            const SizedBox(height: 12),
            _btn(
              context,
              icon: Icons.play_arrow,
              label: 'Sprint starten',
              screen: const TrackListScreen(),
            ),
            const SizedBox(height: 12),
            _btn(
              context,
              icon: Icons.bar_chart,
              label: 'Statistik',
              screen: const StatsScreen(),
            ),
            const SizedBox(height: 12),
            _btn(
              context,
              icon: Icons.my_location,
              label: 'GPS testen',
              screen: const GpsTestScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget screen,
  }) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      ),
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        minimumSize: const Size(220, 48),
      ),
    );
  }
}
