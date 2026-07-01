# Lottie-Animationen

Hier gehören die Lottie-JSON-Dateien hin. Erwartete Dateien:

- `runner.json` – rennender Mann. Wird verwendet für:
  - den **Splash-Screen** beim App-Start (`lib/screens/splash_screen.dart`)
  - die **Mess-Animation** während der GPS-Punkterfassung (`lib/screens/measure_screen.dart`)

Solange die Datei fehlt, zeigen beide Stellen einen Fallback (Logo bzw.
Ladeindikator) – die App stürzt nicht ab.

Kostenlose Animationen z. B. auf https://lottiefiles.com (Suche: "running man").
Datei herunterladen (Lottie JSON) und als `runner.json` hier ablegen.
