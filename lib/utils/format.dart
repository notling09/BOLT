/// Gemeinsame Formatierungs-Helfer für Zeit und Datum.
///
/// Diese Funktionen lagen vorher als private `_formatTime` / `_formatDate`
/// mehrfach (kopiert) in einzelnen Screens. Jetzt stehen sie an EINER Stelle –
/// wer die Darstellung ändern will, ändert sie nur hier.
library;

/// Millisekunden als Stoppuhr-Zeit `MM:SS.hh` (hh = Hundertstel).
///
/// Beispiel: 12840 ms → `00:12.84`. Bewusst mit Hundertsteln, weil die App
/// Sprintzeiten so genau anzeigt (siehe Konzept / Mockup S. 10).
String formatTime(int ms) {
  final d = Duration(milliseconds: ms);
  final min = d.inMinutes.toString().padLeft(2, '0');
  final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
  final hund = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
  return '$min:$sec.$hund';
}

/// Kurzes Datum `DD.MM.YYYY` (ohne Uhrzeit).
String formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

/// Datum mit Uhrzeit `DD.MM.YYYY  HH:MM`.
String formatDateWithTime(DateTime date) {
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '${formatDate(date)}  $hh:$mm';
}

/// Datum relativ zu heute: `Heute, HH:MM` / `Gestern, HH:MM` / sonst `DD.MM.YYYY`.
///
/// Praktisch für "Letzte Läufe", damit frische Einträge sofort erkennbar sind.
String formatDateRelative(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final runDay = DateTime(date.year, date.month, date.day);
  final diffDays = today.difference(runDay).inDays;

  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  final time = '$hh:$mm';

  if (diffDays == 0) return 'Heute, $time';
  if (diffDays == 1) return 'Gestern, $time';
  return formatDate(date);
}
