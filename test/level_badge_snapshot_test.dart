import 'package:bolt/widgets/level_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Snapshot- (Golden-) Test: rendert das LevelBadge und vergleicht es mit
/// einem Referenzbild (test/goldens/level_badge.png).
///
/// Referenzbild erzeugen/aktualisieren:
///   flutter test --update-goldens
void main() {
  testWidgets('Snapshot: LevelBadge entspricht dem Referenzbild', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: LevelBadge(level: 4)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(LevelBadge),
      matchesGoldenFile('goldens/level_badge.png'),
    );
  });
}
