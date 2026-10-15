import 'package:flutter_test/flutter_test.dart';
import 'package:gartenplan/editor/editor_controller.dart';
import 'package:gartenplan/models/element_type.dart';
import 'package:gartenplan/models/garden_element.dart';
import 'package:gartenplan/models/garden_project.dart';

GardenProject emptyProject({double w = 10, double l = 8}) => GardenProject(
  id: 'p',
  name: 'Test',
  width: w,
  length: l,
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
);

void main() {
  late List<GardenProject> saved;
  late EditorController c;

  setUp(() {
    saved = [];
    c = EditorController(
      project: emptyProject(),
      onSave: (p) async => saved.add(p),
      autosaveDelay: const Duration(milliseconds: 10),
    );
  });

  tearDown(() => c.dispose());

  test('Hinzufügen, Verschieben, Undo und Redo', () async {
    final shed = ElementCatalog.byId('shed')!;
    expect(c.addElement(shed).success, isTrue);
    expect(c.elements, hasLength(1));
    final id = c.elements.first.id;
    final before = c.elements.first;

    // Drag mit vielen Zwischenschritten erzeugt genau EINEN Undo-Eintrag.
    expect(c.beginDrag(id), isTrue);
    for (var i = 0; i < 20; i++) {
      c.updateDrag(2 + i * 0.1, 2);
    }
    final r = c.endDrag();
    expect(r.success, isTrue);
    final after = c.elements.first;
    expect(after.x, isNot(before.x));
    expect(after.x, 4.0); // eingerastet auf 0,5 m

    expect(c.canUndo, isTrue);
    c.undo(); // Verschieben rückgängig
    expect(c.elements.first.x, before.x);
    c.undo(); // Hinzufügen rückgängig
    expect(c.elements, isEmpty);
    expect(c.canUndo, isFalse);
    expect(c.canRedo, isTrue);
    c.redo();
    expect(c.elements, hasLength(1));
    c.redo();
    expect(c.elements.first.x, after.x);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(saved, isNotEmpty, reason: 'Autosave muss gelaufen sein');
  });

  test('Drag über die Grenze wird zurückgesetzt', () {
    c.addElement(ElementCatalog.byId('shed')!);
    final e = c.elements.first;
    c.beginDrag(e.id);
    c.updateDrag(-5, -5);
    expect(c.dragInvalid, isTrue);
    final r = c.endDrag();
    expect(r.success, isFalse);
    expect(r.message, contains('Grundstücksgrenze'));
    expect(c.elements.first, e);
    expect(c.canUndo, isTrue); // nur das Hinzufügen
    c.undo();
    expect(c.canUndo, isFalse);
  });

  test('Abgebrochener Drag hinterlässt Ausgangszustand', () {
    c.addElement(ElementCatalog.byId('tree')!);
    final e = c.elements.first;
    c.beginDrag(e.id);
    c.updateDrag(1, 1);
    c.cancelDrag();
    expect(c.elements.first, e);
    expect(c.isDragging, isFalse);
  });

  test('Fixierte Elemente lassen sich nicht verschieben oder löschen', () {
    c.addElement(ElementCatalog.byId('shed')!);
    final id = c.elements.first.id;
    c.setLocked(id, true);
    expect(c.beginDrag(id), isFalse);
    expect(c.remove(id).success, isFalse);
    expect(c.resize(id, width: 4).success, isFalse);
    c.setLocked(id, false);
    expect(c.remove(id).success, isTrue);
  });

  test('Größe, Rotation und Grenzen', () {
    c.addElement(ElementCatalog.byId('path')!); // 1 × 4 in der Mitte (5, 4)
    final id = c.elements.first.id;
    expect(c.resize(id, width: 1, depth: 7).success, isTrue);
    // 7 m tief passt in 8 m Länge, gedreht (7 m breit) auch in 10 m Breite.
    expect(c.rotate(id, 90).success, isTrue);
    expect(c.elements.first.rotation, 90);
    // Jetzt 11 m breit → passt gedreht nicht mehr in 10 m.
    expect(c.resize(id, depth: 11).success, isFalse);
    // Unter dem Mindestmaß.
    expect(c.resize(id, width: 0.1).success, isFalse);
  });

  test('Verbotene Überlappung wird abgelehnt, erlaubte nicht', () {
    c.addElement(ElementCatalog.byId('terrace')!);
    final terrace = c.elements.first;
    // Sitzgruppe direkt auf die Terrasse: erlaubt.
    c.addElement(
      ElementCatalog.byId('seating')!,
      nearX: terrace.x,
      nearY: terrace.y,
    );
    final seating = c.elements.last;
    expect(seating.x, terrace.x);
    expect(seating.y, terrace.y);
    // Gartenhaus auf Gartenhaus: ausweichen auf freien Platz.
    c.addElement(ElementCatalog.byId('shed')!, nearX: 2, nearY: 6);
    final shed1 = c.elements.last;
    c.addElement(ElementCatalog.byId('shed')!, nearX: shed1.x, nearY: shed1.y);
    final shed2 = c.elements.last;
    expect(shed1.x != shed2.x || shed1.y != shed2.y, isTrue);
    // Manuelles Verschieben auf das andere Gartenhaus: abgelehnt.
    c.beginDrag(shed2.id);
    c.updateDrag(shed1.x, shed1.y);
    final r = c.endDrag();
    expect(r.success, isFalse);
    expect(r.message, contains('Überlappung'));
    expect(c.conflictingIds(), isEmpty);
  });

  test('Plan ersetzen ist mit einem Undo rückgängig', () {
    c.addElement(ElementCatalog.byId('shed')!);
    final before = List<GardenElement>.from(c.elements);
    c.replaceAllElements([
      const GardenElement(
        id: 'n1',
        typeId: 'tree',
        x: 3,
        y: 3,
        width: 2,
        depth: 2,
      ),
      const GardenElement(
        id: 'n2',
        typeId: 'pond',
        x: 7,
        y: 5,
        width: 2,
        depth: 2,
      ),
    ]);
    expect(c.elements, hasLength(2));
    c.undo();
    expect(c.elements, before);
  });
}
