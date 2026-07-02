import 'package:bolt/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Snapshot-/Golden-Test: Die StatCard muss optisch dem Referenzbild
/// (goldens/stat_card.png) entsprechen. Ändert sich das Aussehen ungewollt,
/// schlägt der Test fehl.
///
/// Referenzbild erzeugen/aktualisieren:
///   flutter test --update-goldens test/stat_card_snapshot_test.dart
void main() {
  testWidgets('Snapshot: StatCard entspricht dem Referenzbild',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: StatCard(label: 'BESTZEIT', value: '00:12.84'),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(StatCard),
      matchesGoldenFile('goldens/stat_card.png'),
    );
  });
}
