import 'package:bolt/widgets/empty_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Snapshot- (Golden-) Test für das EmptyHint-Widget.
///
/// Referenzbild erzeugen/aktualisieren:
///   flutter test --update-goldens test/empty_hint_snapshot_test.dart
void main() {
  testWidgets('Snapshot: EmptyHint entspricht dem Referenzbild', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Padding(
            padding: EdgeInsets.all(16),
            child: EmptyHint(
              icon: Icons.directions_run,
              text: 'Noch keine Läufe auf dieser Strecke.\nSprint starten!',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(EmptyHint),
      matchesGoldenFile('goldens/empty_hint.png'),
    );
  });
}
