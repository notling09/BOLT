import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/run.dart';
import '../models/track.dart';

/// Kapselt allen Datenbankzugriff (sqflite) an einer Stelle.
///
/// Singleton-Muster: Die DB wird einmal geöffnet und danach wiederverwendet.
/// Tabellen: 'tracks' und 'runs' (Fremdschlüssel runs.trackId → tracks.id).
class DatabaseService {
  static DatabaseService? _instance;
  static Database? _db;

  DatabaseService._();

  static DatabaseService get instance => _instance ??= DatabaseService._();

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bolt.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tracks (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            name          TEXT    NOT NULL,
            startLat      REAL    NOT NULL,
            startLng      REAL    NOT NULL,
            endLat        REAL    NOT NULL,
            endLng        REAL    NOT NULL,
            distanceMeters REAL   NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE runs (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            trackId    INTEGER NOT NULL REFERENCES tracks(id),
            durationMs INTEGER NOT NULL,
            date       INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tracks
  // ---------------------------------------------------------------------------

  /// Strecke einfügen; gibt das gespeicherte Objekt MIT id zurück.
  Future<Track> insertTrack(Track track) async {
    final db = await database;
    final id = await db.insert('tracks', track.toMap());
    return Track(
      id: id,
      name: track.name,
      startLat: track.startLat,
      startLng: track.startLng,
      endLat: track.endLat,
      endLng: track.endLng,
      distanceMeters: track.distanceMeters,
    );
  }

  /// Alle gespeicherten Strecken laden (neueste zuerst).
  Future<List<Track>> getTracks() async {
    final db = await database;
    final rows = await db.query('tracks', orderBy: 'id DESC');
    return rows.map(Track.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Runs
  // ---------------------------------------------------------------------------

  /// Lauf einfügen; gibt das gespeicherte Objekt MIT id zurück.
  Future<Run> insertRun(Run run) async {
    final db = await database;
    final id = await db.insert('runs', run.toMap());
    return Run(
      id: id,
      trackId: run.trackId,
      durationMs: run.durationMs,
      date: run.date,
    );
  }

  /// Alle Läufe einer Strecke laden (schnellste zuerst).
  Future<List<Run>> getRunsForTrack(int trackId) async {
    final db = await database;
    final rows = await db.query(
      'runs',
      where: 'trackId = ?',
      whereArgs: [trackId],
      orderBy: 'durationMs ASC',
    );
    return rows.map(Run.fromMap).toList();
  }

  /// Bestzeit (kleinste durationMs) für eine Strecke – null wenn keine Läufe.
  Future<Run?> getBestRunForTrack(int trackId) async {
    final runs = await getRunsForTrack(trackId);
    return runs.isEmpty ? null : runs.first;
  }

  /// Die letzten Läufe über ALLE Strecken (neueste zuerst), inkl. Streckenname
  /// und Distanz – per JOIN, damit das Hauptmenü "Letzte Läufe" zeigen kann.
  Future<List<({Run run, String trackName, double distanceMeters})>>
      getRecentRuns({int limit = 5}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT runs.id, runs.trackId, runs.durationMs, runs.date,
             tracks.name AS trackName,
             tracks.distanceMeters AS trackDistance
      FROM runs
      JOIN tracks ON runs.trackId = tracks.id
      ORDER BY runs.date DESC
      LIMIT ?
    ''', [limit]);

    return rows
        .map((row) => (
              run: Run.fromMap(row),
              trackName: row['trackName'] as String,
              distanceMeters: row['trackDistance'] as double,
            ))
        .toList();
  }
}
