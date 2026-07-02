import 'dart:math';

import 'package:bolt/services/timer_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit-Tests für den variablen Renn-Countdown (Fairness: 3–7 s zufällig).
void main() {
  group('TimerService.randomCountdownSeconds', () {
    test('Positivtest: Wert liegt immer zwischen 3 und 7 Sekunden', () {
      final service = TimerService();
      for (var i = 0; i < 1000; i++) {
        expect(service.randomCountdownSeconds(), inInclusiveRange(3, 7));
      }
    });

    test('Negativtest: nie ein Wert ausserhalb 3..7 (deterministisch geprüft)',
        () {
      // Random(seed) ist reproduzierbar – über viele Seeds darf NIE ein
      // ungültiger Countdown (z. B. 2 oder 8) entstehen.
      for (var seed = 0; seed < 500; seed++) {
        final service = TimerService(random: Random(seed));
        final value = service.randomCountdownSeconds();
        expect(value < 3 || value > 7, isFalse,
            reason: 'seed=$seed ergab ungültigen Countdown $value');
      }
    });
  });
}
