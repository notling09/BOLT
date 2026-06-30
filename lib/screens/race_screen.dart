import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/track.dart';
import '../services/timer_service.dart';

/// Die zwei Phasen des Rennens (UC2 / User-Story 2).
enum _Phase {
  countdown, // variabler Countdown läuft ("MACH DICH BEREIT…")
  running,   // Stoppuhr läuft, Zeit wird gross angezeigt
}

/// Screen "Sprint starten" – Phase 4 (Timer-Logik).
///
/// Variabler Countdown (3–7 s) → Startsignal → laufende Zeitmessung.
/// Die automatische Zielerkennung (GPS) kommt erst in Phase 5; hier stoppt
/// die Zeit noch nicht von selbst, nur "Abbrechen" verwirft den Lauf.
class RaceScreen extends StatefulWidget {
  /// Die abzusprintende Strecke. Vorerst eine Dummy-Strecke vom HomeScreen,
  /// da Strecken noch nicht persistiert werden.
  final Track track;

  const RaceScreen({super.key, required this.track});

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  final TimerService _timerService = TimerService();

  /// Anzeige-Ticker: aktualisiert ~33×/Sek. die laufende Zeit. Die ZEIT selbst
  /// kommt aber immer aus der Stopwatch (TimerService), nicht aus diesem Timer.
  Timer? _displayTicker;

  _Phase _phase = _Phase.countdown;
  int _countdownValue = 0; // verbleibende Sekunden im Countdown
  int _elapsedMs = 0;      // aktuelle Sprintzeit in ms

  @override
  void initState() {
    super.initState();
    // Startwert direkt setzen (kein setState in initState nötig).
    _countdownValue = _timerService.randomCountdownSeconds();
    _timerService.startCountdown(
      seconds: _countdownValue,
      onTick: (remaining) {
        if (!mounted) return;
        setState(() => _countdownValue = remaining);
      },
      onFinished: _onGo,
    );
  }

  @override
  void dispose() {
    _displayTicker?.cancel();
    _timerService.dispose();
    super.dispose();
  }

  /// Wird beim "GO" aufgerufen: Startsignal geben und Zeitmessung beginnen.
  void _onGo() {
    if (!mounted) return;

    // Klares Startsignal: Ton + spürbarer Ruck (Ton allein ist oft zu leise).
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    _timerService.startStopwatch();
    setState(() => _phase = _Phase.running);

    // UI-Auffrischer (~30 ms) für eine flüssige Hundertstel-Anzeige.
    _displayTicker = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!mounted) return;
      setState(() => _elapsedMs = _timerService.elapsedMs);
    });
  }

  /// Sprint abbrechen: alles stoppen, nichts speichern, Screen verlassen.
  void _abort() {
    _displayTicker?.cancel();
    _timerService.cancelCountdown();
    _timerService.stopStopwatch();
    Navigator.of(context).pop();
  }

  /// Formatiert Millisekunden als MM:SS.hh (Minuten:Sekunden.Hundertstel).
  String _formatTime(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final hundredths = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$hundredths';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _phase == _Phase.countdown
              ? _buildCountdown()
              : _buildRunning(),
        ),
      ),
    );
  }

  /// Phase 1: grosser Countdown-Zähler.
  Widget _buildCountdown() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'MACH DICH BEREIT…',
          style: TextStyle(
            fontSize: 20,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.track.name,
          style: const TextStyle(color: Colors.white38, fontSize: 14),
        ),
        const SizedBox(height: 40),
        Text(
          '$_countdownValue',
          style: const TextStyle(
            fontSize: 160,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          'Zufälliger Start – nicht vorhersehbar.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Phase 2: laufende Zeit gross + Abbrechen.
  Widget _buildRunning() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.track.name.toUpperCase(),
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        // Monospace-Stil über tabularFigures, damit die Zahl beim Hochzählen
        // nicht "wackelt".
        Text(
          _formatTime(_elapsedMs),
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'LÄUFT…',
          style: TextStyle(color: Colors.white38, letterSpacing: 2),
        ),
        const SizedBox(height: 64),
        OutlinedButton.icon(
          onPressed: _abort,
          icon: const Icon(Icons.close),
          label: const Text('ABBRECHEN'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
        ),
      ],
    );
  }
}
