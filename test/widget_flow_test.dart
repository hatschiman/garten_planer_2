import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gartenplan/app_state.dart';
import 'package:gartenplan/main.dart';
import 'package:gartenplan/models/garden_project.dart';
import 'package:gartenplan/storage/project_repository.dart';

/// In-Memory-Ablage für Widget-Tests: keine echte Datei-Ein-/Ausgabe, damit
/// pumpAndSettle deterministisch bleibt. Die Dateiablage selbst wird in
/// project_repository_test.dart geprüft.
class MemoryRepository extends ProjectRepository {
  MemoryRepository(this.dir);

  final Directory dir;
  final Map<String, GardenProject> saved = {};

  bool sampleRemoved = false;

  // Kein Plattformkanal (path_provider) und keine Datei-Ein-/Ausgabe im Test.
  @override
  Future<Directory> baseDirectory() async => dir;

  @override
  Future<bool> isSampleRemoved() async => sampleRemoved;

  @override
  Future<void> markSampleRemoved() async => sampleRemoved = true;

  @override
  Future<LoadResult> loadAll() async =>
      LoadResult(projects: saved.values.toList(), corruptFiles: const []);

  @override
  Future<void> save(GardenProject project) async => saved[project.id] = project;

  @override
  Future<void> delete(String id) async => saved.remove(id);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gartenplan_widget_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('Projekt anlegen, Element hinzufügen, fixieren, speichern', (
    tester,
  ) async {
    final repo = MemoryRepository(tempDir);
    final store = ProjectStore(repo);
    await tester.pumpWidget(GartenPlanApp(store: store));
    await tester.pumpAndSettle();

    // Beispielgarten wird beim ersten Start angelegt.
    expect(find.text('Beispielgarten'), findsOneWidget);
    expect(repo.saved.keys, contains('beispiel-garten'));

    // Neues Projekt
    await tester.tap(find.text('Neuer Garten'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Testgarten',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Breite (m)'),
      '12',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Länge (m)'),
      '9',
    );
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    // Editor offen
    expect(find.text('Testgarten'), findsOneWidget);
    expect(find.text('Element hinzufügen'), findsOneWidget);

    // Element über Katalog hinzufügen
    await tester.tap(find.text('Element hinzufügen'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Gartenhaus'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Gartenhaus'));
    await tester.pumpAndSettle();

    // Auswahlleiste zeigt das neue Element
    expect(find.text('Gartenhaus'), findsOneWidget);
    expect(find.byTooltip('Fixieren'), findsOneWidget);

    // Fixieren
    await tester.tap(find.byTooltip('Fixieren'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Entsperren'), findsOneWidget);

    // Undo macht das Fixieren rückgängig
    await tester.tap(find.byTooltip('Rückgängig'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Fixieren'), findsOneWidget);
    await tester.tap(find.byTooltip('Wiederholen'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Entsperren'), findsOneWidget);

    // Autosave abwarten und zurück zur Übersicht
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    final project = repo.saved.values.firstWhere((p) => p.name == 'Testgarten');
    expect(project.width, 12);
    expect(project.length, 9);
    expect(project.elements, hasLength(1));
    expect(project.elements.first.typeId, 'shed');
    expect(project.elements.first.locked, isTrue);

    // Erneut öffnen: Element ist da.
    await tester.tap(find.text('Testgarten'));
    await tester.pumpAndSettle();
    expect(
      find.text('12,0 m × 9,0 m · 1 Elemente · Raster an'),
      findsOneWidget,
    );
  });

  testWidgets('Ungültige Maße werden abgefangen', (tester) async {
    final store = ProjectStore(MemoryRepository(tempDir));
    await tester.pumpWidget(GartenPlanApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neuer Garten'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), '   ');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Breite (m)'),
      '999',
    );
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte Namen angeben.'), findsOneWidget);
    expect(find.text('Höchstens 200 m.'), findsOneWidget);
    // Dialog ist noch offen (Titel + FAB-Beschriftung).
    expect(find.text('Neuer Garten'), findsNWidgets(2));
  });
}
