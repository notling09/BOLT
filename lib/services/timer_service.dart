import 'dart:async';
import 'dart:math';

/// Renn-Zeitlogik für Phase 4 (UC2 / User-Story 2):
/// variabler Countdown + präzise Stoppuhr.
///
/// Bewusst Flutter-frei (nur dart:async / dart:math), damit der Service
/// unabhängig testbar bleibt. Die UI-Aktualisierung (Anzeige-Ticker)
/// liegt im Screen, nicht hier.
class TimerService {
  /// Injizierbar, damit man den Zufall in Tests deterministisch machen kann.
  final Random _random;

  /// Zeitquelle für die laufende Sprintzeit. Stopwatch liest eine
  /// hochauflösende, monotone Systemuhr → driftet nicht (anders als das
  /// Aufsummieren von Timer-Ticks).
  final Stopwatch _stopwatch = Stopwatch();

  /// Der herunterzählende Sekunden-Timer.
  Timer? _countdownTimer;

  TimerService({Random? random}) : _random = random ?? Random();

  /// Zufällige Countdown-Dauer in GANZEN Sekunden zwischen 3 und 7.
  ///
  /// Zweck (Fairness): Der Startmoment darf nicht vorhersehbar sein, sonst
  /// könnte der Nutzer den Sprint "timen" und sich einen Vorteil verschaffen.
  /// Ganze Sekunden 3–7 sind dafür unvorhersehbar genug; Millisekunden-Zufall
  /// brächte keinen zusätzlichen Fairness-Gewinn.
  int randomCountdownSeconds() => 3 + _random.nextInt(5); // 3, 4, 5, 6 oder 7

  /// Startet einen Sekunden-Countdown.
  ///
  /// [onTick] erhält bei jedem Schritt die verbleibenden Sekunden (>= 1).
  /// [onFinished] feuert genau einmal, wenn 0 erreicht ist (= "GO").
  void startCountdown({
    required int seconds,
    required void Function(int remaining) onTick,
    required void Function() onFinished,
  }) {
    _countdownTimer?.cancel();
    var remaining = seconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      if (remaining > 0) {
        onTick(remaining);
      } else {
        timer.cancel();
        onFinished();
      }
    });
  }

  /// Bricht einen laufenden Countdown ab (z. B. beim Verlassen des Screens).
  void cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Startet die Stoppuhr von 0 (ab dem Startsignal aufgerufen).
  void startStopwatch() {
    _stopwatch
      ..reset()
      ..start();
  }

  /// Stoppt die Stoppuhr (in Phase 5 bei Zielerkennung, hier beim Abbrechen).
  void stopStopwatch() => _stopwatch.stop();

  /// Aktuelle Sprintzeit in Millisekunden – passend zum Run-Modell (Zeit in ms).
  int get elapsedMs => _stopwatch.elapsedMilliseconds;

  /// Alles beenden – im dispose() des Screens aufrufen, damit nichts im
  /// Hintergrund weiterläuft.
  void dispose() {
    _countdownTimer?.cancel();
    _stopwatch.stop();
  }
}
