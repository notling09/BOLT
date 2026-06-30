import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/gps_test_screen.dart';

/// Einstiegspunkt der App.
///
/// `async`, weil wir VOR dem Start zwei Systemeinstellungen setzen müssen.
Future<void> main() async {
  // Stellt sicher, dass das Flutter-Framework bereit ist, bevor wir
  // SystemChrome (Systemeinstellungen wie Bildschirm-Ausrichtung) anfassen.
  WidgetsFlutterBinding.ensureInitialized();

  // Konzept S. 11: BOLT ist nur fürs Hochformat (Portrait) gedacht.
  // Wir sperren die App auf "portraitUp" – kein Querformat.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const BoltApp());
}

/// Wurzel-Widget der gesamten App.
/// Stateless, weil sich hier (noch) nichts dynamisch ändert.
class BoltApp extends StatelessWidget {
  const BoltApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOLT',
      debugShowCheckedModeBanner: false,
      // Dark Theme mit gelbem Akzent – passend zu den Mockups (Konzept S. 9–10).
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

/// Vorläufiger Start-Screen (Platzhalter).
/// Wird in einer späteren Phase durch das echte Hauptmenü ersetzt
/// (mit Level/XP, "Sprint starten", letzte Läufe – siehe Mockup S. 9).
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
            // Phase 2: Zugang zum GPS-Test-Screen (vorläufig, bis das echte
            // Hauptmenü mit Bottom-Navigation gebaut ist).
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GpsTestScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.my_location),
              label: const Text('GPS testen'),
            ),
          ],
        ),
      ),
    );
  }
}
