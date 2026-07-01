import 'package:flutter/material.dart';

/// Kleines, wiederverwendbares Badge für das aktuelle Level ("LV.4").
///
/// Bewusst service-frei und rein präsentativ – dadurch gut per Snapshot-
/// (Golden-)Test prüfbar und in Home-/Statistik-Screen wiederverwendbar.
class LevelBadge extends StatelessWidget {
  final int level;

  const LevelBadge({super.key, required this.level});

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
