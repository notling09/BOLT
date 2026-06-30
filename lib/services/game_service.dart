import 'package:shared_preferences/shared_preferences.dart';

import '../models/player.dart';

/// Gamification-Logik: XP berechnen, Level bestimmen, Fortschritt speichern.
///
/// Player-Daten (xp, level) leben in shared_preferences – kein sqflite nötig,
/// weil es nur einen einzigen Spieler mit zwei Skalar-Werten gibt.
class GameService {
  static const String _keyXp = 'player_xp';
  static const String _keyLevel = 'player_level';

  /// XP-Schwelle pro Level: alle 500 XP ein neues Level.
  static const int xpPerLevel = 500;

  // ---------------------------------------------------------------------------
  // Laden / Speichern
  // ---------------------------------------------------------------------------

  /// Aktuellen Spielstand laden (gibt Startwerte zurück falls noch nichts gespeichert).
  Future<Player> loadPlayer() async {
    final prefs = await SharedPreferences.getInstance();
    return Player(
      xp: prefs.getInt(_keyXp) ?? 0,
      level: prefs.getInt(_keyLevel) ?? 1,
    );
  }

  /// Spielstand dauerhaft speichern.
  Future<void> savePlayer(Player player) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyXp, player.xp);
    await prefs.setInt(_keyLevel, player.level);
  }

  // ---------------------------------------------------------------------------
  // XP-Berechnung
  // ---------------------------------------------------------------------------

  /// XP für einen abgeschlossenen Lauf berechnen.
  ///
  /// Formel (im Konzept besprochen):
  ///   Basis     = 50 XP  (jeder gültige Lauf zählt)
  ///   Bonus     = (Geschwindigkeit in m/s × 10).round()
  ///   Bestzeit  = +50 XP extra, wenn [isNewBest] == true
  ///
  /// Beispiel: 100 m in 12.5 s → 8 m/s → 50 + 80 = 130 XP (+ 50 bei Bestzeit)
  int calculateXp({
    required double distanceMeters,
    required int durationMs,
    required bool isNewBest,
  }) {
    const int base = 50;
    const int bestBonus = 50;

    final double seconds = durationMs / 1000.0;
    final double speed = seconds > 0 ? distanceMeters / seconds : 0;
    final int speedBonus = (speed * 10).round();

    return base + speedBonus + (isNewBest ? bestBonus : 0);
  }

  /// Level aus XP berechnen: alle 500 XP ein Level-up, Start bei Level 1.
  int levelFromXp(int xp) => xp ~/ xpPerLevel + 1;

  /// XP innerhalb des aktuellen Levels (für Fortschrittsbalken).
  int xpInCurrentLevel(int xp) => xp % xpPerLevel;

  // ---------------------------------------------------------------------------
  // Spielstand aktualisieren
  // ---------------------------------------------------------------------------

  /// XP gutschreiben, Level neu berechnen, speichern.
  /// Gibt den aktualisierten Player zurück.
  Future<Player> awardXp({
    required double distanceMeters,
    required int durationMs,
    required bool isNewBest,
  }) async {
    final current = await loadPlayer();
    final earned = calculateXp(
      distanceMeters: distanceMeters,
      durationMs: durationMs,
      isNewBest: isNewBest,
    );
    final newXp = current.xp + earned;
    final updated = Player(xp: newXp, level: levelFromXp(newXp));
    await savePlayer(updated);
    return updated;
  }
}
