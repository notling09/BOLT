import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

/// Die drei Schritte der Streckenvermessung (UC1 / User-Story 1).
enum _Step {
  idle,     // noch kein Startpunkt
  startSet, // Startpunkt gesetzt, Ziel fehlt noch
  done,     // beide Punkte gesetzt, Distanz berechnet
}

/// Screen "Strecke vermessen" – Phase 3 (UC1).
///
/// Erfasst Start- und Zielpunkt per GPS und berechnet die Distanz mit
/// [Geolocator.distanceBetween]. Kein sqflite – das Track-Objekt lebt nur
/// im RAM bis der Screen verlassen wird (Persistenz kommt in Phase 6).
class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

class _MeasureScreenState extends State<MeasureScreen> {
  final _locationService = LocationService();
  final _nameController = TextEditingController();

  _Step _step = _Step.idle;
  bool _isLoading = false;

  Position? _startPos;
  Position? _endPos;
  double? _distance;

  /// Live mitlaufende Luftlinie Start -> aktuelle Position (Variante A).
  /// Nur waehrend des Messens (Step.startSet) aktiv.
  double? _liveDistance;

  /// Abo des GPS-Positions-Stroms. Muss beim Verlassen/Reset gekuendigt werden,
  /// sonst laeuft das GPS im Hintergrund weiter (Akku!).
  StreamSubscription<Position>? _posSub;

  /// Gesetzt, wenn ein GPS-Aufruf fehlschlug (serviceDisabled / permissionDenied…).
  LocationStatus? _gpsError;

  /// Unter dieser Distanz warnen wir vor GPS-Rauschen (±3–5 m Ungenauigkeit).
  static const double _minDistanceMeters = 10.0;

  @override
  void dispose() {
    _posSub?.cancel(); // GPS-Strom stoppen, sonst laeuft er im Hintergrund weiter.
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
      final start = result.position!;
      setState(() {
        _startPos = start;
        // Vorherige Zielmessung verwerfen, falls der Nutzer neu startet.
        _endPos = null;
        _distance = null;
        _liveDistance = 0; // Am Startpunkt sind es 0 m.
        _step = _Step.startSet;
        _isLoading = false;
      });
      _startLiveTracking(start); // ab jetzt live mitzaehlen
    } else {
      setState(() {
        _gpsError = result.status;
        _isLoading = false;
      });
    }
  }

  /// Startet das Live-Mitzaehlen: abonniert den Positions-Strom und berechnet
  /// bei JEDER neuen Position die Luftlinie vom Startpunkt zur aktuellen
  /// Position. Das ist der Kern von Variante A.
  void _startLiveTracking(Position start) {
    _posSub?.cancel(); // evtl. altes Abo zuerst beenden
    _posSub = _locationService.positionStream().listen((pos) {
      if (!mounted) return;
      final d = Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        pos.latitude,
        pos.longitude,
      );
      setState(() => _liveDistance = d);
    });
  }

  Future<void> _setEnd() async {
    // Lokale Kopie vor dem await – Dart Flow Analysis verliert die Null-Garantie
    // auf Klassen-Felder über async-Grenzen hinweg.
    final start = _startPos;
    if (start == null) return;

    setState(() {
      _isLoading = true;
      _gpsError = null;
    });

    final result = await _locationService.getCurrentPosition();
    if (!mounted) return;

    if (result.isSuccess) {
      // Live-Mitzaehlen stoppen – ab jetzt ist die Distanz eingefroren.
      _posSub?.cancel();
      _posSub = null;

      // position ist garantiert non-null wenn isSuccess == true.
      final end = result.position!;
      // Haversine-Distanz zwischen zwei GPS-Punkten in Metern.
      final dist = Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );

      setState(() {
        _endPos = end;
        _distance = dist;
        _liveDistance = null; // Live-Wert nicht mehr relevant
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

  void _reset() {
    _posSub?.cancel(); // laufendes Live-Abo beenden
    _posSub = null;
    setState(() {
      _step = _Step.idle;
      _startPos = null;
      _endPos = null;
      _distance = null;
      _liveDistance = null;
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
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('NEU MESSEN'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Zentrale Statuskarte: Icon, Beschreibungstext, Koordinaten.
  Widget _buildStatusCard() {
    final (IconData icon, String text) = switch (_step) {
      _Step.idle => (Icons.place_outlined, 'Start- und Zielpunkt setzen'),
      _Step.startSet => (Icons.flag_outlined, 'Startpunkt gesetzt\nJetzt zum Ziel gehen und Zielpunkt setzen'),
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

  /// Zwei Aktions-Buttons nebeneinander: STARTPUNKT SETZEN | ZIELPUNKT SETZEN.
  Widget _buildActionButtons() {
    final startActive = !_isLoading;
    final endActive = !_isLoading && _step != _Step.idle;

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
              backgroundColor: _step == _Step.idle ? Colors.amber : Colors.grey[800],
              foregroundColor: _step == _Step.idle ? Colors.black : Colors.white70,
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
              backgroundColor: _step == _Step.startSet ? Colors.amber : Colors.grey[800],
              foregroundColor: _step == _Step.startSet ? Colors.black : Colors.white70,
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
              Expanded(
                child: Text(msg, style: const TextStyle(fontSize: 13)),
              ),
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

  /// Zeigt die berechnete Distanz (oder "— m" wenn noch nicht gemessen).
  Widget _buildDistanzCard() {
    // Waehrend des Messens (startSet) zeigen wir die LIVE-Distanz,
    // nach dem Ziel (done) die eingefrorene Mess-Distanz.
    final bool isLive = _step == _Step.startSet;
    final double? dist = isLive ? _liveDistance : _distance;
    // Die "zu kurz"-Warnung ist nur am Ende sinnvoll, nicht waehrend man laeuft.
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
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Geh zum Ziel – die Distanz zählt live mit.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
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
}
