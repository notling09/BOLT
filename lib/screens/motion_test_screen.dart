import 'dart:async';

import 'package:flutter/material.dart';

import '../services/motion_service.dart';

/// Test-Screen fuer die Sprint-Start-Erkennung (Teil B, Sensor-Fusion).
///
/// Zeigt die Live-Beschleunigung und meldet, sobald ein Start erkannt wird.
/// Dient zum Ausprobieren/Tunen der Schwelle, bevor man es spaeter in den
/// RaceScreen (automatischer Timer-Start) einbaut.
class MotionTestScreen extends StatefulWidget {
  const MotionTestScreen({super.key});

  @override
  State<MotionTestScreen> createState() => _MotionTestScreenState();
}

class _MotionTestScreenState extends State<MotionTestScreen> {
  final _motion = MotionService();
  StreamSubscription<double>? _sub;

  double _magnitude = 0; // aktuelle Beschleunigungs-Staerke
  double _peak = 0;      // hoechster gemessener Wert (zum Tunen)
  bool _started = false; // gerastet, sobald die Schwelle ueberschritten wurde

  @override
  void initState() {
    super.initState();
    _sub = _motion.accelerationMagnitude().listen((m) {
      if (!mounted) return;
      setState(() {
        _magnitude = m;
        if (m > _peak) _peak = m;
        if (m >= MotionService.startThreshold) _started = true;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _peak = 0;
      _started = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final overThreshold = _magnitude >= MotionService.startThreshold;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SPRINT-START-TEST',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'BESCHLEUNIGUNG (ohne Schwerkraft)',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_magnitude.toStringAsFixed(1)} m/s²',
              style: TextStyle(
                color: overThreshold ? Colors.redAccent : Colors.amber,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_magnitude / (MotionService.startThreshold * 2)).clamp(0, 1),
              minHeight: 10,
              backgroundColor: Colors.grey[850],
              color: overThreshold ? Colors.redAccent : Colors.amber,
            ),
            const SizedBox(height: 8),
            Text(
              'Schwelle: ${MotionService.startThreshold.toStringAsFixed(0)} m/s²'
              '  ·  Peak: ${_peak.toStringAsFixed(1)} m/s²',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 40),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: _started ? Colors.amber : Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _started ? '🏃 START ERKANNT!' : 'Bereit… losspurten',
                  style: TextStyle(
                    color: _started ? Colors.black : Colors.white54,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('ZURÜCKSETZEN'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber,
                side: const BorderSide(color: Colors.amber),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
