import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:volume_controller/volume_controller.dart';

import '../models/player.dart';
import '../models/run.dart';
import '../models/track.dart';
import '../services/database_service.dart';
import '../services/game_service.dart';
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

class _RaceScreenState extends State<RaceScreen>
    with SingleTickerProviderStateMixin {
  final TimerService _timerService = TimerService();
  final LocationService _locationService = LocationService();
  final DatabaseService _db = DatabaseService.instance;
  final GameService _gameService = GameService();

  /// Spielt das Beep-Startsignal (Asset assets/sounds/beep.wav).
  final AudioPlayer _beepPlayer = AudioPlayer();

  /// True für Fix-Strecken (Vorgaben ohne echte Zielkoordinaten) → beim
  /// Sprinten wird distanz-basiert gestoppt statt per Zielradius.
  bool get _isDistanceMode => widget.track.isTemplate;

  /// Distanz-Modus: Startreferenz (erster GPS-Fix nach dem Start).
  Position? _distStart;

  /// Fehler mit "Erneut versuchen"-Aktion (z. B. Lautstärke aus).
  bool _errorShowRetry = false;

  /// Steuert die Level-up-"Pop"-Animation (Skalierung des Badges).
  late final AnimationController _levelUpController;
  late final Animation<double> _levelUpScale;
  bool _leveledUp = false;

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

  /// Ergebnis nach _finish(): XP, Bestzeit-Flag, aktualisierter Player.
  int _earnedXp = 0;
  bool _isNewBest = false;
  Player? _updatedPlayer;

  /// Gesetzt bei GPS-Problemen → freundlicher Hinweis statt Absturz.
  String? _errorMessage;
  bool _errorShowSettings = false;

  /// Zielradius in Metern. Bewusst grösser als die GPS-Ungenauigkeit
  /// (±3–5 m, Konzept 6.3) – sonst würde die Zielerkennung nie auslösen.
  static const double _targetRadiusMeters = 10.0;

  @override
  void initState() {
    super.initState();
    // 600ms "Pop": elasticOut lässt das Badge kurz über die Endgrösse
    // hinausschiessen und zurückfedern – wirkt wie ein kleiner Triumph.
    _levelUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _levelUpScale = CurvedAnimation(
      parent: _levelUpController,
      curve: Curves.elasticOut,
    );
    _prepare();
  }

  @override
  void dispose() {
    _levelUpController.dispose();
    _displayTicker?.cancel();
    _positionSub?.cancel();
    _timerService.dispose();
    _beepPlayer.dispose();
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

    // Lautstärke prüfen: Der Start wird per Beep signalisiert. Ist der Ton
    // stumm, würde der Nutzer das Signal verpassen → freundlicher Hinweis.
    final volume = await VolumeController.instance.getVolume();
    if (!mounted) return;
    if (volume <= 0.0) {
      _setVolumeError();
      return;
    }

    // GPS + Ton ok → (weiterhin zufälligen) Countdown vorbereiten und starten.
    // Kein sichtbarer Zähler mehr – der Beep signalisiert den Start.
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

    // Beep-Startsignal (Lautstärke wurde in _prepare geprüft) + Haptik.
    _beepPlayer.play(AssetSource('sounds/beep.wav'));
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

    if (_isDistanceMode) {
      // Fix-Strecke: ersten Fix nach dem Start als Referenz merken, dann die
      // gelaufene Luftlinie messen und bei Erreichen der Ziel-Distanz stoppen.
      final start = _distStart ??= pos;
      final run = Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        pos.latitude,
        pos.longitude,
      );
      final remaining = widget.track.distanceMeters - run;
      setState(() => _distanceToTarget = remaining > 0 ? remaining : 0);
      if (run >= widget.track.distanceMeters) _finish();
      return;
    }

    // Echte Strecke: Distanz zum festen Zielpunkt; Zielradius → stoppen.
    final dist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      widget.track.endLat,
      widget.track.endLng,
    );

    setState(() => _distanceToTarget = dist);

    if (dist <= _targetRadiusMeters) {
      _finish();
    }
  }

  /// Ziel erreicht: Zeit stoppen, Lauf + XP speichern, Ergebnis zeigen.
  ///
  /// Nur wenn der Track eine echte DB-id hat (wurde über measure_screen
  /// gespeichert), wird auch ein Run-Eintrag angelegt. Bei der Dummy-Strecke
  /// (id == null, z. B. direkter Start ohne Speichern) wird nichts persistiert.
  void _finish() {
    _timerService.stopStopwatch();
    _displayTicker?.cancel();
    _positionSub?.cancel();
    HapticFeedback.heavyImpact();

    final ms = _timerService.elapsedMs;
    setState(() {
      _finalMs = ms;
      _phase = _Phase.finished;
    });

    // Asynchron speichern – UI ist bereits auf "finished" gesetzt.
    _saveResult(ms);
  }

  Future<void> _saveResult(int durationMs) async {
    final trackId = widget.track.id;
    // Nur speichern, wenn die Strecke eine echte DB-id hat.
    if (trackId == null) return;

    // Bisherige Bestzeit laden, um Bestzeit-Bonus zu prüfen.
    final prevBest = await _db.getBestRunForTrack(trackId);
    final isNewBest =
        prevBest == null || durationMs < prevBest.durationMs;

    // Lauf in sqflite speichern.
    await _db.insertRun(Run(
      trackId: trackId,
      durationMs: durationMs,
      date: DateTime.now(),
    ));

    // Level VOR der XP-Gutschrift merken, um ein Level-up zu erkennen.
    final before = await _gameService.loadPlayer();

    // XP berechnen und Player aktualisieren.
    final player = await _gameService.awardXp(
      distanceMeters: widget.track.distanceMeters,
      durationMs: durationMs,
      isNewBest: isNewBest,
    );

    final earned = _gameService.calculateXp(
      distanceMeters: widget.track.distanceMeters,
      durationMs: durationMs,
      isNewBest: isNewBest,
    );

    final leveledUp = player.level > before.level;

    if (!mounted) return;
    setState(() {
      _earnedXp = earned;
      _isNewBest = isNewBest;
      _updatedPlayer = player;
      _leveledUp = leveledUp;
    });

    // Feier-Animation starten, wenn ein Level-up passiert ist.
    if (leveledUp) {
      HapticFeedback.heavyImpact();
      _levelUpController.forward(from: 0);
    }
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
      _errorShowRetry = false;
      _checkingGps = false;
    });
  }

  /// Hinweis, wenn die Lautstärke stumm ist (Start-Beep wäre nicht hörbar).
  void _setVolumeError() {
    setState(() {
      _errorMessage = 'Bitte Lautstärke aktivieren.\n'
          'Der Start wird per Beep-Ton signalisiert – bei stummem Ton '
          'verpasst du das Signal.';
      _errorShowSettings = false;
      _errorShowRetry = true;
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
      _distStart = null;
      _errorMessage = null;
      _errorShowSettings = false;
      _errorShowRetry = false;
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

  /// Phase 1: Warten auf das Beep-Startsignal (kein sichtbarer Countdown mehr).
  Widget _buildCountdown() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'MACH DICH BEREIT…',
          style: TextStyle(
            fontSize: 22,
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
        const SizedBox(height: 56),
        const Icon(Icons.volume_up, size: 110, color: Colors.amber),
        const SizedBox(height: 32),
        const Text(
          'Beim BEEP geht’s los!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
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
          dist != null
              ? (_isDistanceMode
                  ? 'Noch ${dist.toStringAsFixed(0)} m'
                  : 'Ziel in ${dist.toStringAsFixed(0)} m')
              : 'LÄUFT…',
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

  /// Phase 3: Ziel erreicht – Ergebnis mit XP-Anzeige.
  Widget _buildFinished() {
    final player = _updatedPlayer;
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
        const SizedBox(height: 16),
        // XP + Bestzeit-Anzeige (nur wenn Strecke eine echte id hatte).
        if (player != null) ...[
          if (_isNewBest)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'NEUE BESTZEIT!',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          // Level-up-Feier: "Pop"-Animation (elasticOut, siehe initState).
          if (_leveledUp)
            ScaleTransition(
              scale: _levelUpScale,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_circle_up,
                        color: Colors.black, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'LEVEL UP!  LV.${player.level}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  '+$_earnedXp XP  ·  Level ${player.level}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
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
        if (_errorShowRetry) ...[
          ElevatedButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.refresh),
            label: const Text('ERNEUT VERSUCHEN'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
        ],
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
