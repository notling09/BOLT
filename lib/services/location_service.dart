import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Ergebnis-Status einer Standort-Abfrage.
///
/// Die UI entscheidet anhand dieses Status, welche (freundliche) Meldung sie
/// zeigt – sie muss die GPS-Logik selbst nicht kennen (saubere Trennung).
enum LocationStatus {
  /// Position erfolgreich erhalten.
  success,

  /// Der GPS-Dienst des Geräts ist ausgeschaltet (separater Schalter!).
  serviceDisabled,

  /// Der Nutzer hat die Berechtigung (dieses Mal) abgelehnt.
  permissionDenied,

  /// Der Nutzer hat dauerhaft "Nein" gesagt. Ein erneutes Anfragen zeigt
  /// KEIN Popup mehr – nur über die App-Einstellungen lösbar.
  permissionDeniedForever,
}

/// Das, was eine Standort-Abfrage zurückgibt: ein Status und – im Erfolgsfall –
/// die Position.
class LocationResult {
  final LocationStatus status;
  final Position? position;

  const LocationResult(this.status, [this.position]);

  bool get isSuccess => status == LocationStatus.success;
}

/// Kapselt allen Zugriff auf GPS/Standort an EINER Stelle.
///
/// Basis für Phase 3 ("Strecke vermessen", UC1) und Phase 5 (automatische
/// Zeitmessung am Ziel, UC2).
class LocationService {
  /// Holt EINE aktuelle Position und durchläuft dabei den kompletten
  /// Berechtigungs-Entscheidungsbaum (siehe CLAUDE.md / Konzept US1).
  Future<LocationResult> getCurrentPosition() async {
    // 1. Ist der GPS-Dienst am Gerät überhaupt eingeschaltet?
    //    (Unabhängig von der App-Berechtigung – zwei getrennte Schalter.)
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(LocationStatus.serviceDisabled);
    }

    // 2. Welchen Berechtigungs-Status hat unsere App?
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Noch nie gefragt → jetzt das System-Popup auslösen.
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationStatus.permissionDenied);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Sackgasse: nur über die Einstellungen wieder freischaltbar.
      return const LocationResult(LocationStatus.permissionDeniedForever);
    }

    // 3. Berechtigung vorhanden (whileInUse oder always) → Position auslesen.
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        // bestForNavigation nutzt die GNSS-Sensoren (inkl. Dual-Frequency
        // L1+L5) maximal aus – die schaerfste Stufe fuer kurze Sprints.
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
    return LocationResult(LocationStatus.success, position);
  }

  /// Live-Strom von Positionen für die kontinuierliche Anzeige/Tracking.
  ///
  /// Voraussetzung: Berechtigung wurde bereits erteilt (z. B. zuvor über
  /// [getCurrentPosition] sichergestellt). `distanceFilter: 0` = jede
  /// Änderung melden, damit der Test-Screen wirklich "live" wirkt.
  Stream<Position> positionStream() {
    // AndroidSettings erlaubt ein festes Update-Intervall. 500 ms statt der
    // ueblichen 1–2 s -> haeufigere, feinere Updates fuer die Live-Distanz.
    return Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0, // jede noch so kleine Bewegung melden
        intervalDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  /// Öffnet die System-Einstellungen der App, damit der Nutzer eine dauerhaft
  /// verweigerte Standort-Berechtigung wieder freigeben kann.
  /// (Hier nutzen wir bewusst `permission_handler`.)
  Future<void> openAppSettings() => ph.openAppSettings();
}
