import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

/// Test-Screen aus Phase 2 (GPS-Grundlagen).
///
/// Zeigt die aktuelle Position live an (Latitude / Longitude / Genauigkeit).
/// Ohne Berechtigung oder GPS-Signal erscheint ein freundlicher Hinweis statt
/// eines Absturzes (Akzeptanzkriterium User-Story 1).
class GpsTestScreen extends StatefulWidget {
  const GpsTestScreen({super.key});

  @override
  State<GpsTestScreen> createState() => _GpsTestScreenState();
}

class _GpsTestScreenState extends State<GpsTestScreen> {
  final LocationService _locationService = LocationService();

  /// Live-Abo des Positions-Stroms. `null`, solange wir nichts empfangen.
  StreamSubscription<Position>? _positionSub;

  LocationStatus? _status; // null = noch am Laden
  Position? _position;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    // GPS-Strom beenden, damit nichts im Hintergrund weiterläuft (Akku).
    _positionSub?.cancel();
    super.dispose();
  }

  /// Startet die Abfrage: erst eine Position holen (inkl. Berechtigung),
  /// bei Erfolg dann den Live-Strom abonnieren.
  Future<void> _start() async {
    setState(() => _loading = true);

    final result = await _locationService.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      _status = result.status;
      _position = result.position;
      _loading = false;
    });

    if (result.isSuccess) {
      _positionSub?.cancel();
      _positionSub = _locationService.positionStream().listen((pos) {
        if (!mounted) return;
        setState(() => _position = pos);
      });
    }
  }

  Future<void> _openSettings() async {
    await _locationService.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPS-Test'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildContent(),
        ),
      ),
    );
  }

  /// Wählt anhand des Status, was angezeigt wird.
  Widget _buildContent() {
    if (_loading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.amber),
          SizedBox(height: 16),
          Text('Suche GPS-Signal …'),
        ],
      );
    }

    switch (_status) {
      case LocationStatus.success:
        return _buildPosition(_position!);

      case LocationStatus.serviceDisabled:
        return _buildHint(
          icon: Icons.location_off,
          message:
              'Der Standortdienst ist ausgeschaltet.\n'
              'Bitte aktiviere GPS in den Geräte-Einstellungen.',
          buttonLabel: 'Erneut versuchen',
          onPressed: _start,
        );

      case LocationStatus.permissionDenied:
        return _buildHint(
          icon: Icons.gps_off,
          message:
              'Ohne Standort-Berechtigung kann BOLT deine Sprints nicht messen.',
          buttonLabel: 'Berechtigung erneut anfragen',
          onPressed: _start,
        );

      case LocationStatus.permissionDeniedForever:
        return _buildHint(
          icon: Icons.settings,
          message:
              'Die Standort-Berechtigung wurde dauerhaft abgelehnt.\n'
              'Bitte gib sie in den App-Einstellungen frei.',
          buttonLabel: 'Einstellungen öffnen',
          onPressed: _openSettings,
        );

      case null:
        return const Text('Bereit.');
    }
  }

  /// Live-Anzeige der Position.
  Widget _buildPosition(Position pos) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.my_location, size: 72, color: Colors.amber),
        const SizedBox(height: 24),
        _dataRow('Latitude', pos.latitude.toStringAsFixed(6)),
        _dataRow('Longitude', pos.longitude.toStringAsFixed(6)),
        _dataRow('Genauigkeit', '± ${pos.accuracy.toStringAsFixed(1)} m'),
        const SizedBox(height: 24),
        const Text(
          'Aktualisiert sich live, sobald du dich bewegst.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Eine Beschriftungs-Zeile "Label: Wert".
  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  /// Freundlicher Hinweis-Block mit Icon, Text und Aktions-Knopf.
  Widget _buildHint({
    required IconData icon,
    required String message,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 72, color: Colors.amber),
        const SizedBox(height: 24),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
          ),
          child: Text(buttonLabel),
        ),
      ],
    );
  }
}
