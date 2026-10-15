import '../models/element_type.dart';
import '../models/garden_element.dart';
import 'geometry.dart';

/// Regelmatrix: Dürfen sich Elemente zweier Kollisionsklassen überlappen?
///
/// Grundidee:
/// - Flächen (ground) bilden den Boden. Auf ihnen darf alles stehen,
///   aber zwei Flächen dürfen sich nicht überlappen.
/// - Pflanzen, Möbel und Bauten sind Hindernisse und dürfen sich gegenseitig
///   nicht überlappen (auch nicht untereinander in derselben Klasse).
/// - Zonen (Spielbereich) sind Markierungen: Sie dürfen Flächen und leichte
///   Möbel (z. B. Sandkasten) überlagern, aber keine Bauten oder Pflanzen.
///
/// Die Matrix ist symmetrisch.
bool mayOverlap(CollisionClass a, CollisionClass b) {
  if (a == CollisionClass.ground || b == CollisionClass.ground) {
    // Fläche vs. Fläche verboten, Fläche vs. alles andere erlaubt.
    return !(a == CollisionClass.ground && b == CollisionClass.ground);
  }
  if (a == CollisionClass.zone || b == CollisionClass.zone) {
    final other = a == CollisionClass.zone ? b : a;
    // Zone vs. Zone: erlaubt (zwei Spielbereiche dürfen sich berühren).
    if (other == CollisionClass.zone) return true;
    return other == CollisionClass.furniture;
  }
  // plant, furniture, structure untereinander: nie.
  return false;
}

/// Prüft, ob [candidate] mit [others] regelwidrig kollidiert.
/// Das Element mit derselben ID wie [candidate] wird übersprungen.
List<GardenElement> findConflicts(
  GardenElement candidate,
  Iterable<GardenElement> others,
) {
  final result = <GardenElement>[];
  final cls = candidate.type.collisionClass;
  for (final other in others) {
    if (other.id == candidate.id) continue;
    if (mayOverlap(cls, other.type.collisionClass)) continue;
    if (elementsOverlap(candidate, other)) result.add(other);
  }
  return result;
}

/// Ergebnis einer Platzierungsprüfung.
class PlacementCheck {
  const PlacementCheck({required this.insideGarden, required this.conflicts});
  final bool insideGarden;
  final List<GardenElement> conflicts;
  bool get isValid => insideGarden && conflicts.isEmpty;
}

PlacementCheck checkPlacement(
  GardenElement candidate,
  Iterable<GardenElement> others,
  double gardenWidth,
  double gardenLength,
) => PlacementCheck(
  insideGarden: isInsideGarden(candidate, gardenWidth, gardenLength),
  conflicts: findConflicts(candidate, others),
);
