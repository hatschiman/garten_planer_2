import 'package:flutter_test/flutter_test.dart';
import 'package:gartenplan/geometry/collision_rules.dart';
import 'package:gartenplan/geometry/geometry.dart';
import 'package:gartenplan/models/garden_element.dart';
import 'package:gartenplan/models/garden_project.dart';
import 'package:gartenplan/models/planning_settings.dart';
import 'package:gartenplan/models/sample_garden.dart';
import 'package:gartenplan/planner/auto_planner.dart';

void main() {
  test('Beispielgarten ist regelkonform', () {
    final p = buildSampleGarden();
    for (final e in p.elements) {
      expect(isInsideGarden(e, p.width, p.length), isTrue, reason: e.id);
      expect(findConflicts(e, p.elements), isEmpty, reason: e.id);
    }
  });

  group('AutoPlanner', () {
    test(
      'Vorschläge sind gültig und fixierte Elemente bleiben unverändert',
      () {
        final project = buildSampleGarden().copyWith(
          planning: const PlanningSettings(
            style: GardenStyle.family,
            targetLawnShare: 0.4,
            wishes: {
              'vegetable_bed': 2,
              'tree': 1,
              'sandbox': 1,
              'greenhouse': 1,
            },
          ),
        );
        final locked = project.elements.where((e) => e.locked).toList();
        expect(locked, isNotEmpty);

        final result = AutoPlanner().plan(project, seed: 7);
        expect(result.proposals, isNotEmpty);

        for (final p in result.proposals) {
          // Fixierte unverändert
          for (final l in locked) {
            expect(p.elements, contains(l));
          }
          // Vorhandene beibehalten
          for (final e in project.elements) {
            expect(p.elements.any((x) => x.id == e.id), isTrue);
          }
          // Harte Regeln
          for (final e in p.elements) {
            expect(
              isInsideGarden(e, project.width, project.length),
              isTrue,
              reason: '${e.typeId} außerhalb',
            );
            expect(
              findConflicts(e, p.elements),
              isEmpty,
              reason: '${e.typeId} kollidiert',
            );
          }
          expect(p.unplaced, isEmpty);
          expect(p.fulfilled, contains('2 × Gemüsebeet'));
          expect(p.reasons, isNotEmpty);
        }
      },
    );

    test('Gleicher Seed liefert gleiches Ergebnis', () {
      final project = buildSampleGarden();
      final a = AutoPlanner().plan(project, seed: 3);
      final b = AutoPlanner().plan(project, seed: 3);
      expect(a.proposals.length, b.proposals.length);
      for (var i = 0; i < a.proposals.length; i++) {
        expect(a.proposals[i].elements, b.proposals[i].elements);
      }
    });

    test('Nicht erfüllbare Wünsche werden offen gemeldet', () {
      final project = GardenProject(
        id: 'klein',
        name: 'Klein',
        width: 4,
        length: 3,
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
        planning: const PlanningSettings(
          wishes: {'shed': 3, 'greenhouse': 1, 'pond': 1},
        ),
      );
      final result = AutoPlanner().plan(project, seed: 1);
      expect(result.proposals, isNotEmpty);
      final p = result.proposals.first;
      expect(p.unplaced, isNotEmpty);
      final placedSheds = p.elements.where((e) => e.typeId == 'shed').length;
      final unplacedSheds = p.unplaced.where((u) => u.typeId == 'shed').length;
      expect(placedSheds + unplacedSheds, 3);
      for (final u in p.unplaced) {
        expect(u.reason, isNotEmpty);
      }
      // Trotzdem keine Regelverletzung.
      for (final e in p.elements) {
        expect(isInsideGarden(e, 4, 3), isTrue);
        expect(findConflicts(e, p.elements), isEmpty);
      }
    });

    test('Element größer als der Garten wird mit Begründung abgelehnt', () {
      final project = GardenProject(
        id: 'mini',
        name: 'Mini',
        width: 2,
        length: 2,
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
        planning: const PlanningSettings(wishes: {'shed': 1}),
      );
      final result = AutoPlanner().plan(project, seed: 1);
      final p = result.proposals.first;
      expect(p.elements, isEmpty);
      expect(p.unplaced.single.reason, contains('größer als der Garten'));
    });

    test('Rasenwunsch füllt freie Fläche und keine andere Fläche', () {
      final project = GardenProject(
        id: 'r',
        name: 'Rasen',
        width: 10,
        length: 8,
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
        elements: const [
          GardenElement(
            id: 'terrasse',
            typeId: 'terrace',
            x: 2,
            y: 1.5,
            width: 4,
            depth: 3,
            locked: true,
          ),
        ],
        planning: const PlanningSettings(wishes: {'lawn': 1, 'shed': 1}),
      );
      final result = AutoPlanner().plan(project, seed: 5);
      final p = result.proposals.first;
      final lawn = p.elements.where((e) => e.typeId == 'lawn');
      expect(lawn, hasLength(1));
      expect(lawn.first.width * lawn.first.depth, greaterThan(20));
      expect(findConflicts(lawn.first, p.elements), isEmpty);
    });
  });
}
