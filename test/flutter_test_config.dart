import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wird von `flutter test` automatisch geladen und umschliesst alle Tests.
///
/// Wir ersetzen den Standard-Golden-Vergleicher durch einen mit kleiner
/// Toleranz. Grund: Golden-Bilder können sich zwischen Windows (lokal) und
/// Linux (GitLab-CI) durch minimale Rendering-Unterschiede unterscheiden.
/// So scheitert die Pipeline nicht an Pixel-Kleinkram, echte optische
/// Änderungen fallen aber weiterhin auf.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final previous = goldenFileComparator;
  if (previous is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenComparator(previous.basedir);
  }
  await testMain();
}

class _TolerantGoldenComparator extends LocalFileComparator {
  _TolerantGoldenComparator(Uri baseDir)
      : super(baseDir.resolve('flutter_test_config.dart'));

  /// Maximal erlaubte Abweichung (2 %).
  static const double _threshold = 0.02;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _threshold) {
      return true;
    }
    throw FlutterError(await generateFailureOutput(result, golden, basedir));
  }
}
