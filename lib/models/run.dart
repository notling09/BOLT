/// Ein einzelner absolvierter Sprint.
///
/// Entspricht "Läufe" aus dem Konzept (Kapitel 7.1):
/// gemessene Zeit, Datum und zugehörige Strecke.
class Run {
  /// Datenbank-ID. `null`, solange der Lauf noch nicht gespeichert wurde.
  final int? id;

  /// Verweis auf die Strecke, zu der dieser Lauf gehört (Track.id).
  /// So wissen wir, welcher Lauf zu welcher Strecke zählt.
  final int trackId;

  /// Gemessene Zeit in **Millisekunden**.
  ///
  /// Warum ms und nicht z. B. Sekunden als Kommazahl?
  /// Die App zeigt Hundertstel an (z. B. 12.84s, siehe Mockup S. 10).
  /// Ganze Millisekunden sind exakt und vermeiden Rundungsfehler von double.
  /// 12.84 s  ->  12840 ms.
  final int durationMs;

  /// Zeitpunkt des Laufs (für "Letzte Läufe" und Statistik).
  final DateTime date;

  const Run({
    this.id,
    required this.trackId,
    required this.durationMs,
    required this.date,
  });
}
