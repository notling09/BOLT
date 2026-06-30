/// Der Spielfortschritt des Nutzers (Gamification).
///
/// Entspricht "Level und XP" aus dem Konzept (Kapitel 7.1).
/// Wird als einfacher Wert über shared_preferences gespeichert –
/// kein sqflite nötig, weil es nur EINEN Spieler gibt (Single-User-App).
class Player {
  /// Gesammelte Erfahrungspunkte (XP) über alle Läufe.
  final int xp;

  /// Aktuelles Level.
  ///
  /// Hinweis: Das Level lässt sich später auch aus der XP *berechnen*
  /// (z. B. alle 500 XP ein Level-up, siehe Mockup S. 9). Wir speichern es
  /// hier trotzdem direkt, wie im Konzept vorgesehen. Die genaue
  /// Level-Formel kommt später in den game_service.
  final int level;

  const Player({
    this.xp = 0,
    this.level = 1,
  });
}
