import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/track.dart';
import '../services/location_service.dart';
import '../services/timer_service.dart';

/// Die Phasen des Rennens (UC2/UC3, User-Stories 2 & 3).
enum _Phase {
  countdown, // variabler Countdown ("MACH DICH BEREIT…")
  running,   // Stoppuhr läuft, GPS prüft live auf Zielerreichung
  finished,  // Ziel erreicht – Ergebnis wird angezeigt
}

/// Screen "Sprint" – Phase 4 (Timer) + Phase 5 (Zielerkennung).
///
/// Ablauf: GPS prüfen → variabler Countdown → Startsignal → Zeit läuft →
/// sobald die Live-Position im Zielradius liegt, stoppt die Zeit AUTOMATISCH
/// (Special Feature, User-Story 3). Noch keine Speicherung/XP (Phase 6).
class RaceScreen extends StatefulWidget {
  /// Die abzusprintende Strecke (Ziel = endLat/endLng).
  final Track track;

  const RaceScreen({super.key, required this.track});

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  final TimerService _timerService = TimerService();
  final LocationService _locationService = LocationService();

  /// Live-Abo der GPS-Positionen während des Laufs.
  StreamSubscription<Position>? _positionSub;

  /// Anzeige-Ticker (~33×/Sek.). Die Zeit selbst kommt aus der Stopwatch.
  Timer? _displayTicker;

  _Phase _phase = _Phase.countdown;
  bool _checkingGps = true; // beim Eintritt: GPS/Berechtigung prüfen
  int _countdownValue = 0;
  int _elapsedMs = 0;
  int _finalMs = 0;
  double? _distanceToTarget; // aktuelle Distanz zum Ziel (Live-Feedback)

  /// Gesetzt bei GPS-Problemen → freundlicher Hinweis statt Absturz.
  String? _errorMessage;
  bool _errorShowSettings = false;

  /// Zielradius in Metern. Bewusst grösser als die GPS-Ungenauigkeit
  /// (±3–5 m, Konzept 6.3) – sonst würde die Zielerkennung nie auslösen.
  static const double _targetRadiusMeters = 10.0;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _displayTicker?.cancel();
    _positionSub?.cancel();
    _timerService.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Ablauf-Logik
  // ---------------------------------------------------------------------------

  /// Schritt 0: GPS-Dienst + Berechtigung sicherstellen, dann Countdown starten.
  Future<void> _prepare() async {
    final result = await _locationService.getCurrentPosition();
    if (!mounted) return;

    if (!result.isSuccess) {
      _setError(result.status);
      return;
    }

    // GPS ok → Countdown vorbereiten und starten.
    _countdownValue = _timerService.randomCountdownSeconds();
    setState(() => _checkingGps = false);

    _timerService.startCountdown(
      seconds: _countdownValue,
      onTick: (remaining) {
        if (!mounted) return;
        setState(() => _countdownValue = remaining);
      },
      onFinished: _onGo,
    );
  }

  /// Beim "GO": Startsignal geben, Stoppuhr starten und GPS-Zielerkennung starten.
  void _onGo() {
    if (!mounted) return;

    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    _timerService.startStopwatch();
    setState(() => _phase = _Phase.running);

    // UI-Auffrischer für die laufende Zeit.
    _displayTicker = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!mounted) return;
      setState(() => _elapsedMs = _timerService.elapsedMs);
    });

    // Live-GPS: bei jeder Position Distanz zum Ziel prüfen.
    _positionSub = _locationService.positionStream().listen(
      _onPosition,
      onError: (_) => _onSignalLost(),
    );
  }

  /// Wird bei jeder neuen GPS-Position aufgerufen.
  void _onPosition(Position pos) {
    if (!mounted || _phase != _Phase.running) return;

    final dist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      widget.track.endLat,
      widget.track.endLng,
    );

    setState(() => _distanceToTarget = dist);

    // Zielradius erreicht → automatisch stoppen.
    if (dist <= _targetRadiusMeters) {
      _finish();
    }
  }

  /// Ziel erreicht: alles stoppen, finale Zeit sichern, Ergebnis zeigen.
  void _finish() {
    _timerService.stopStopwatch();
    _displayTicker?.cancel();
    _positionSub?.cancel();
    HapticFeedback.heavyImpact();

    setState(() {
      _finalMs = _timerService.elapsedMs;
      _phase = _Phase.finished;
    });
  }

  /// GPS-Signal während des Laufs verloren → Lauf ungültig.
  void _onSignalLost() {
    if (!mounted) return;
    _timerService.stopStopwatch();
    _displayTicker?.cancel();
    _positionSub?.cancel();
    setState(() {
      _errorMessage = 'GPS-Signal verloren.\nDer Lauf ist ungültig – bitte erneut versuchen.';
      _errorShowSettings = false;
    });
  }

  /// Übersetzt einen LocationStatus in eine freundliche Meldung.
  void _setError(LocationStatus status) {
    final (String msg, bool settings) = switch (status) {
      LocationStatus.serviceDisabled => (
        'GPS ist ausgeschaltet.\nBitte in den Geräte-Einstellungen aktivieren.',
        false,
      ),
      LocationStatus.permissionDenied => (
        'Standort-Berechtigung verweigert.\nOhne Standort kann der Sprint nicht gemessen werden.',
        false,
      ),
      LocationStatus.permissionDeniedForever => (
        'Berechtigung dauerhaft verweigert.\nBitte in den App-Einstellungen freigeben.',
        true,
      ),
      _ => ('Unbekannter GPS-Fehler.', false),
    };
    setState(() {
      _errorMessage = msg;
      _errorShowSettings = settings;
      _checkingGps = false;
    });
  }

  /// Sprint abbrechen: alles stoppen, nichts behalten, Screen verlassen.
  void _abort() {
    _displayTicker?.cancel();
    _positionSub?.cancel();
    _timerService.cancelCountdown();
    _timerService.stopStopwatch();
    Navigator.of(context).pop();
  }

  /// Nochmal: kompletten Ablauf von vorne starten.
  void _restart() {
    _displayTicker?.cancel();
    _positionSub?.cancel();
    setState(() {
      _phase = _Phase.countdown;
      _checkingGps = true;
      _countdownValue = 0;
      _elapsedMs = 0;
      _finalMs = 0;
      _distanceToTarget = null;
      _errorMessage = null;
      _errorShowSettings = false;
    });
    _prepare();
  }

  /// Formatiert Millisekunden als MM:SS.hh.
  String _formatTime(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final hundredths = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$minutes:$seconds.$hundredths';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) return _buildError();
    if (_checkingGps) return _buildPreparing();

    return switch (_phase) {
      _Phase.countdown => _buildCountdown(),
      _Phase.running => _buildRunning(),
      _Phase.finished => _buildFinished(),
    };
  }

  /// GPS-Vorbereitung (kurz vor dem Countdown).
  Widget _buildPreparing() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: Colors.amber),
        SizedBox(height: 24),
        Text('GPS wird vorbereitet …'),
      ],
    );
  }

  /// Phase 1: grosser Countdown.
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

  /// Phase 2: laufende Zeit + Live-Distanz zum Ziel + Abbrechen.
  Widget _buildRunning() {
    final dist = _distanceToTarget;
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
        Text(
          dist != null ? 'Ziel in ${dist.toStringAsFixed(0)} m' : 'LÄUFT…',
          style: const TextStyle(color: Colors.white38, letterSpacing: 2),
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

  /// Phase 3: Ziel erreicht – Ergebnis.
  Widget _buildFinished() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.flag_circle, size: 72, color: Colors.amber),
        const SizedBox(height: 16),
        const Text(
          'ZIEL!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _formatTime(_finalMs),
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.track.name} · ${widget.track.distanceMeters.toStringAsFixed(0)} m',
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh),
              label: const Text('NOCHMAL'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber,
                side: const BorderSide(color: Colors.amber),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check),
              label: const Text('FERTIG'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Freundlicher Fehler-Hinweis (GPS aus / keine Berechtigung / Signal verloren).
  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.gps_off, size: 72, color: Colors.amber),
        const SizedBox(height: 24),
        Text(
          _errorMessage ?? 'GPS-Fehler.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (_errorShowSettings)
          TextButton(
            onPressed: _locationService.openAppSettings,
            child: const Text(
              'App-Einstellungen öffnen',
              style: TextStyle(color: Colors.amber),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('ZURÜCK'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.amber,
            side: const BorderSide(color: Colors.amber),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ],
    );
  }
}
