import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/garden_project.dart';

/// Ergebnis des Ladens: gültige Projekte plus Hinweise auf beschädigte Dateien.
class LoadResult {
  const LoadResult({required this.projects, required this.corruptFiles});
  final List<GardenProject> projects;
  final List<String> corruptFiles;
}

/// Speichert jedes Projekt als eigene JSON-Datei im App-Dokumentenverzeichnis.
///
/// Schreibvorgänge sind atomar: Es wird zuerst in eine temporäre Datei
/// geschrieben und diese anschließend über die Zieldatei verschoben. Ein
/// abgebrochener Schreibvorgang lässt die bisherige Datei unverändert.
class ProjectRepository {
  ProjectRepository({Directory? baseDirectory}) : _baseOverride = baseDirectory;

  final Directory? _baseOverride;
  Directory? _dir;

  /// Verzeichnis, in dem die Projektdateien liegen.
  Future<Directory> baseDirectory() => _directory();

  Future<Directory> _directory() async {
    if (_dir != null) return _dir!;
    final base = _baseOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}gardens');
    if (!await dir.exists()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  File _fileFor(Directory dir, String id) =>
      File('${dir.path}${Platform.pathSeparator}${_safeName(id)}.json');

  /// IDs werden auf Dateisystem-sichere Zeichen reduziert.
  static String _safeName(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');

  Future<LoadResult> loadAll() async {
    final dir = await _directory();
    final projects = <GardenProject>[];
    final corrupt = <String>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final text = await entity.readAsString();
        final decoded = jsonDecode(text);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Kein JSON-Objekt.');
        }
        projects.add(GardenProject.fromJson(decoded));
      } catch (_) {
        corrupt.add(entity.uri.pathSegments.last);
        // Beschädigte Datei zur Seite legen, damit sie nicht jedes Mal stört,
        // aber auch nicht verloren geht.
        try {
          await entity.rename('${entity.path}.defekt');
        } catch (_) {
          // Ignorieren – im schlimmsten Fall wird sie beim nächsten Start
          // erneut gemeldet.
        }
      }
    }
    projects.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return LoadResult(projects: projects, corruptFiles: corrupt);
  }

  Future<void> save(GardenProject project) async {
    final dir = await _directory();
    final target = _fileFor(dir, project.id);
    final temp = File('${target.path}.tmp');
    final text = const JsonEncoder.withIndent('  ').convert(project.toJson());
    await temp.writeAsString(text, flush: true);
    await temp.rename(target.path);
  }

  File _sampleMarker(Directory dir) =>
      File('${dir.path}${Platform.pathSeparator}.sample_removed');

  /// Wurde der Beispielgarten vom Nutzer gelöscht? Dann nicht neu anlegen.
  Future<bool> isSampleRemoved() async =>
      _sampleMarker(await _directory()).exists();

  Future<void> markSampleRemoved() async =>
      _sampleMarker(await _directory()).writeAsString('1', flush: true);

  Future<void> delete(String id) async {
    final dir = await _directory();
    final f = _fileFor(dir, id);
    if (await f.exists()) await f.delete();
  }

  /// Serialisiert ein Projekt für den Export.
  static String exportJson(GardenProject project) =>
      const JsonEncoder.withIndent('  ').convert(project.toJson());

  /// Liest ein exportiertes Projekt. Wirft [FormatException] bei Fehlern.
  static GardenProject importJson(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Die Datei enthält kein Gartenprojekt.');
    }
    return GardenProject.fromJson(decoded);
  }
}
