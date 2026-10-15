import 'package:flutter_test/flutter_test.dart';
import 'package:gartenplan/geometry/collision_rules.dart';
import 'package:gartenplan/geometry/geometry.dart';
import 'package:gartenplan/models/element_type.dart';
import 'package:gartenplan/models/garden_element.dart';

GardenElement el(
  String id,
  String type,
  double x,
  double y,
  double w,
  double d, {
  double rot = 0,
}) => GardenElement(
  id: id,
  typeId: type,
  x: x,
  y: y,
  width: w,
  depth: d,
  rotation: rot,
);

void main() {
  group('Grundstücksgrenzen', () {
    test('Element innerhalb und außerhalb', () {
      expect(isInsideGarden(el('a', 'shed', 2, 2, 3, 2.5), 10, 8), isTrue);
      expect(isInsideGarden(el('a', 'shed', 1, 2, 3, 2.5), 10, 8), isFalse);
      expect(isInsideGarden(el('a', 'shed', 9, 7, 3, 2.5), 10, 8), isFalse);
    });

    test('Gedrehtes Element: 90° vertauscht Breite und Tiefe', () {
      // 4 m breit, 1 m tief, Mitte bei (2, 0.5): passt ungedreht knapp.
      final flat = el('a', 'hedge', 2, 0.5, 4, 1);
      expect(isInsideGarden(flat, 10, 8), isTrue);
      // Gedreht ragt es oben 1,5 m hinaus.
      final upright = flat.copyWith(rotation: 90);
      expect(isInsideGarden(upright, 10, 8), isFalse);
      final bounds = elementBounds(upright);
      expect(bounds.width, closeTo(1, 1e-9));
      expect(bounds.height, closeTo(4, 1e-9));
    });

    test('45° gedrehtes Quadrat braucht mehr Platz', () {
      final square = el('a', 'shed', 1, 1, 2, 2);
      expect(isInsideGarden(square, 10, 10), isTrue);
      final rotated = square.copyWith(rotation: 45);
      expect(isInsideGarden(rotated, 10, 10), isFalse);
    });

    test('Kreis wird über den Durchmesser geprüft', () {
      expect(isInsideGarden(el('t', 'tree', 2, 2, 4, 4), 10, 10), isTrue);
      expect(isInsideGarden(el('t', 'tree', 1.9, 2, 4, 4), 10, 10), isFalse);
    });
  });

  group('Treffertest', () {
    test('Punkt in gedrehtem Rechteck', () {
      final e = el('a', 'path', 5, 5, 1, 4, rot: 90);
      // Nach Drehung liegt der Weg horizontal: x 3..7, y 4.5..5.5
      expect(elementContainsPoint(e, const Offset(6.8, 5.2)), isTrue);
      expect(elementContainsPoint(e, const Offset(5, 6.2)), isFalse);
    });
  });

  group('Überlappungsregeln', () {
    test('Sitzgruppe darf auf Terrasse stehen', () {
      final terrace = el('t', 'terrace', 2, 2, 4, 3);
      final seating = el('s', 'seating', 2, 2, 2, 1.5);
      expect(elementsOverlap(terrace, seating), isTrue);
      expect(findConflicts(seating, [terrace]), isEmpty);
    });

    test('Baum darf auf Rasen stehen', () {
      final lawn = el('l', 'lawn', 5, 5, 10, 10);
      final tree = el('b', 'tree', 5, 5, 4, 4);
      expect(findConflicts(tree, [lawn]), isEmpty);
    });

    test('Gartenhaus darf kein anderes Gartenhaus überlagern', () {
      final a = el('a', 'shed', 2, 2, 3, 2.5);
      final b = el('b', 'shed', 3, 2, 3, 2.5);
      expect(findConflicts(b, [a]), hasLength(1));
    });

    test('Zwei Flächen dürfen sich nicht überlappen, Berührung ist ok', () {
      final lawn = el('l', 'lawn', 3, 3, 6, 6);
      final terrace = el('t', 'terrace', 8, 3, 4, 3); // x 6..10, berührt
      expect(findConflicts(terrace, [lawn]), isEmpty);
      final overlapping = terrace.copyWith(x: 7.9);
      expect(findConflicts(overlapping, [lawn]), hasLength(1));
    });

    test('Gedrehte Elemente kollidieren korrekt (SAT)', () {
      final a = el('a', 'hedge', 5, 5, 6, 0.5); // horizontal
      final b = el('b', 'hedge', 5, 7, 6, 0.5); // 2 m darunter, parallel
      expect(elementsOverlap(a, b), isFalse);
      final bRot = b.copyWith(rotation: 90); // vertikal, kreuzt a
      expect(elementsOverlap(a, bRot), isTrue);
    });

    test('Kreis gegen gedrehtes Rechteck', () {
      final tree = el('t', 'tree', 5, 5, 2, 2); // r = 1
      final shed = el('s', 'shed', 7.5, 5, 3, 1, rot: 90); // x 7..8
      expect(elementsOverlap(tree, shed), isFalse);
      final closer = shed.copyWith(x: 5.9); // x 5.4..6.4 → Abstand 0.4 < r
      expect(elementsOverlap(tree, closer), isTrue);
    });

    test(
      'Spielbereich (Zone) darf Sandkasten, aber nicht Teich überlagern',
      () {
        expect(
          mayOverlap(CollisionClass.zone, CollisionClass.furniture),
          isTrue,
        );
        expect(
          mayOverlap(CollisionClass.zone, CollisionClass.structure),
          isFalse,
        );
        expect(mayOverlap(CollisionClass.zone, CollisionClass.ground), isTrue);
        expect(mayOverlap(CollisionClass.plant, CollisionClass.plant), isFalse);
      },
    );

    test('Regelmatrix ist symmetrisch', () {
      for (final a in CollisionClass.values) {
        for (final b in CollisionClass.values) {
          expect(mayOverlap(a, b), mayOverlap(b, a), reason: '$a/$b');
        }
      }
    });
  });
}
