import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gartenplan/models/garden_project.dart';
import 'package:gartenplan/models/planning_settings.dart';
import 'package:gartenplan/models/sample_garden.dart';
import 'package:gartenplan/storage/project_repository.dart';

void main() {
  group('JSON-Roundtrip', () {
    test('Beispielgarten überlebt Serialisierung unverändert', () {
      final original = buildSampleGarden();
      final text = jsonEncode(original.toJson());
      final restored = GardenProject.fromJson(
        jsonDecode(text) as Map<String, dynamic>,
      );

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.width, original.width);
      expect(restored.length, original.length);
      expect(restored.isSample, isTrue);
      expect(restored.elements, original.elements);
      expect(restored.planning.style, GardenStyle.family);
      expect(restored.planning.wishes, original.planning.wishes);
      expect(restored.createdAt, original.createdAt);
    });

    test('Beschädigte Daten werfen FormatException', () {
      expect(
        () => GardenProject.fromJson({'schemaVersion': 1, 'id': 'x'}),
        throwsFormatException,
      );
      expect(
        () => GardenProject.fromJson({
          'schemaVersion': 1,
          'id': 'x',
          'name': 'n',
          'width': 5000,
          'length': 5,
        }),
        throwsFormatException,
      );
      expect(
        () => GardenProject.fromJson({
          'schemaVersion': 99,
          'id': 'x',
          'name': 'n',
          'width': 5,
          'length': 5,
        }),
        throwsFormatException,
      );
      expect(
        () => ProjectRepository.importJson('[1,2,3]'),
        throwsFormatException,
      );
      expect(
        () => GardenProject.fromJson({
          'schemaVersion': 1,
          'id': 'x',
          'name': 'n',
          'width': 5,
          'length': 5,
          'elements': [
            {'id': 'e1', 'typeId': 'gibt_es_nicht', 'x': 1, 'y': 1},
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
