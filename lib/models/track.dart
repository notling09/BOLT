/// Eine vom Nutzer vermessene Sprintstrecke.
///
/// Entspricht "Strecken" aus dem Konzept (Kapitel 7.1):
/// Name, Start- und Zielkoordinaten sowie die berechnete Distanz.
class Track {
  /// Datenbank-ID. `null`, solange die Strecke noch nicht gespeichert wurde.
  /// (sqflite vergibt die ID erst beim Einfügen.)
  final int? id;

  /// Anzeigename, z. B. "Schulhof Sprint" (siehe Mockup S. 9).
  final String name;

  // Startpunkt als GPS-Koordinaten.
  final double startLat;
  final double startLng;

  // Zielpunkt als GPS-Koordinaten.
  final double endLat;
  final double endLng;

  /// Distanz in Metern, von der App berechnet (Geolocator.distanceBetween).
  final double distanceMeters;

  const Track({
    this.id,
    required this.name,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.distanceMeters,
  });
}
