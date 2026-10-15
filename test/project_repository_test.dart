import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gartenplan/models/sample_garden.dart';
import 'package:gartenplan/storage/project_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gartenplan_repo_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('Speichern, Laden, Löschen und beschädigte Dateien', () async {
    final repo = ProjectRepository(baseDirectory: tempDir);
    final sample = buildSampleGarden();
    await repo.save(sample);
    await repo.save(sample.copyWith(name: 'Geändert'));

    // Keine temporäre Datei bleibt zurück (atomares Umbenennen).
    final dir = await repo.baseDirectory();
    final files = dir.listSync().map((f) => f.uri.pathSegments.last).toList();
    expect(files, ['beispiel-garten.json']);

    // Beschädigte Datei daneben legen.
    File('${dir.path}/kaputt.json').writeAsStringSync('{"schemaVersion":');

    final result = await repo.loadAll();
    expect(result.projects, hasLength(1));
    expect(result.projects.single.name, 'Geändert');
    expect(result.projects.single.elements, sample.elements);
    expect(result.corruptFiles, ['kaputt.json']);
    expect(File('${dir.path}/kaputt.json.defekt').existsSync(), isTrue);

    await repo.delete(sample.id);
    expect((await repo.loadAll()).projects, isEmpty);

    expect(await repo.isSampleRemoved(), isFalse);
    await repo.markSampleRemoved();
    expect(await repo.isSampleRemoved(), isTrue);
  });
}
