import 'package:bolt/models/track.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit-Tests der Track-Serialisierung (toMap/fromMap, reine Dart-Logik).
void main() {
  group('Track Serialisierung', () {
    test('Positivtest: toMap -> fromMap erhält alle Felder (Round-Trip)', () {
      const track = Track(
        name: 'Schulhof Sprint',
        startLat: 46.9481,
        startLng: 7.4474,
        endLat: 46.9490,
        endLng: 7.4480,
        distanceMeters: 105.5,
        isTemplate: false,
      );

      // Die DB vergibt die id erst beim Insert – hier simuliert.
      final row = {...track.toMap(), 'id': 1};
      final restored = Track.fromMap(row);

      expect(restored.id, 1);
      expect(restored.name, 'Schulhof Sprint');
      expect(restored.startLat, 46.9481);
      expect(restored.endLng, 7.4480);
      expect(restored.distanceMeters, 105.5);
      expect(restored.isTemplate, false);
    });

    test('Negativtest: fehlende isTemplate-Spalte (alte DB) -> false statt Absturz',
        () {
      final row = {
        'id': 2,
        'name': 'Alte Strecke',
        'startLat': 0.0,
        'startLng': 0.0,
        'endLat': 0.0,
        'endLng': 0.0,
        'distanceMeters': 50.0,
        // Bewusst KEIN 'isTemplate' (wie bei einer alten DB-Version).
      };

      final track = Track.fromMap(row);
      expect(track.isTemplate, false);
      expect(track.distanceMeters, 50.0);
    });
  });
}
