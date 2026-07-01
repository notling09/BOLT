import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'main_shell.dart';

/// Start-Ladescreen (~3 s): zeigt einen rennenden Mann (Lottie), damit im
/// Hintergrund Karte & Co. laden können, und wechselt danach ins Hauptmenü.
///
/// Fehlt die Lottie-Datei (assets/lottie/runner.json) noch, zeigt der
/// errorBuilder einen Fallback (Logo) – die App startet trotzdem normal.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Nach 3 Sekunden ins Hauptmenü wechseln.
    _timer = Timer(const Duration(seconds: 3), _goHome);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 220,
              child: Lottie.asset(
                'assets/lottie/runner.json',
                repeat: true,
                errorBuilder: (_, _, _) => _buildFallback(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'B.O.L.T.',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: Colors.amber,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Fallback, solange keine runner.json vorhanden ist.
  Widget _buildFallback() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.directions_run, size: 96, color: Colors.amber),
        SizedBox(height: 16),
        CircularProgressIndicator(color: Colors.amber),
      ],
    );
  }
}
