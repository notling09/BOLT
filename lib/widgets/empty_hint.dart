import 'package:flutter/material.dart';

/// Wiederverwendbarer "Leer"-Hinweis: grauer Kasten mit Icon und Text.
///
/// Wird z. B. angezeigt, wenn zu einer Strecke noch keine Läufe existieren.
/// Rein präsentativ (kein Service) – dadurch gut per Snapshot-Test prüfbar.
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyHint({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white24, size: 40),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
