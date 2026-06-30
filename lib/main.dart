import 'package:flutter/material.dart';

void main() {
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
      theme: ThemeData(
        // Gelb passt zum "Blitz"-Thema (Bolt = Blitz) und zur Energie der App.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

/// Vorläufiger Start-Screen (Platzhalter).
/// Wird in einer späteren Phase durch das echte Hauptmenü ersetzt.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.bolt, size: 96, color: Colors.amber),
            Text(
              'B.O.L.T.',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Beat. Outrun. Level-up. Track.'),
          ],
        ),
      ),
    );
  }
}
