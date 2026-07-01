import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/run.dart';
import '../models/track.dart';
import '../services/database_service.dart';
import 'race_screen.dart';

/// Übersicht zu einer gespeicherten Strecke (Phase 9).
///
/// Zeigt Karte (Start/Ziel), Distanz, Bestzeit und die Läufe. Von hier kann
/// man die Strecke sprinten oder Start/Ziel tauschen.
class TrackDetailScreen extends StatefulWidget {
  final Track track;

  const TrackDetailScreen({super.key, required this.track});

  @override
  State<TrackDetailScreen> createState() => _TrackDetailScreenState();
}

class _TrackDetailScreenState extends State<TrackDetailScreen> {
  final _db = DatabaseService.instance;

  late Track _track = widget.track;
  List<Run> _runs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Frischen Stand laden (falls die Strecke neu vermessen wurde).
    final id = _track.id;
    if (id != null) {
      final fresh = await _db.getTrack(id);
      final runs = await _db.getRunsForTrack(id);
      if (!mounted) return;
      setState(() {
        if (fresh != null) _track = fresh;
        _runs = runs; // bereits nach Zeit aufsteigend sortiert
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _startSprint() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RaceScreen(track: _track)),
    );
  }

  /// Vertauscht Start und Ziel der gespeicherten Strecke (dauerhaft in der DB,
  /// jederzeit wieder zurück-tauschbar). Distanz bleibt gleich (A→B = B→A);
  /// die Karten-Marker (grün=Start, rot=Ziel) tauschen automatisch.
  Future<void> _swapStartEnd() async {
    final t = _track;
    final id = t.id;
    if (id == null) return;

    final swapped = Track(
      id: id,
      name: t.name,
      startLat: t.endLat,
      startLng: t.endLng,
      endLat: t.startLat,
      endLng: t.startLng,
      distanceMeters: t.distanceMeters,
      isTemplate: t.isTemplate,
    );
    await _db.updateTrack(swapped);
    await _load();
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Start und Ziel getauscht'),
          ],
        ),
        backgroundColor: Colors.green[800],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatTime(int ms) {
    final d = Duration(milliseconds: ms);
    final min = d.inMinutes.toString().padLeft(2, '0');
    final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
    final hund = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$min:$sec.$hund';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _track.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMapOrTemplate(),
                const SizedBox(height: 16),
                _buildInfoRow(),
                const SizedBox(height: 16),
                _buildActions(),
                const SizedBox(height: 24),
                _buildRuns(),
              ],
            ),
    );
  }

  /// Karte mit Start/Ziel – oder ein Hinweis bei Vorgabe-Strecken (ohne Koords).
  Widget _buildMapOrTemplate() {
    if (_track.isTemplate) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.straighten, color: Colors.amber),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Vorgabe-Strecke mit fester Distanz.\n'
                'Beim Sprint wird gestoppt, sobald du die Distanz gelaufen bist.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final start = LatLng(_track.startLat, _track.startLng);
    final end = LatLng(_track.endLat, _track.endLng);
    final center = LatLng(
      (_track.startLat + _track.endLat) / 2,
      (_track.startLng + _track.endLng) / 2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
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
            MarkerLayer(
              markers: [
                Marker(
                  point: start,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.trip_origin,
                      color: Colors.greenAccent, size: 30),
                ),
                Marker(
                  point: end,
                  width: 40,
                  height: 40,
                  child:
                      const Icon(Icons.flag, color: Colors.redAccent, size: 30),
                ),
              ],
            ),
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

  /// Distanz + Bestzeit nebeneinander.
  Widget _buildInfoRow() {
    final best = _runs.isEmpty ? null : _runs.first;
    return Row(
      children: [
        Expanded(
          child: _statCard(
            'DISTANZ',
            '${_track.distanceMeters.toStringAsFixed(_track.isTemplate ? 0 : 1)} m',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            'BESTZEIT',
            best != null ? _formatTime(best.durationMs) : '—',
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 11, letterSpacing: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: _startSprint,
          icon: const Icon(Icons.bolt),
          label: const Text(
            'SPRINT STARTEN',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        // "Start/Ziel tauschen" nur für selbst vermessene Strecken – bei
        // Vorgabe-Strecken (feste Distanz, keine Koordinaten) sinnlos.
        if (!_track.isTemplate) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _swapStartEnd,
            icon: const Icon(Icons.swap_horiz),
            label: const Text('START/ZIEL TAUSCHEN'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber,
              side: const BorderSide(color: Colors.amber),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRuns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 16, color: Colors.amber),
            const SizedBox(width: 8),
            const Text(
              'LÄUFE',
              style: TextStyle(
                  fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_runs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Noch keine Läufe auf dieser Strecke.\nSprint starten!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          )
        else
          ..._runs.asMap().entries.map((e) => _buildRunTile(e.key, e.value)),
      ],
    );
  }

  Widget _buildRunTile(int rank, Run run) {
    final isBest = rank == 0; // Liste ist nach Zeit sortiert → erster = Bestzeit
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: isBest
            ? Border.all(color: Colors.amber.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Icon(isBest ? Icons.emoji_events : Icons.directions_run,
              color: isBest ? Colors.amber : Colors.white38, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _formatDate(run.date),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Text(
            _formatTime(run.durationMs),
            style: const TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final t =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}  $t';
  }
}
