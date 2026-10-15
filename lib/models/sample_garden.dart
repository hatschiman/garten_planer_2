import 'garden_element.dart';
import 'garden_project.dart';
import 'planning_settings.dart';

/// Mitgelieferter Beispielgarten. Feste ID, damit er nur einmal angelegt wird.
const String kSampleProjectId = 'beispiel-garten';

GardenProject buildSampleGarden() {
  final now = DateTime(2026, 1, 1);
  return GardenProject(
    id: kSampleProjectId,
    name: 'Beispielgarten',
    width: 14,
    length: 10,
    createdAt: now,
    modifiedAt: now,
    isSample: true,
    planning: const PlanningSettings(
      style: GardenStyle.family,
      targetLawnShare: 0.4,
      wishes: {'vegetable_bed': 2, 'tree': 1, 'sandbox': 1},
    ),
    elements: const [
      GardenElement(
        id: 's-lawn',
        typeId: 'lawn',
        x: 9.25,
        y: 6.5,
        width: 8.5,
        depth: 6,
      ),
      GardenElement(
        id: 's-terrace',
        typeId: 'terrace',
        x: 2.5,
        y: 1.75,
        width: 5,
        depth: 3.5,
        locked: true,
      ),
      GardenElement(
        id: 's-seating',
        typeId: 'seating',
        x: 2.5,
        y: 1.75,
        width: 2,
        depth: 1.5,
      ),
      GardenElement(
        id: 's-path',
        typeId: 'path',
        x: 2.5,
        y: 6.75,
        width: 1,
        depth: 6.5,
      ),
      GardenElement(
        id: 's-shed',
        typeId: 'shed',
        x: 12.3,
        y: 8.6,
        width: 3,
        depth: 2.5,
      ),
      GardenElement(
        id: 's-tree',
        typeId: 'tree',
        x: 11.5,
        y: 3,
        width: 3.5,
        depth: 3.5,
      ),
      GardenElement(
        id: 's-bed1',
        typeId: 'vegetable_bed',
        x: 8,
        y: 1,
        width: 2.5,
        depth: 1.2,
      ),
      GardenElement(
        id: 's-bed2',
        typeId: 'vegetable_bed',
        x: 8,
        y: 2.5,
        width: 2.5,
        depth: 1.2,
      ),
      GardenElement(
        id: 's-barrel',
        typeId: 'rain_barrel',
        x: 0.6,
        y: 4.2,
        width: 0.8,
        depth: 0.8,
      ),
    ],
  );
}
