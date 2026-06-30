import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/run.dart';
import '../models/track.dart';
import '../services/database_service.dart';
import '../services/game_service.dart';

/// Statistik-Screen: Level + XP (US4) und Bestzeiten pro Strecke (US5 / UC3).
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _db = DatabaseService.instance;
  final _gameService = GameService();

  Player? _player;
  // Jede Strecke zusammen mit ihren Läufen (bereits nach durationMs sortiert).
  List<(Track, List<Run>)>? _data;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _data = null;
      _hasError = false;
    });
    try {
      final player = await _gameService.loadPlayer();
      final tracks = await _db.getTracks();
      final data = <(Track, List<Run>)>[];
      for (final track in tracks) {
        final runs = await _db.getRunsForTrack(track.id!);
        data.add((track, runs));
      }
      if (!mounted) return;
      setState(() {
        _player = player;
        _data = data;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
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
        title: const Text(
          'STATISTIK',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            const Text('Fehler beim Laden.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: const Text('Erneut versuchen'),
            ),
          ],
        ),
      );
    }

    if (_data == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: Colors.amber,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPlayerCard(),
          const SizedBox(height: 24),
          _buildTracksSection(),
        ],
      ),
    );
  }

  /// Level + XP-Fortschrittsbalken (US4).
  Widget _buildPlayerCard() {
    final player = _player ?? const Player();
    final xpInLevel = _gameService.xpInCurrentLevel(player.xp);
    final progress = xpInLevel / GameService.xpPerLevel;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LEVEL',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${player.xp} XP gesamt',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${player.level}',
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$xpInLevel / ${GameService.xpPerLevel} XP bis Level ${player.level + 1}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// Strecken mit Bestzeiten und letzten Läufen (US5 / UC3).
  Widget _buildTracksSection() {
    final data = _data!;

    if (data.isEmpty) {
      return Column(
        children: [
          const Icon(Icons.directions_run, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Noch keine Läufe vorhanden.\nMesse eine Strecke und sprinke los!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        ],
      );
    }

    // Strecken mit Läufen zuerst anzeigen.
    final sorted = [...data]
      ..sort((a, b) => b.$2.length.compareTo(a.$2.length));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GESPEICHERTE STRECKEN',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...sorted.map((entry) => _buildTrackSection(entry.$1, entry.$2)),
      ],
    );
  }

  Widget _buildTrackSection(Track track, List<Run> runs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Strecken-Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.place, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      track.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${track.distanceMeters.toStringAsFixed(0)} m',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (runs.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  'Noch keine Läufe auf dieser Strecke.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              )
            else ...[
              const Divider(color: Colors.white12, height: 1),
              // Läufe (schnellste zuerst dank getRunsForTrack ORDER BY durationMs ASC)
              ...runs.take(5).toList().asMap().entries.map((entry) {
                final i = entry.key;
                final run = entry.value;
                final isBest = i == 0;
                return _buildRunRow(run, isBest: isBest);
              }),
              if (runs.length > 5)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Text(
                    '+ ${runs.length - 5} weitere Läufe',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                )
              else
                const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRunRow(Run run, {required bool isBest}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (isBest)
            const Icon(Icons.emoji_events, color: Colors.amber, size: 16)
          else
            const Icon(Icons.timer_outlined, color: Colors.white24, size: 16),
          const SizedBox(width: 8),
          Text(
            _formatTime(run.durationMs),
            style: TextStyle(
              color: isBest ? Colors.amber : Colors.white70,
              fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          Text(
            _formatDate(run.date),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}
