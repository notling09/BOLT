import 'package:bolt/widgets/rank_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Snapshot-/Golden-Test: Der RankBadge muss optisch dem Referenzbild
/// (goldens/rank_badge.png) entsprechen. Ändert sich das Aussehen ungewollt,
/// schlägt der Test fehl.
void main() {
  testWidgets('Snapshot: RankBadge entspricht dem Referenzbild',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: RankBadge(level: 2)),
        ),
      ),
    );

    await expectLater(
      find.byType(RankBadge),
      matchesGoldenFile('goldens/rank_badge.png'),
    );
  });
}
