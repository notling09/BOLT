# B.O.L.T – Break Old Limits Today

Mobile **Sprint-Tracking-App mit Gamification** (Modul M335, ICT-LearnFactory).
Nutzer vermessen per GPS eine eigene Sprintstrecke, sprinten sie ab, und die App
misst die Zeit **automatisch**, sobald das Ziel erreicht ist. Aus den Zeiten
entstehen Erfahrungspunkte (XP) und Level-Ups.

- **Framework:** Flutter (Dart) · **Zielplattform:** Android (iOS vorbereitet)
- **Team:** Michael Bergamin, Nilton Barroso Carvalho, Thierry Oesch

---

## Starten (Entwicklung)

Voraussetzungen: Flutter SDK (stable), ein Android-Gerät mit aktiviertem
USB-Debugging (oder Emulator – GPS dann simulieren).

```bash
flutter pub get
flutter run
```

Beim allerersten Build lädt Gradle Android-SDK/NDK-Komponenten nach – das kann
einige Minuten dauern.

## Installierbare APK bauen

```bash
flutter build apk --release
```

Die fertige Datei liegt unter
`build/app/outputs/flutter-apk/app-release.apk` und kann direkt auf einem
Android-Gerät installiert werden.

## Tests ausführen

```bash
flutter test
```

Enthält Unit-Tests (XP-/Level-Logik, Streckenmodell) und einen Snapshot-/Golden-Test.

---

## Berechtigungen

| Berechtigung | Zweck | Pflicht? |
|---|---|---|
| **Standort (GPS)** | Strecke vermessen & automatische Zeitmessung | **Ja** |
| **Körperliche Aktivität** (Schrittzähler) | zweite Distanzquelle (Sensor-Fusion) | optional |
| **Internet** | Kartenkacheln (OpenStreetMap) beim Vermessen | für die Karte |

Beim ersten Nutzen fragt die App die Standort-Berechtigung an. Ohne Standort
funktioniert die Kernfunktion (Messen/Sprinten) nicht.

## Bedienung (Kurz)

- **Sprint:** Strecke wählen → *Sprint starten* → **kurz stillhalten** → beim
  **Beep** losrennen. Die Zeit stoppt automatisch am Ziel.
- **Strecke vermessen:** Startpunkt setzen → zum Ziel gehen → Zielpunkt setzen →
  speichern. Danach optional Start/Ziel tauschen.
- **Vorgaben:** 50/100/200/300 m sind bereits vorhanden (distanz-basiert).

## Wichtige Hinweise / bekannte Punkte (für die Bewertung)

- **Draussen testen:** GPS braucht freie Sicht zum Himmel. In Gebäuden ist die
  Messung ungenau. Die App wartet bewusst auf ein stabiles Signal.
- **Mindest-Distanz 25 m:** Kürzere eigene Strecken lassen sich nicht speichern,
  weil GPS-Rauschen (±3–5 m) sie zu ungenau macht.
- **Ton an:** Der Sprint-Start wird per **Beep** signalisiert. Ist das Gerät
  stumm, erscheint ein Hinweis, die Lautstärke zu aktivieren.
- **Nur Hochformat**, Smartphone (kein Tablet/Querformat).
- **Kein Backend, kein Login, kein Passwort:** Alle Daten (Strecken, Läufe,
  Level/XP) werden **lokal** gespeichert (sqflite + shared_preferences).

## Special Feature

Automatische Zeitmessung über **GPS** (Zielradius bzw. gelaufene Distanz),
ergänzt durch **Sensor-Fusion** (Beschleunigungssensor für Start-/Reaktions-
erkennung, Schrittzähler als zweite Distanzquelle).
