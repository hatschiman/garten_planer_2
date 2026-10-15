import 'package:flutter/foundation.dart';

import 'models/garden_project.dart';
import 'models/ids.dart';
import 'models/sample_garden.dart';
import 'storage/project_repository.dart';

/// Verwaltet die Liste der Projekte und delegiert das Speichern.
class ProjectStore extends ChangeNotifier {
  ProjectStore(this.repository);

  final ProjectRepository repository;

  List<GardenProject> _projects = [];
  bool _loaded = false;
  List<String> _corruptFiles = [];
  String? _loadError;

  List<GardenProject> get projects => _projects;
  bool get isLoaded => _loaded;
  List<String> get corruptFiles => _corruptFiles;
  String? get loadError => _loadError;

  Future<void> load() async {
    try {
      final result = await repository.loadAll();
      _projects = result.projects;
      _corruptFiles = result.corruptFiles;
      _loadError = null;
      await _ensureSample();
    } catch (e) {
      _loadError = 'Projekte konnten nicht geladen werden: $e';
    }
    _loaded = true;
    notifyListeners();
  }

  /// Legt den Beispielgarten beim ersten Start an. Wird er gelöscht, bleibt
  /// er gelöscht (Marker-Datei).
  Future<void> _ensureSample() async {
    if (_projects.any((p) => p.id == kSampleProjectId)) return;
    if (await repository.isSampleRemoved()) return;
    final sample = buildSampleGarden();
    await repository.save(sample);
    _projects = [..._projects, sample];
  }

  void clearCorruptNotice() {
    _corruptFiles = [];
    notifyListeners();
  }

  Future<GardenProject> create({
    required String name,
    required double width,
    required double length,
  }) async {
    final now = DateTime.now();
    final p = GardenProject(
      id: newId('g-'),
      name: name.trim(),
      width: width,
      length: length,
      createdAt: now,
      modifiedAt: now,
    );
    await repository.save(p);
    _projects = [p, ..._projects];
    notifyListeners();
    return p;
  }

  Future<void> save(GardenProject project) async {
    await repository.save(project);
    final idx = _projects.indexWhere((p) => p.id == project.id);
    if (idx >= 0) {
      _projects = List.of(_projects)..[idx] = project;
    } else {
      _projects = [project, ..._projects];
    }
    _projects.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    notifyListeners();
  }

  Future<void> rename(String id, String name) async {
    final p = _projects.firstWhere((p) => p.id == id);
    await save(p.copyWith(name: name.trim(), modifiedAt: DateTime.now()));
  }

  Future<void> resize(String id, double width, double length) async {
    final p = _projects.firstWhere((p) => p.id == id);
    await save(
      p.copyWith(width: width, length: length, modifiedAt: DateTime.now()),
    );
  }

  Future<void> delete(String id) async {
    await repository.delete(id);
    if (id == kSampleProjectId) await repository.markSampleRemoved();
    _projects = _projects.where((p) => p.id != id).toList();
    notifyListeners();
  }

  /// Fügt ein importiertes Projekt mit neuer ID hinzu.
  Future<GardenProject> import(GardenProject imported) async {
    final now = DateTime.now();
    final p = GardenProject(
      id: newId('g-'),
      name: imported.name,
      width: imported.width,
      length: imported.length,
      createdAt: now,
      modifiedAt: now,
      elements: imported.elements,
      planning: imported.planning,
    );
    await save(p);
    return p;
  }

  GardenProject? byId(String id) {
    for (final p in _projects) {
      if (p.id == id) return p;
    }
    return null;
  }
}
