import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/track.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import 'race_screen.dart';

/// Die drei Schritte der Streckenvermessung (UC1 / User-Story 1).
enum _Step {
  idle,     // noch kein Startpunkt
  startSet, // Startpunkt gesetzt, Ziel fehlt noch
  done,     // beide Punkte gesetzt, Distanz berechnet
}

/// Screen "Strecke vermessen" – Phase 3 (UC1) + Phase 6 (Persistenz).
///
/// Ablauf: Start setzen → Ziel setzen → Distanz anzeigen → SPEICHERN → Sprint.
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

  _Step _step = _Step.idle;
  bool _isLoading = false;
  bool _isSaving = false;

  Position? _startPos;
  Position? _endPos;
  double? _distance;

  /// Gesetzt nach erfolgreichem INSERT – enthält dann eine echte DB-id.
  Track? _savedTrack;

  /// Gesetzt, wenn ein GPS-Aufruf fehlschlug.
  LocationStatus? _gpsError;

  static const double _minDistanceMeters = 10.0;

  @override
  void dispose() {
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

    final result = await _locationService.getCurrentPosition();
    if (!mounted) return;

    if (result.isSuccess) {
      setState(() {
        _startPos = result.position;
        _endPos = null;
        _distance = null;
        _savedTrack = null;
        _step = _Step.startSet;
        _isLoading = false;
      });
    } else {
      setState(() {
        _gpsError = result.status;
        _isLoading = false;
      });
    }
  }

  Future<void> _setEnd() async {
    final start = _startPos;
    if (start == null) return;

    setState(() {
      _isLoading = true;
      _gpsError = null;
    });

    final result = await _locationService.getCurrentPosition();
    if (!mounted) return;

    if (result.isSuccess) {
      final end = result.position!;
      final dist = Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );

      setState(() {
        _endPos = end;
        _distance = dist;
        _savedTrack = null; // neue Messung → alten Save verwerfen
        _step = _Step.done;
        _isLoading = false;
      });
    } else {
      setState(() {
        _gpsError = result.status;
        _isLoading = false;
      });
    }
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
    final track = Track(
      name: name.isEmpty ? 'Meine Strecke' : name,
      startLat: start.latitude,
      startLng: start.longitude,
      endLat: end.latitude,
      endLng: end.longitude,
      distanceMeters: dist,
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
    setState(() {
      _step = _Step.idle;
      _startPos = null;
      _endPos = null;
      _distance = null;
      _savedTrack = null;
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            if (_gpsError != null) ...[
              const SizedBox(height: 12),
              _buildErrorCard(),
            ],
            const SizedBox(height: 24),
            _buildDistanzCard(),
            const SizedBox(height: 16),
            _buildNameField(),
            if (_step == _Step.done) ...[
              const SizedBox(height: 24),
              _buildSaveButtons(),
            ],
          ],
        ),
      ),
    );
  }

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
          if (_isLoading)
            const CircularProgressIndicator(color: Colors.amber)
          else
            Icon(icon, size: 56, color: Colors.amber),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center),
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

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _setStart,
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
            onPressed: (_isLoading || _step == _Step.idle) ? null : _setEnd,
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

  Widget _buildDistanzCard() {
    final dist = _distance;
    final tooShort = dist != null && dist < _minDistanceMeters;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DISTANZ',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
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
          if (tooShort)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Strecke zu kurz – wahrscheinlich GPS-Rauschen (±3–5 m).\n'
                'Bitte Start und Ziel weiter auseinandersetzen.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
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
