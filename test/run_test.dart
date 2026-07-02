import 'package:bolt/models/run.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit-Tests der Run-Serialisierung (toMap/fromMap, reine Dart-Logik).
void main() {
  group('Run Serialisierung', () {
    test('Positivtest: toMap -> fromMap erhält alle Felder inkl. date (Round-Trip)',
        () {
      final date = DateTime(2026, 6, 30, 14, 32, 15);
      final run = Run(id: 7, trackId: 3, durationMs: 12840, date: date);

      // toMap enthält keine id (DB vergibt sie beim Insert) – hier simuliert.
      final row = {...run.toMap(), 'id': 7};
      final restored = Run.fromMap(row);

      expect(restored.id, 7);
      expect(restored.trackId, 3);
      expect(restored.durationMs, 12840);
      // date muss exakt erhalten bleiben (ms seit Epoch hin und zurück).
      expect(restored.date, date);
      expect(restored.date.millisecondsSinceEpoch, date.millisecondsSinceEpoch);
    });

    test('Negativtest/Edge: fromMap mit int-date ergibt korrektes DateTime, id null ohne Absturz',
        () {
      final ms = DateTime(2026, 1, 1).millisecondsSinceEpoch;
      final row = <String, dynamic>{
        'id': null, // Lauf noch nicht gespeichert
        'trackId': 5,
        'durationMs': 9999,
        'date': ms,
      };

      final run = Run.fromMap(row);

      expect(run.id, isNull); // kein Absturz trotz null-id
      expect(run.trackId, 5);
      expect(run.durationMs, 9999);
      expect(run.date, DateTime.fromMillisecondsSinceEpoch(ms));
    });
  });
}
