/// Ein einzelner absolvierter Sprint.
///
/// Entspricht "Läufe" aus dem Konzept (Kapitel 7.1):
/// gemessene Zeit, Datum und zugehörige Strecke.
class Run {
  /// Datenbank-ID. `null`, solange der Lauf noch nicht gespeichert wurde.
  final int? id;

  /// Verweis auf die Strecke, zu der dieser Lauf gehört (Track.id).
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

  /// Für sqflite INSERT: DateTime als int (ms seit Epoch), id weglassen.
  Map<String, dynamic> toMap() => {
        'trackId': trackId,
        'durationMs': durationMs,
        'date': date.millisecondsSinceEpoch,
      };

  /// Aus einer sqflite-Zeile ein Run-Objekt bauen.
  factory Run.fromMap(Map<String, dynamic> map) => Run(
        id: map['id'] as int?,
        trackId: map['trackId'] as int,
        durationMs: map['durationMs'] as int,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      );
}
