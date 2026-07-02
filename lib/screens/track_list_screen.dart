import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/database_service.dart';
import 'measure_screen.dart';
import 'race_screen.dart';
import 'track_detail_screen.dart';

/// Zeigt alle gespeicherten Strecken an (US6: Strecke speichern / wählen).
///
/// Der Nutzer wählt eine Strecke aus der Liste und startet damit direkt
/// den RaceScreen mit der echten gespeicherten Strecke (inkl. DB-id).
class TrackListScreen extends StatefulWidget {
  const TrackListScreen({super.key});

  @override
  State<TrackListScreen> createState() => _TrackListScreenState();
}

class _TrackListScreenState extends State<TrackListScreen> {
  final _db = DatabaseService.instance;

  List<Track>? _tracks; // null = wird noch geladen
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _tracks = null;
      _hasError = false;
    });
    try {
      final tracks = await _db.getTracks();
      if (!mounted) return;
      setState(() => _tracks = tracks);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  void _startSprint(Track track) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RaceScreen(track: track)),
    );
  }

  /// Übersicht zur Strecke öffnen (Karte, Bestzeit, Neu-vermessen); danach
  /// die Liste neu laden, weil die Strecke geändert worden sein könnte.
  Future<void> _openDetail(Track track) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrackDetailScreen(track: track)),
    );
    await _loadTracks();
  }

  /// Zum Vermessen-Screen wechseln; nach Rückkehr Streckenliste neu laden.
  Future<void> _openMeasure() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MeasureScreen()),
    );
    await _loadTracks();
  }

  /// Auswahl beim "+"-Button: GPS-Strecke vermessen oder eigene Distanz eingeben.
  void _showAddOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.place, color: Colors.amber),
              title: const Text('Strecke vermessen'),
              subtitle: const Text('Start- und Zielpunkt per GPS ablaufen'),
              onTap: () {
                Navigator.pop(ctx);
                _openMeasure();
              },
            ),
            ListTile(
              leading: const Icon(Icons.straighten, color: Colors.amber),
              title: const Text('Eigene Distanz'),
              subtitle: const Text('Distanz direkt eingeben (z. B. 1000 m)'),
              onTap: () {
                Navigator.pop(ctx);
                _addCustom();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Custom-Strecke: Name + Distanz eingeben, als Distanz-Strecke speichern.
  ///
  /// isTemplate = true → beim Sprint wird distanz-basiert gestoppt (kein
  /// GPS-Ziel), genau wie bei den Vorgaben. Koordinaten bleiben 0.
  Future<void> _addCustom() async {
    final result = await showDialog<({String name, double distance})>(
      context: context,
      builder: (_) => const _CustomTrackDialog(),
    );
    if (result == null) return;

    await _db.insertTrack(Track(
      name: result.name,
      startLat: 0,
      startLng: 0,
      endLat: 0,
      endLng: 0,
      distanceMeters: result.distance,
      isTemplate: true,
    ));
    await _loadTracks();
  }

  /// Dialog zum Umbenennen einer Strecke.
  Future<void> _renameTrack(Track track) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initialName: track.name),
    );

    if (newName == null || newName.isEmpty || track.id == null) return;
    await _db.updateTrackName(track.id!, newName);
    await _loadTracks();
  }

  /// Bestätigungs-Dialog und Löschen einer Strecke (inkl. ihrer Läufe).
  Future<void> _deleteTrack(Track track) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Strecke löschen?'),
        content: Text(
          '«${track.name}» und alle zugehörigen Läufe werden gelöscht. '
          'Das kann nicht rückgängig gemacht werden.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true || track.id == null) return;
    await _db.deleteTrack(track.id!);
    await _loadTracks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'STRECKEN',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.amber,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddOptions,
            tooltip: 'Strecke hinzufügen',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTracks,
            tooltip: 'Aktualisieren',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return _buildCentered(
        icon: Icons.error_outline,
        text: 'Fehler beim Laden der Strecken.',
        button: ('Erneut versuchen', _loadTracks),
      );
    }

    if (_tracks == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.amber));
    }

    if (_tracks!.isEmpty) {
      return _buildCentered(
        icon: Icons.place_outlined,
        text: 'Noch keine Strecken vorhanden.',
        button: ('Strecke hinzufügen', _showAddOptions),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tracks!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildTrackCard(_tracks![i]),
    );
  }

  Widget _buildTrackCard(Track track) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () => _openDetail(track),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          track.isTemplate ? Icons.straighten : Icons.place,
          color: Colors.amber,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                track.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (track.isTemplate) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DISTANZ',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${track.distanceMeters.toStringAsFixed(track.isTemplate ? 0 : 1)} m',
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _startSprint(track),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('SPRINT'),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white54),
              color: Colors.grey[850],
              onSelected: (value) {
                if (value == 'rename') _renameTrack(track);
                if (value == 'delete') _deleteTrack(track);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Text('Umbenennen'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.redAccent, size: 18),
                      SizedBox(width: 8),
                      Text('Löschen'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCentered({
    required IconData icon,
    required String text,
    (String, VoidCallback)? button,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.amber),
            const SizedBox(height: 24),
            Text(text, textAlign: TextAlign.center),
            if (button != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: button.$2,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                ),
                child: Text(button.$1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Umbenennen-Dialog, der seinen TextEditingController selbst verwaltet.
///
/// Wichtig: Der Controller wird im dispose() dieses Widgets freigegeben – erst
/// wenn das Textfeld wirklich aus dem Baum ist. (Frühere Freigabe direkt nach
/// showDialog löste den Fehler «_dependents.isEmpty is not true» aus.)
class _RenameDialog extends StatefulWidget {
  final String initialName;

  const _RenameDialog({required this.initialName});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Strecke umbenennen'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(color: Colors.white),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
        decoration: const InputDecoration(
          hintText: 'Neuer Name',
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.amber),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Speichern', style: TextStyle(color: Colors.amber)),
        ),
      ],
    );
  }
}

/// Dialog für eine eigene Distanz-Strecke: Name (optional) + Distanz in Metern.
///
/// Gibt bei "Speichern" einen Record `(name, distance)` zurück – aber nur,
/// wenn die Distanz eine gültige positive Zahl ist. Sonst wird ein Fehler
/// im Dialog angezeigt.
class _CustomTrackDialog extends StatefulWidget {
  const _CustomTrackDialog();

  @override
  State<_CustomTrackDialog> createState() => _CustomTrackDialogState();
}

class _CustomTrackDialogState extends State<_CustomTrackDialog> {
  final _nameController = TextEditingController();
  final _distanceController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  void _submit() {
    // Komma oder Punkt als Dezimaltrenner erlauben.
    final raw = _distanceController.text.trim().replaceAll(',', '.');
    final distance = double.tryParse(raw);

    if (distance == null || distance < 25) {
      setState(() => _error =
          'Bitte mindestens 25 m eingeben – kürzere Distanzen sind zu ungenau.');
      return;
    }

    final name = _nameController.text.trim();
    Navigator.pop(context, (
      name: name.isEmpty ? '${distance.round()} Meter' : name,
      distance: distance,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Eigene Distanz'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              hintText: 'z. B. Parkstrecke',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.amber),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _distanceController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Distanz in Metern (min. 25)',
              hintText: 'z. B. 1000',
              errorText: _error,
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.amber),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Speichern', style: TextStyle(color: Colors.amber)),
        ),
      ],
    );
  }
}
