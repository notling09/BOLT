import 'package:flutter/material.dart';

/// Wiederverwendbare „Statistik-Kachel": ein kleines Label oben und ein
/// großer Amber-Wert darunter (z. B. DISTANZ · 120 m  oder  BESTZEIT · 00:12.84).
///
/// Diese Kachel war vorher als private `_statCard`-Methode direkt in einem
/// Screen gebaut. Als eigenständiges Widget ist sie wiederverwendbar und
/// per Snapshot-/Golden-Test prüfbar (rein darstellend, keine Abhängigkeiten).
class StatCard extends StatelessWidget {
  /// Kurze Überschrift, z. B. "DISTANZ".
  final String label;

  /// Der hervorgehobene Wert, z. B. "120 m" oder "00:12.84".
  final String value;

  const StatCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              // Monospace-Ziffern: Werte "zappeln" nicht beim Aktualisieren.
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
