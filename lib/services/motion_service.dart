import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Liest den Beschleunigungssensor (ohne Schwerkraft) und liefert die
/// Staerke der linearen Beschleunigung – Basis, um einen Sprint-START zu
/// erkennen: Eine harte Vorwaerts-Beschleunigung erzeugt einen grossen Ausschlag.
///
/// Gedacht als Ergaenzung zum GPS (Sensor-Fusion): Der Beschleunigungssensor
/// reagiert sofort (Millisekunden), waehrend GPS erst mit ~0.5–1 s nachzieht.
class MotionService {
  /// Ab dieser Staerke (m/s²) werten wir es als Sprint-Start.
  /// In Ruhe liegt der Wert bei ~0; ein kraeftiger Losstart erzeugt einen
  /// deutlichen Peak. Wert ist bewusst als Konstante zum Tunen ausgelegt.
  static const double startThreshold = 12.0;

  /// Strom der aktuellen Beschleunigungs-Staerke (Betrag |a|) in m/s².
  /// `userAccelerometer` = Beschleunigung OHNE Schwerkraft, daher in Ruhe ~0.
  Stream<double> accelerationMagnitude() {
    return userAccelerometerEventStream().map(
      (e) => sqrt(e.x * e.x + e.y * e.y + e.z * e.z),
    );
  }
}
