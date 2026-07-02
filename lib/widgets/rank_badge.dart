import 'package:flutter/material.dart';

/// Kleiner Level-Badge „LV.x" im Amber-Stil (z. B. im Hauptmenü).
///
/// Bewusst rein darstellend und ohne Abhängigkeiten – dadurch wiederverwendbar
/// und gut per Snapshot-/Golden-Test prüfbar.
class RankBadge extends StatelessWidget {
  final int level;

  const RankBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'LV.$level',
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
