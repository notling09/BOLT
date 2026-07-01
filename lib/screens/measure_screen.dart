import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/track.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import 'motion_test_screen.dart';
import 'race_screen.dart';

/// Die drei Schritte der Streckenvermessung (UC1 / User-Story 1).
enum _Step {
  idle,     // noch kein Startpunkt
  startSet, // Startpunkt gesetzt, Ziel fehlt noch
  done,     // beide Punkte gesetzt, Distanz berechnet
}

/// Screen "Strecke vermessen" – Phase 3 (UC1) + Phase 6 (Persistenz)
/// + Genauigkeits-Features (Live-Distanz, stabile Erfassung, Sensor-Fusion).
///
/// Ablauf: Start setzen → (live mitzaehlen) → Ziel setzen → Distanz anzeigen
/// (GPS + Schritte kombiniert) → SPEICHERN → Sprint.
/// Die Strecke wird mit [DatabaseService.insertTrack] gespeichert und bekommt
/// dabei eine id, die der RaceScreen für das Speichern des Laufs braucht.
class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  final _locationService = LocationService();
  final _db = DatabaseService.instance;
  final _nameController = TextEditingController();

  /// Steuert die Karte (Kamera auf Start/Ziel schwenken).
  final _mapController = MapController();

  /// Zuletzt bekannte aktuelle Position (für den Live-Marker auf der Karte).
  LatLng? _currentLatLng;

  _Step _step = _Step.idle;
  bool _isLoading = false;
  bool _isSaving = false;

  Position? _startPos;
  Position? _endPos;
  double? _distance;

  /// Gesetzt nach erfolgreichem INSERT – enthält dann eine echte DB-id.
  Track? _savedTrack;

  /// Gesetzt, wenn ein GPS-Aufruf fehlschlug (serviceDisabled / permissionDenied…).
  LocationStatus? _gpsError;

  /// Unter dieser Distanz warnen wir vor GPS-Rauschen (±3–5 m Ungenauigkeit).
  static const double _minDistanceMeters = 10.0;

  /// Live mitlaufende Luftlinie Start -> aktuelle Position (Variante A).
  /// Nur waehrend des Messens (Step.startSet) aktiv.
  double? _liveDistance;

  /// Abo des GPS-Positions-Stroms. Muss beim Verlassen/Reset gekuendigt werden,
  /// sonst laeuft das GPS im Hintergrund weiter (Akku!).
  StreamSubscription<Position>? _posSub;

  /// Genauigkeit (±Meter) der zuletzt empfangenen Position. Punkt 1: anzeigen.
  double? _currentAccuracy;

  /// Punkt 3 (Ausreisser-Filter): Live-Positionen mit schlechterer Genauigkeit
  /// als dieser Wert werden NICHT in die Distanz eingerechnet.
  static const double _maxAccuracyMeters = 20.0;

  // --- Stabile Punkterfassung (warten, bis genau – dann mitteln) ---

  /// Eine Messung gilt als "brauchbar", wenn ihre Genauigkeit <= diesem Wert ist.
  /// Bewusst lockerer (mittel statt streng gut), weil der Schrittzaehler als
  /// zweite, GPS-unabhaengige Quelle ein mittelmaessiges GPS auffaengt.
  static const double _goodAccuracyMeters = 20.0;

  /// So viele GUTE Messungen sammeln und mitteln wir pro Punkt.
  static const int _requiredSamples = 5;

  /// Nach so vielen Sekunden ohne genug gute Messungen brechen wir ehrlich ab.
  static const int _captureTimeoutSeconds = 25;

  /// True, waehrend wir auf ein stabiles Signal warten/sammeln.
  bool _isCapturing = false;

  /// Anzahl bisher gesammelter guter Messungen (fuer die Fortschrittsanzeige).
  int _captureCount = 0;

  /// Laufende Erfassung – muss bei dispose/reset beendet werden.
  StreamSubscription<Position>? _captureSub;
  Timer? _captureTimer;

  // --- Pedometer (zweite, GPS-unabhaengige Messquelle) ---

  /// Schrittlaenge in Metern – zur Laufzeit anpassbar (Default ~Gehen).
  /// Spaeter koennte man sie ueber eine bekannte Strecke automatisch kalibrieren.
  double _strideMeters = 0.70;

  /// Abo des Schrittzaehler-Sensors.
  StreamSubscription<StepCount>? _stepSub;

  /// Letzter bekannter (kumulierter) Schrittzaehler-Stand seit Geraetestart.
  int? _currentSteps;

  /// Schrittzaehler-Stand beim Setzen des Startpunkts (Basislinie).
  int? _stepBaseline;

  /// Schritte vom Start bis zum Ziel (fuer die Anzeige im done-Schritt).
  /// Die Distanz daraus wird live berechnet (_stepsWalked * _strideMeters),
  /// damit eine geaenderte Schrittlaenge sofort wirkt.
  int? _stepsWalked;

  @override
  void initState() {
    super.initState();
    _initPedometer();
  }

  /// Fragt die Aktivitaets-Berechtigung an und abonniert den Schrittzaehler.
  /// Schlaegt das fehl (kein Sensor / keine Erlaubnis), bleibt einfach GPS allein.
  Future<void> _initPedometer() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted || !mounted) return;
    _stepSub = Pedometer.stepCountStream.listen(
      (event) {
        if (!mounted) return;
        _currentSteps = event.steps; // kumuliert seit Geraetestart
      },
      onError: (_) {/* Schrittzaehler nicht verfuegbar – still ignorieren */},
    );
  }

  @override
  void dispose() {
    _posSub?.cancel(); // GPS-Strom stoppen, sonst laeuft er im Hintergrund weiter.
    _captureSub?.cancel();
    _captureTimer?.cancel();
    _stepSub?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Aktionen
  // ---------------------------------------------------------------------------

  Future<void> _setStart() async {
    setState(() {
      _isLoading = true;
      _gpsError = null;
    });

    // 1. Berechtigung/GPS-Dienst einmalig pruefen (mit Fehlerbehandlung).
    final perm = await _locationService.getCurrentPosition();
    if (!mounted) return;
    if (!perm.isSuccess) {
      setState(() {
        _gpsError = perm.status;
        _isLoading = false;
      });
      return;
    }

    // 2. Stabilen Startpunkt erfassen: warten, bis genug GUTE Messungen da sind.
    setState(() {
      _isLoading = false;
      _isCapturing = true;
      _captureCount = 0;
    });
    final start = await _captureStablePosition();
    if (!mounted) return;

    if (start == null) {
      setState(() => _isCapturing = false);
      _showNoSignalHint(); // kein gutes Signal -> gar nicht messen
      return;
    }

    setState(() {
      _isCapturing = false;
      _startPos = start;
      // Vorherige Zielmessung verwerfen, falls der Nutzer neu startet.
      _endPos = null;
      _distance = null;
      _savedTrack = null;
      _liveDistance = 0; // Am Startpunkt sind es 0 m.
      _currentAccuracy = start.accuracy;
      // Pedometer: Basislinie merken, ab hier zaehlen wir die Schritte.
      _stepBaseline = _currentSteps;
      _stepsWalked = null;
      _step = _Step.startSet;
    });
    _startLiveTracking(start); // ab jetzt live mitzaehlen
    _fitMap();
  }

  Future<void> _setEnd() async {
    final start = _startPos;
    if (start == null) return;

    // Live-Mitzaehlen pausieren, waehrend wir den Zielpunkt stabil erfassen.
    _posSub?.cancel();
    _posSub = null;

    setState(() {
      _isLoading = true;
      _gpsError = null;
    });

    // 1. Berechtigung/GPS-Dienst pruefen.
    final perm = await _locationService.getCurrentPosition();
    if (!mounted) return;
    if (!perm.isSuccess) {
      setState(() {
        _gpsError = perm.status;
        _isLoading = false;
      });
      _startLiveTracking(start); // Live-Anzeige wieder aktivieren
      return;
    }

    // 2. Stabilen Zielpunkt erfassen (warten + mitteln).
    setState(() {
      _isLoading = false;
      _isCapturing = true;
      _captureCount = 0;
    });
    final end = await _captureStablePosition();
    if (!mounted) return;

    if (end == null) {
      setState(() => _isCapturing = false);
      _showNoSignalHint();
      _startLiveTracking(start); // weiter live anzeigen, Nutzer kann erneut versuchen
      return;
    }

    // Haversine-Distanz zwischen den beiden gemittelten Punkten in Metern.
    final dist = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    // Zweite Quelle: nur die Schrittzahl merken – die Distanz daraus wird
    // live berechnet, damit eine geaenderte Schrittlaenge sofort wirkt.
    final baseline = _stepBaseline;
    final nowSteps = _currentSteps;
    int? stepsWalked;
    if (baseline != null && nowSteps != null) {
      stepsWalked = nowSteps - baseline;
      if (stepsWalked < 0) stepsWalked = 0; // Sicherheit (Sensor-Reset o.ae.)
    }

    setState(() {
      _isCapturing = false;
      _endPos = end;
      _distance = dist;
      _savedTrack = null; // neue Messung → alten Save verwerfen
      _liveDistance = null; // Live-Wert nicht mehr relevant
      _currentAccuracy = end.accuracy; // gemittelte Genauigkeit der Ziel-Messung
      _stepsWalked = stepsWalked;
      _step = _Step.done;
    });
    _fitMap();
  }

  /// Start- und Zielpunkt vertauschen (z. B. um nicht zum Start zurückzulaufen).
  ///
  /// Die Distanz bleibt identisch (Luftlinie A→B = B→A), nur die Rollen der
  /// beiden Punkte tauschen – die Karten-Marker (grün=Start, rot=Ziel) tauschen
  /// dadurch automatisch. Ein bereits gespeicherter Track wird verworfen, damit
  /// die getauschte Variante neu gespeichert werden kann.
  void _swapStartEnd() {
    final oldStart = _startPos;
    final oldEnd = _endPos;
    if (oldStart == null || oldEnd == null) return;

    setState(() {
      _startPos = oldEnd;
      _endPos = oldStart;
      _savedTrack = null;
    });
    _fitMap();
  }

  /// Schwenkt/zoomt die Karte passend: beide Punkte einpassen, sonst auf den
  /// vorhandenen Punkt zentrieren. Nach dem Frame, damit die Karte bereit ist.
  void _fitMap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final start = _startPos;
      final end = _endPos;
      try {
        if (start != null && end != null) {
          _mapController.fitCamera(
            CameraFit.coordinates(
              coordinates: [
                LatLng(start.latitude, start.longitude),
                LatLng(end.latitude, end.longitude),
              ],
              padding: const EdgeInsets.all(48),
              maxZoom: 18,
            ),
          );
        } else if (start != null) {
          _mapController.move(LatLng(start.latitude, start.longitude), 18);
        }
      } catch (_) {
        // Karte evtl. noch nicht gerendert – unkritisch, nächster Punkt fixt es.
      }
    });
  }

  /// Startet das Live-Mitzaehlen: abonniert den Positions-Strom und berechnet
  /// bei JEDER neuen Position die Luftlinie vom Startpunkt zur aktuellen
  /// Position. Das ist der Kern von Variante A.
  void _startLiveTracking(Position start) {
    _posSub?.cancel(); // evtl. altes Abo zuerst beenden
    _posSub = _locationService.positionStream().listen((pos) {
      if (!mounted) return;
      setState(() {
        // Punkt 1: Genauigkeit IMMER aktualisieren, damit der Nutzer sie sieht.
        _currentAccuracy = pos.accuracy;
        _currentLatLng = LatLng(pos.latitude, pos.longitude); // Live-Marker

        // Punkt 3: zu ungenaue Positionen NICHT in die Distanz einrechnen –
        // sonst verfaelschen Ausreisser den Wert.
        if (pos.accuracy <= _maxAccuracyMeters) {
          _liveDistance = Geolocator.distanceBetween(
            start.latitude,
            start.longitude,
            pos.latitude,
            pos.longitude,
          );
        }
      });
    });
  }

  /// Sammelt mehrere GUTE GPS-Messungen und mittelt sie zu einem stabilen Punkt.
  /// Gibt `null` zurueck, wenn nicht rechtzeitig genug gute Messungen kamen
  /// (dann messen wir bewusst gar nicht – lieber nichts als ein falscher Wert).
  Future<Position?> _captureStablePosition() async {
    final samples = <Position>[];
    final completer = Completer<Position?>();

    void finish(Position? result) {
      _captureTimer?.cancel();
      _captureTimer = null;
      _captureSub?.cancel();
      _captureSub = null;
      if (!completer.isCompleted) completer.complete(result);
    }

    _captureSub = _locationService.positionStream().listen((pos) {
      if (!mounted) return finish(null);
      // Genauigkeit live zeigen, damit der Nutzer sieht, wie es besser wird.
      setState(() => _currentAccuracy = pos.accuracy);
      // Nur GUTE Messungen sammeln.
      if (pos.accuracy <= _goodAccuracyMeters) {
        samples.add(pos);
        setState(() => _captureCount = samples.length);
        if (samples.length >= _requiredSamples) {
          finish(_averagePosition(samples));
        }
      }
    });

    // Sicherheitsnetz: nach X Sekunden ohne genug gute Messungen abbrechen.
    _captureTimer = Timer(
      const Duration(seconds: _captureTimeoutSeconds),
      () => finish(null),
    );

    return completer.future;
  }

  /// Mittelt mehrere Positionen zu einer (Durchschnitt von Lat/Lng/Genauigkeit).
  /// Das glaettet das GPS-Rauschen deutlich.
  Position _averagePosition(List<Position> samples) {
    double lat = 0, lng = 0, acc = 0;
    for (final p in samples) {
      lat += p.latitude;
      lng += p.longitude;
      acc += p.accuracy;
    }
    final n = samples.length;
    return Position(
      latitude: lat / n,
      longitude: lng / n,
      timestamp: DateTime.now(),
      accuracy: acc / n,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  /// Roter Hinweis, wenn kein ausreichend genaues Signal zustande kam.
  void _showNoSignalHint() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Kein ausreichend genaues GPS-Signal. Geh auf offenes Feld '
          '(freier Himmel) und versuch es nochmal.',
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  /// Strecke in sqflite speichern und Track mit echter id zurückbekommen.
  Future<Track?> _saveTrack() async {
    final start = _startPos;
    final end = _endPos;
    final dist = _distance;
    if (start == null || end == null || dist == null) return null;

    // Bereits gespeichert? Nicht doppelt einfügen.
    if (_savedTrack != null) return _savedTrack;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    // Wir speichern den kombinierten (Sensor-Fusion-)Wert als Distanz, falls
    // verfuegbar – sonst die reine GPS-Distanz.
    final track = Track(
      name: name.isEmpty ? 'Meine Strecke' : name,
      startLat: start.latitude,
      startLng: start.longitude,
      endLat: end.latitude,
      endLng: end.longitude,
      distanceMeters: _combinedDistance() ?? dist,
    );

    final saved = await _db.insertTrack(track);
    if (!mounted) return null;

    setState(() {
      _savedTrack = saved;
      _isSaving = false;
    });
    return saved;
  }

  /// Speichern (falls nötig) und direkt zum RaceScreen.
  Future<void> _saveAndSprint() async {
    final track = await _saveTrack();
    if (!mounted || track == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RaceScreen(track: track)),
    );
  }

  /// Nur speichern, dann SnackBar zeigen.
  Future<void> _saveOnly() async {
    final track = await _saveTrack();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          track != null
              ? '«${track.name}» gespeichert!'
              : 'Fehler beim Speichern.',
        ),
        backgroundColor: track != null ? Colors.green[800] : Colors.red[800],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _reset() {
    _posSub?.cancel(); // laufendes Live-Abo beenden
    _posSub = null;
    _captureSub?.cancel(); // laufende Punkterfassung beenden
    _captureSub = null;
    _captureTimer?.cancel();
    _captureTimer = null;
    setState(() {
      _step = _Step.idle;
      _startPos = null;
      _endPos = null;
      _distance = null;
      _savedTrack = null;
      _liveDistance = null;
      _currentAccuracy = null;
      _isCapturing = false;
      _captureCount = 0;
      _stepBaseline = null;
      _stepsWalked = null;
      _gpsError = null;
      _nameController.clear();
    });
  }

  // ---------------------------------------------------------------------------
  // UI-Aufbau
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Schliessen',
        ),
        title: const Text(
          'STRECKE VERMESSEN',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
        actions: [
          // Temporaerer Zugang zum Sprint-Start-Test (Teil B).
          IconButton(
            icon: const Icon(Icons.directions_run),
            tooltip: 'Sprint-Start-Test',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MotionTestScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMap(),
            const SizedBox(height: 16),
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            if (_gpsError != null) ...[
              const SizedBox(height: 12),
              _buildErrorCard(),
            ],
            const SizedBox(height: 24),
            _buildDistanzCard(),
            // Streckenname + Speichern erst zeigen, wenn Start UND Ziel gesetzt
            // sind (vorher gibt es noch nichts zu benennen/speichern).
            if (_step == _Step.done) ...[
              const SizedBox(height: 12),
              _buildComparisonCard(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _swapStartEnd,
                icon: const Icon(Icons.swap_vert),
                label: const Text('START & ZIEL TAUSCHEN'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: BorderSide(color: Colors.amber.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              _buildNameField(),
              const SizedBox(height: 24),
              _buildSaveButtons(),
            ],
          ],
        ),
      ),
    );
  }

  /// Karte (OpenStreetMap) mit Start-, Ziel- und Live-Positions-Marker.
  Widget _buildMap() {
    final start = _startPos;
    final end = _endPos;
    final current = _currentLatLng;

    // Startzentrum: gesetzter Start → aktuelle Position → Fallback (Bern).
    final center = start != null
        ? LatLng(start.latitude, start.longitude)
        : current ?? const LatLng(46.9481, 7.4474);

    final markers = <Marker>[
      if (current != null && _step != _Step.done)
        Marker(
          point: current,
          width: 24,
          height: 24,
          child: const Icon(Icons.my_location, color: Colors.lightBlueAccent, size: 24),
        ),
      if (start != null)
        Marker(
          point: LatLng(start.latitude, start.longitude),
          width: 40,
          height: 40,
          child: const Icon(Icons.trip_origin, color: Colors.greenAccent, size: 30),
        ),
      if (end != null)
        Marker(
          point: LatLng(end.latitude, end.longitude),
          width: 40,
          height: 40,
          child: const Icon(Icons.flag, color: Colors.redAccent, size: 30),
        ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 17,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'dev.bergamin.bolt',
            ),
            MarkerLayer(markers: markers),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Zentrale Statuskarte: Icon/Fortschritt, Beschreibungstext, Koordinaten.
  Widget _buildStatusCard() {
    final (IconData icon, String text) = switch (_step) {
      _Step.idle => (Icons.place_outlined, 'Start- und Zielpunkt setzen'),
      _Step.startSet => (
        Icons.flag_outlined,
        'Startpunkt gesetzt\nJetzt zum Ziel gehen und Zielpunkt setzen',
      ),
      _Step.done => (Icons.check_circle_outline, 'Vermessung abgeschlossen'),
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          if (_isCapturing)
            _buildCaptureAnimation()
          else if (_isLoading)
            const CircularProgressIndicator(color: Colors.amber)
          else
            Icon(icon, size: 56, color: Colors.amber),
          const SizedBox(height: 16),
          Text(
            _isCapturing
                ? 'Warte auf brauchbares GPS-Signal…\n'
                    '$_captureCount/$_requiredSamples Messungen'
                : text,
            textAlign: TextAlign.center,
          ),
          if (_startPos != null) ...[
            const SizedBox(height: 16),
            _coordRow('Start', _startPos!),
          ],
          if (_endPos != null) ...[
            const SizedBox(height: 6),
            _coordRow('Ziel', _endPos!),
          ],
          if (_savedTrack != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Gespeichert als «${_savedTrack!.name}»',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Rennender Mann (Lottie) während der GPS-Punkterfassung – begleitet die
  /// "$_captureCount/$_requiredSamples Messungen"-Anzeige. Fehlt die
  /// runner.json noch, zeigt der errorBuilder den bisherigen Ladeindikator.
  ///
  /// (Mit der echten Animationsdatei liesse sich die Laufgeschwindigkeit über
  /// einen AnimationController zusätzlich an _captureCount koppeln.)
  Widget _buildCaptureAnimation() {
    return SizedBox(
      height: 80,
      child: Lottie.asset(
        'assets/lottie/runner.json',
        repeat: true,
        errorBuilder: (_, _, _) =>
            const CircularProgressIndicator(color: Colors.amber),
      ),
    );
  }

  Widget _coordRow(String label, Position pos) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Text(
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
          style: const TextStyle(color: Colors.amber, fontSize: 12),
        ),
      ],
    );
  }

  /// Zwei Aktions-Buttons nebeneinander: STARTPUNKT SETZEN | ZIELPUNKT SETZEN.
  Widget _buildActionButtons() {
    final startActive = !_isLoading && !_isCapturing;
    final endActive = !_isLoading && !_isCapturing && _step != _Step.idle;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: startActive ? _setStart : null,
            icon: const Icon(Icons.my_location, size: 18),
            label: const Text(
              'STARTPUNKT\nSETZEN',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _step == _Step.idle ? Colors.amber : Colors.grey[800],
              foregroundColor:
                  _step == _Step.idle ? Colors.black : Colors.white70,
              disabledBackgroundColor: Colors.grey[850],
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: endActive ? _setEnd : null,
            icon: const Icon(Icons.flag, size: 18),
            label: const Text(
              'ZIELPUNKT\nSETZEN',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _step == _Step.startSet ? Colors.amber : Colors.grey[800],
              foregroundColor:
                  _step == _Step.startSet ? Colors.black : Colors.white70,
              disabledBackgroundColor: Colors.grey[850],
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  /// Roter Hinweis-Block, wenn GPS nicht verfügbar / keine Berechtigung.
  Widget _buildErrorCard() {
    final (String msg, bool showSettingsButton) = switch (_gpsError) {
      LocationStatus.serviceDisabled => (
        'GPS ist ausgeschaltet.\nBitte in den Geräte-Einstellungen aktivieren.',
        false,
      ),
      LocationStatus.permissionDenied => (
        'Standort-Berechtigung verweigert.\nBitte nochmals erlauben.',
        false,
      ),
      LocationStatus.permissionDeniedForever => (
        'Berechtigung dauerhaft verweigert.\nBitte in den App-Einstellungen freigeben.',
        true,
      ),
      _ => ('Unbekannter GPS-Fehler.', false),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[900]?.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
            ],
          ),
          if (showSettingsButton)
            TextButton(
              onPressed: _locationService.openAppSettings,
              child: const Text(
                'App-Einstellungen öffnen',
                style: TextStyle(color: Colors.amber),
              ),
            ),
        ],
      ),
    );
  }

  /// Zeigt die Distanz: waehrend des Messens (startSet) die LIVE-Distanz,
  /// nach dem Ziel (done) die eingefrorene Mess-Distanz.
  Widget _buildDistanzCard() {
    final bool isLive = _step == _Step.startSet;
    final double? dist = isLive ? _liveDistance : _distance;
    final tooShort = !isLive && dist != null && dist < _minDistanceMeters;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isLive ? 'LIVE-DISTANZ' : 'DISTANZ',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              if (isLive) ...[
                const SizedBox(width: 8),
                const Icon(Icons.circle, color: Colors.redAccent, size: 10),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dist != null ? '${dist.toStringAsFixed(1)} m' : '— m',
            style: TextStyle(
              color: tooShort ? Colors.orange : Colors.amber,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Punkt 1: aktuelle GPS-Genauigkeit (±X m), farbcodiert.
          if (_currentAccuracy != null) ...[
            const SizedBox(height: 8),
            _buildAccuracyRow(),
          ],
          if (tooShort)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Strecke zu kurz – wahrscheinlich GPS-Rauschen (±3–5 m).\n'
                'Bitte Start und Ziel weiter auseinandersetzen.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            )
          else if (isLive)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                (_currentAccuracy != null && _currentAccuracy! > _maxAccuracyMeters)
                    ? 'GPS-Signal zu ungenau – Distanz pausiert.\n'
                        'Geh nach draußen oder warte auf besseres Signal.'
                    : 'Geh zum Ziel – die Distanz zählt live mit.',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            )
          else if (dist != null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'GPS-Messung',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  /// Punkt 1: zeigt die GPS-Genauigkeit (±X m) farbcodiert an.
  /// gut (<= 8 m, grün) · mittel (<= 20 m, orange) · schlecht (> 20 m, rot).
  Widget _buildAccuracyRow() {
    final acc = _currentAccuracy!;
    final Color color;
    final String quality;
    if (acc <= 8) {
      color = Colors.greenAccent;
      quality = 'gut';
    } else if (acc <= _maxAccuracyMeters) {
      color = Colors.orange;
      quality = 'mittel';
    } else {
      color = Colors.redAccent;
      quality = 'schlecht';
    }

    return Row(
      children: [
        Icon(Icons.gps_fixed, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          'GPS-Genauigkeit: ±${acc.toStringAsFixed(0)} m ($quality)',
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }

  /// Zeigt im done-Schritt GPS und Schritte einzeln + ein kombiniertes Total,
  /// das nach GPS-Genauigkeit gewichtet ist (Sensor-Fusion).
  Widget _buildComparisonCard() {
    final gps = _distance;
    final steps = _stepsWalked;
    final stepDist = steps != null ? steps * _strideMeters : null;
    final combined = _combinedDistance();
    final gpsPct = (_gpsWeight(_currentAccuracy ?? 15) * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MESSMETHODEN',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _methodRow(
            Icons.satellite_alt,
            'GPS (Luftlinie)',
            gps != null ? '${gps.toStringAsFixed(1)} m' : '—',
          ),
          const SizedBox(height: 8),
          _methodRow(
            Icons.directions_walk,
            'Schritte',
            stepDist != null
                ? '${stepDist.toStringAsFixed(1)} m  ($steps Schr.)'
                : 'nicht verfügbar',
          ),
          const Divider(height: 24, color: Colors.white12),
          // Kombiniertes Total – gewichtet nach GPS-Genauigkeit.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KOMBINIERT',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stepDist != null
                          ? 'GPS $gpsPct % · Schritte ${100 - gpsPct} %'
                          : 'nur GPS (kein Schrittwert)',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                combined != null ? '${combined.toStringAsFixed(1)} m' : '—',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Colors.white12),
          // Schrittlaenge anpassen (wirkt sofort auf Schritt- und Kombi-Wert).
          Row(
            children: [
              const Icon(Icons.straighten, size: 16, color: Colors.white54),
              const SizedBox(width: 8),
              const Text('Schrittlänge', style: TextStyle(fontSize: 13)),
              const Spacer(),
              IconButton(
                onPressed: () => _changeStride(-0.05),
                icon: const Icon(Icons.remove_circle_outline, color: Colors.amber),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '${_strideMeters.toStringAsFixed(2)} m',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => _changeStride(0.05),
                icon: const Icon(Icons.add_circle_outline, color: Colors.amber),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _methodRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.amber),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(
          value,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Gewicht des GPS am kombinierten Wert (0..1), abhaengig von der Genauigkeit:
  /// gutes GPS -> hohes Gewicht, schlechtes GPS -> mehr Vertrauen in die Schritte.
  double _gpsWeight(double accuracy) {
    if (accuracy <= 8) return 0.85;
    if (accuracy >= 25) return 0.40;
    final t = (accuracy - 8) / (25 - 8); // 0..1
    return 0.85 - t * (0.85 - 0.40);
  }

  /// Kombiniert GPS- und Schritt-Distanz, gewichtet nach GPS-Genauigkeit.
  double? _combinedDistance() {
    final gps = _distance;
    if (gps == null) return null;
    final steps = _stepsWalked;
    if (steps == null) return gps; // keine zweite Quelle -> nur GPS
    final stepDist = steps * _strideMeters;
    final w = _gpsWeight(_currentAccuracy ?? 15);
    return w * gps + (1 - w) * stepDist;
  }

  void _changeStride(double delta) {
    setState(() {
      _strideMeters = (_strideMeters + delta).clamp(0.40, 2.00).toDouble();
    });
  }

  /// Optionales Textfeld für den Streckennamen (fliessen in Track.name ein).
  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      enabled: _step == _Step.done,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'STRECKENNAME',
        hintText: 'z. B. Schulhof Sprint',
        labelStyle: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
        hintStyle: const TextStyle(color: Colors.white30),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.amber),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildSaveButtons() {
    final busy = _isSaving || _isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: busy ? null : _saveAndSprint,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Icon(Icons.timer),
          label: const Text('SPEICHERN & SPRINTEN'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: (busy || _savedTrack != null) ? null : _saveOnly,
          icon: const Icon(Icons.save_outlined),
          label: Text(_savedTrack != null ? 'GESPEICHERT' : 'NUR SPEICHERN'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.amber,
            side: const BorderSide(color: Colors.amber),
            disabledForegroundColor: Colors.white30,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : _reset,
          icon: const Icon(Icons.refresh),
          label: const Text('NEU MESSEN'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white54,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}
