import 'package:bolt/services/game_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit-Tests der reinen XP-/Level-Logik (kein Plugin, keine DB nötig).
void main() {
  final game = GameService();

  group('calculateXp', () {
    test('Positivtest: 100 m in 12.5 s ohne Bestzeit ergibt 130 XP', () {
      // 100 / 12.5 = 8 m/s -> Bonus 80, plus 50 Basis = 130
      final xp = game.calculateXp(
        distanceMeters: 100,
        durationMs: 12500,
        isNewBest: false,
      );
      expect(xp, 130);
    });

    test('Positivtest: neue Bestzeit gibt +50 Bonus (180 XP)', () {
      final xp = game.calculateXp(
        distanceMeters: 100,
        durationMs: 12500,
        isNewBest: true,
      );
      expect(xp, 180);
    });

    test('Negativtest: durationMs = 0 stürzt nicht ab und gibt nur Basis-XP', () {
      // Randfall: ohne Schutz gäbe es eine Division durch 0 (Infinity).
      final xp = game.calculateXp(
        distanceMeters: 100,
        durationMs: 0,
        isNewBest: false,
      );
      expect(xp, 50);
      expect(xp.isFinite, isTrue);
    });
  });

  group('Level-Logik', () {
    test('levelFromXp: Schwelle bei je 500 XP', () {
      expect(game.levelFromXp(0), 1);
      expect(game.levelFromXp(499), 1);
      expect(game.levelFromXp(500), 2);
      expect(game.levelFromXp(1000), 3);
    });

    test('xpInCurrentLevel: Rest innerhalb des aktuellen Levels', () {
      expect(game.xpInCurrentLevel(0), 0);
      expect(game.xpInCurrentLevel(500), 0);
      expect(game.xpInCurrentLevel(550), 50);
    });
  });
}
