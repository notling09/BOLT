# CLAUDE.md – Projektkontext BOLT

> Diese Datei wird von Claude Code bei jeder Sitzung automatisch gelesen.
> Sie sorgt dafür, dass der Kontext erhalten bleibt, auch wenn ein Chat verloren geht.
> Bitte **vor jeder Antwort** diesen Kontext berücksichtigen.

---

## 1. Projektübersicht

**Name:** B.O.L.T. – Akronym für **B**eat. **O**utrun. **L**evel-up. **T**rack.

BOLT ist eine mobile **Sprint-Tracking-App mit Gamification**. Kernidee:
Nutzer vermessen eine eigene Sprintstrecke, sprinten sie ab, und das Smartphone
misst per GPS automatisch die Zeit, sobald das festgelegte Ziel erreicht wird.
Aus den erzielten Zeiten entsteht ein Spielfortschritt mit Erfahrungspunkten (XP)
und Level-ups.

Dies ist ein **Lern-/Schulprojekt** (IT-Ausbildung, Schweiz).

---

## 2. Kernfunktionen

- **Streckenvermessung:** Nutzer legen Start- und Zielpunkt fest; die App berechnet die Distanz.
- **Variabler Renn-Timer:** Der Countdown vor dem Start ist unterschiedlich lang
  (zufällige Verzögerung, z. B. 3–7 Sekunden), wie bei einem echten Rennen.
  Das verhindert, dass Nutzer im exakt richtigen Moment lostippen und sich einen Vorteil verschaffen.
- **Automatische Zeitmessung:** Sobald die Position des Handys den festgelegten
  Zielbereich (Zielradius) erreicht, stoppt die Zeit automatisch.
- **Gamification:** Aus den gemessenen Zeiten werden XP berechnet. Nutzer steigen
  Level auf, sehen Fortschritt und Bestzeiten – jeder Sprint wird zum Wettkampf gegen sich selbst.

---

## 3. Technologie-Stack

- **Framework:** Flutter (Cross-Platform für **Android UND iOS** aus einer Codebasis)
- **Sprache:** Dart
- **Geplante Packages:**
  - `geolocator` – GPS-Position, Distanzberechnung, Tracking
  - `permission_handler` – Standort-Berechtigungen
  - `riverpod` oder `provider` – State Management
  - `sqflite` oder `shared_preferences` – lokale Datenspeicherung (Bestzeiten, Level)

**Begründung der Framework-Wahl:** Flutter, weil die App auf Android und iOS laufen
soll. Reines Kotlin wäre Android-only gewesen; zwei native Apps (Kotlin + Swift)
wären für ein Lernprojekt zu aufwändig. Flutter deckt beide Plattformen aus einer
Codebasis ab und bietet starke UI-Möglichkeiten für die Gamification-Animationen.

**Plattform-Fokus:** Zuerst auf **Android** entwickeln und testen. iOS später
(benötigt einen Mac mit Xcode). Web/Desktop sind **nicht** Ziel – können in der
Projektkonfiguration deaktiviert werden.

---

## 4. Datenhaltung & Backend

- **Kein Backend** geplant – alles läuft **lokal** auf dem Gerät.
- Lokale Speicherung von Bestzeiten, Strecken und Spielfortschritt via
  `sqflite` (strukturiert) oder `shared_preferences` (einfache Werte).
- **Keine Authentifizierung** nötig (Single-User, lokal).

---

## 5. Projektstruktur (Zielbild)

```
bolt/
├── lib/
│   ├── main.dart                 # Einstiegspunkt
│   ├── models/
│   │   ├── track.dart            # Strecke (Start, Ziel, Distanz)
│   │   ├── run.dart              # Einzelner Lauf (Zeit, Datum)
│   │   └── player.dart           # Level, XP, Fortschritt
│   ├── screens/
│   │   ├── home_screen.dart      # Übersicht / Hauptmenü
│   │   ├── measure_screen.dart   # Strecke vermessen
│   │   ├── race_screen.dart      # Countdown + Sprint + Zeitmessung
│   │   └── profile_screen.dart   # Level, Statistiken, Bestzeiten
│   ├── services/
│   │   ├── location_service.dart # GPS-Tracking & Distanzberechnung
│   │   ├── timer_service.dart    # Variabler Countdown + Stoppuhr
│   │   └── game_service.dart     # XP-Berechnung, Level-up-Regeln
│   └── widgets/                  # Wiederverwendbare UI-Bausteine
└── pubspec.yaml                  # Abhängigkeiten
```

---

## 6. Entwicklungsreihenfolge (Phasen)

Eine Phase nach der anderen – nicht alles auf einmal.

1. **Setup:** Flutter-Setup + lauffähiges „Hello World" auf Android.
2. **GPS-Grundlagen:** aktuelle Position anzeigen, Berechtigungen handhaben.
3. **Streckenvermessung:** Start-/Zielpunkt erfassen, Distanz berechnen (`Geolocator.distanceBetween`).
4. **Timer-Logik:** variabler Countdown (zufällig 3–7 Sek) + Stoppuhr.
5. **Zielerkennung:** Position im Zielradius prüfen → Zeit stoppen.
6. **Gamification:** XP aus Zeiten berechnen, Level-System, Fortschritt speichern.
7. **UI-Politur:** Level-up-Animationen, Design.
8. **iOS-Test:** sofern ein Mac verfügbar ist.

**Aktueller Stand:** Phase 1 (frisches, leeres Flutter-Projekt mit Standard-Counter-Demo).

---

## 7. Bekannte Herausforderungen / offene Punkte

- **GPS-Präzision:** Smartphone-GPS hat typischerweise ±3–5 m Ungenauigkeit. Bei kurzen
  Sprints (z. B. 50–100 m) kann das die Zeitmessung verfälschen. Lösungsansätze für
  *später*: Glättung/Filterung (z. B. Kalman-Filter), Mindeststrecken, Kombination mit
  Beschleunigungssensor (Sensor-Fusion).
- **Native Präzision via Platform Channels:** Falls die GPS-Präzision mit `geolocator`
  nicht ausreicht, ist geplant, den GPS/Sensor-Teil über **Platform Channels** an
  nativen Code (Kotlin/Swift) anzubinden. Bewusst eine **spätere** Option, kein
  initialer Bestandteil.
- **iOS-Deployment:** Für iOS-Builds wird zwingend ein Mac mit Xcode benötigt. Mit
  kostenloser Apple-ID ist Testen auf dem eigenen iPhone möglich, aber das
  Provisioning-Profil läuft nach 7 Tagen ab. App-Store-Veröffentlichung benötigt einen
  Apple Developer Account (99 USD/Jahr).
- **Hintergrund-Tracking & Akku:** Dauerhaftes GPS-Tracking belastet den Akku;
  Energiemanagement beachten.

---

## 8. Arbeitsweise (WICHTIG – comprehension-first)

- **Erkläre jeden Schritt, bevor du Code schreibst.** Ich will verstehen, was passiert,
  nicht blind Code übernehmen.
- **Gib nicht alles auf einmal aus.** Gehe Phase für Phase vor.
- **Stelle sicher, dass ich jeden Teil nachvollziehe**, bevor wir weitergehen.
- Kein undiszipliniertes „Vibe-Coding" – Verständnis vor Geschwindigkeit.
- Bei Konzepten (GPS-Filterung, Timer-Logik, XP-Formeln) lieber erst das Konzept
  erklären, dann gemeinsam umsetzen.

---

## 9. Sprache

- Antworten bevorzugt auf **Deutsch**.
- Englische Fachbegriffe sind erlaubt und erwünscht (Stack, State Management, etc.).
