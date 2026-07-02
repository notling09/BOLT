import 'package:bolt/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit-Tests für die Zeit-Formatierung `formatTime` aus lib/utils/format.dart.
///
/// formatTime wandelt Millisekunden in das Stoppuhr-Format `MM:SS.hh` um
/// (hh = Hundertstel). Diese Funktion ist reine Logik ohne UI → ideal für
/// schnelle Unit-Tests.
void main() {
  group('formatTime', () {
    test('Positivtest: 12840 ms ergibt "00:12.84"', () {
      // 12,84 Sekunden → 12 Sekunden und 84 Hundertstel.
      expect(formatTime(12840), '00:12.84');
    });

    test('Positivtest: 65430 ms ergibt "01:05.43"', () {
      // 65,43 s → 1 Minute, 5 Sekunden, 43 Hundertstel (Minuten-Übertrag).
      expect(formatTime(65430), '01:05.43');
    });

    test('Negativtest/Edge: 0 ms ergibt "00:00.00"', () {
      // Grenzfall: keine Zeit → alles auf Null, kein Absturz.
      expect(formatTime(0), '00:00.00');
    });
  });
}
