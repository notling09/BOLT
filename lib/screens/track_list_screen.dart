import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/database_service.dart';
import 'measure_screen.dart';
import 'race_screen.dart';

/// Zeigt alle gespeicherten Strecken an (US6: Strecke speichern / wählen).
///
/// Der Nutzer wählt eine Strecke aus der Liste und startet damit direkt
/// den RaceScreen mit der echten gespeicherten Strecke (inkl. DB-id).
class TrackListScreen extends StatefulWidget {
  const TrackListScreen({super.key});

  @override
  State<TrackListScreen> createState() => _TrackListScreenState();
}

class _TrackListScreenState extends State<TrackListScreen> {
  final _db = DatabaseService.instance;

  List<Track>? _tracks; // null = wird noch geladen
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _tracks = null;
      _hasError = false;
    });
    try {
      final tracks = await _db.getTracks();
      if (!mounted) return;
      setState(() => _tracks = tracks);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  void _startSprint(Track track) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RaceScreen(track: track)),
    );
  }

  /// Zum Vermessen-Screen wechseln; nach Rückkehr Streckenliste neu laden.
  Future<void> _openMeasure() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MeasureScreen()),
    );
    await _loadTracks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'STRECKEN',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTracks,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return _buildCentered(
        icon: Icons.error_outline,
        text: 'Fehler beim Laden der Strecken.',
        button: ('Erneut versuchen', _loadTracks),
      );
    }

    if (_tracks == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }

    if (_tracks!.isEmpty) {
      return _buildCentered(
        icon: Icons.place_outlined,
        text: 'Noch keine Strecken gespeichert.\nMesse zuerst eine Strecke!',
        button: ('Strecke vermessen', _openMeasure),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tracks!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildTrackCard(_tracks![i]),
    );
  }

  Widget _buildTrackCard(Track track) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.place, color: Colors.amber),
        title: Text(
          track.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${track.distanceMeters.toStringAsFixed(1)} m',
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: ElevatedButton(
          onPressed: () => _startSprint(track),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('SPRINT'),
        ),
      ),
    );
  }

  Widget _buildCentered({
    required IconData icon,
    required String text,
    (String, VoidCallback)? button,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.amber),
            const SizedBox(height: 24),
            Text(text, textAlign: TextAlign.center),
            if (button != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: button.$2,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                child: Text(button.$1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
