import 'package:flutter/material.dart';

import '../models/player.dart';
import '../models/run.dart';
import '../services/database_service.dart';
import '../services/game_service.dart';

/// Hauptmenü / Home-Tab (Mockup 5.1): Level/XP oben, Aktions-Buttons, letzte Läufe.
///
/// [onGoToTab] wechselt den Tab der umgebenden [MainShell] (z. B. Sprint = 1,
/// Statistik = 2), statt einen neuen Screen zu pushen.
class HomeScreen extends StatefulWidget {
  final void Function(int index)? onGoToTab;

  const HomeScreen({super.key, this.onGoToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseService.instance;
  final _gameService = GameService();

  Player? _player;
  List<({Run run, String trackName, double distanceMeters})>? _recentRuns;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final player = await _gameService.loadPlayer();
    final runs = await _db.getRecentRuns(limit: 5);
    if (!mounted) return;
    setState(() {
      _player = player;
      _recentRuns = runs;
    });
  }

  /// Rang-Titel aus dem Level (Gamification-Flavor, Mockup zeigt "SPRINT-ROOKIE").
  String _rankName(int level) {
    if (level >= 10) return 'BOLT-LEGENDE';
    if (level >= 6) return 'SPEEDSTER';
    if (level >= 3) return 'SPRINTER';
    return 'SPRINT-ROOKIE';
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: Colors.amber,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildLevelCard(),
              const SizedBox(height: 16),
              _buildSprintButton(),
              const SizedBox(height: 12),
              _buildSecondaryButtons(),
              const SizedBox(height: 28),
              _buildRecentRuns(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bausteine
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    // Zwei separate Bilder: links das Logo (B.O.L.T), rechts der Slogan.
    // Fehlt eine Datei noch, zeigt der errorBuilder einen Text-Fallback.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Links: Logo
        Image.asset(
          'assets/images/logo.png',
          height: 56,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _buildLogoFallback(),
        ),
        const Spacer(),
        // Rechts: Slogan
        Image.asset(
          'assets/images/slogan.png',
          height: 40,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _buildSloganFallback(),
        ),
      ],
    );
  }

  /// Fallback für das Logo (links), solange keine logo.png da ist.
  Widget _buildLogoFallback() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bolt, size: 32, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          'B.O.L.T.',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            color: Colors.amber,
            letterSpacing: 1,
            shadows: [
              Shadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 12),
            ],
          ),
        ),
      ],
    );
  }

  /// Fallback für den Slogan (rechts), solange keine slogan.png da ist.
  Widget _buildSloganFallback() {
    return const Text(
      'BREAK OLD\nLIMITS TODAY',
      textAlign: TextAlign.right,
      style: TextStyle(letterSpacing: 2, fontSize: 10, color: Colors.white54),
    );
  }

  Widget _buildLevelCard() {
    final player = _player;
    if (player == null) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    final xpInLevel = _gameService.xpInCurrentLevel(player.xp);
    final progress = xpInLevel / GameService.xpPerLevel;

    return Container(
      padding: const EdgeInsets.all(18),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RANG',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _rankName(player.level),
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LV.${player.level}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'XP-FORTSCHRITT',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '$xpInLevel / ${GameService.xpPerLevel}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSprintButton() {
    return ElevatedButton.icon(
      onPressed: () => widget.onGoToTab?.call(1),
      icon: const Icon(Icons.bolt),
      label: const Text(
        'SPRINT STARTEN',
        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildSecondaryButtons() {
    // "Strecke vermessen" ist ins Strecken-"+"-Menü gewandert; hier bleibt
    // nur der Schnellzugriff auf die Statistik.
    return _secondaryButton(
      icon: Icons.bar_chart,
      label: 'STATISTIK',
      onPressed: () => widget.onGoToTab?.call(2),
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.amber,
        side: BorderSide(color: Colors.amber.withValues(alpha: 0.6)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRuns() {
    final runs = _recentRuns;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 3, height: 16, color: Colors.amber),
            const SizedBox(width: 8),
            const Text(
              'LETZTE LÄUFE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (runs == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: Colors.amber),
            ),
          )
        else if (runs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.directions_run, color: Colors.white24, size: 40),
                SizedBox(height: 12),
                Text(
                  'Noch keine Läufe.\nMess eine Strecke und sprint los!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...runs.map(_buildRunTile),
      ],
    );
  }

  Widget _buildRunTile(
      ({Run run, String trackName, double distanceMeters}) entry) {
    final xp = _gameService.calculateXp(
      distanceMeters: entry.distanceMeters,
      durationMs: entry.run.durationMs,
      isNewBest: false,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: Colors.amber, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.trackName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(entry.run.date),
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(entry.run.durationMs),
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '+$xp XP',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final runDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(runDay).inDays;

    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'Heute, $time';
    if (diff == 1) return 'Gestern, $time';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
