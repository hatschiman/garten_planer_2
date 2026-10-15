import 'package:flutter/material.dart';

/// Kategorie eines Katalogelements.
enum ElementCategory {
  surface('Flächen'),
  plant('Pflanzen'),
  equipment('Ausstattung'),
  path('Wege');

  const ElementCategory(this.label);
  final String label;
}

/// Kollisionsklasse. Sie entscheidet, ob sich zwei Elemente überlappen dürfen.
///
/// - [ground]: Bodenbelag/Fläche (Rasen, Terrasse, Beet, Kies, Weg).
///   Flächen dürfen sich untereinander NICHT überlappen (sonst wäre unklar,
///   welcher Belag gilt), alles andere darf aber auf ihnen stehen.
/// - [plant]: Pflanzen. Dürfen auf Flächen stehen, nicht ineinander und nicht
///   in Bauten/Hindernissen.
/// - [furniture]: Leichte Ausstattung (Sitzgruppe, Grill, Sandkasten, Regentonne).
///   Darf auf Flächen stehen, nicht in anderen Hindernissen.
/// - [structure]: Bauten (Gartenhaus, Gewächshaus, Hochbeet, Kompost, Teich).
///   Darf auf Flächen stehen, nicht auf anderen Bauten/Möbeln/Pflanzen.
/// - [zone]: Bereiche ohne feste Bebauung (Spielbereich). Dürfen Flächen
///   und Möbel überlagern, aber keine Bauten oder Pflanzen.
enum CollisionClass { ground, plant, furniture, structure, zone }

/// Darstellungsform eines Elements im Plan.
enum ElementShape { rect, circle }

/// Ein Elementtyp aus dem Katalog.
class ElementType {
  const ElementType({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultWidth,
    required this.defaultDepth,
    required this.shape,
    required this.fillColor,
    required this.strokeColor,
    required this.collisionClass,
    this.recommendedClearance = 0,
    this.minSize = 0.3,
    this.maxSize = 60,
    this.icon = Icons.crop_square,
    this.pattern = ElementPattern.none,
  });

  final String id;
  final String name;
  final ElementCategory category;

  /// Standardbreite in Metern (bei Kreisen: Durchmesser).
  final double defaultWidth;

  /// Standardtiefe in Metern (bei Kreisen gleich der Breite).
  final double defaultDepth;
  final ElementShape shape;
  final Color fillColor;
  final Color strokeColor;
  final CollisionClass collisionClass;

  /// Empfohlener Abstand zu anderen Hindernissen in Metern (weiches Kriterium).
  final double recommendedClearance;
  final double minSize;
  final double maxSize;
  final IconData icon;
  final ElementPattern pattern;

  bool get isSurface => collisionClass == CollisionClass.ground;
}

/// Dezentes Muster für die Darstellung einer Fläche.
enum ElementPattern { none, grass, tiles, soil, gravel, water, sand, hedge }

/// Vordefinierter Katalog aller Elementtypen.
class ElementCatalog {
  ElementCatalog._();

  static const List<ElementType> all = [
    // --- Flächen ---
    ElementType(
      id: 'lawn',
      name: 'Rasen',
      category: ElementCategory.surface,
      defaultWidth: 6,
      defaultDepth: 4,
      shape: ElementShape.rect,
      fillColor: Color(0xFF9CCC65),
      strokeColor: Color(0xFF689F38),
      collisionClass: CollisionClass.ground,
      icon: Icons.grass,
      pattern: ElementPattern.grass,
    ),
    ElementType(
      id: 'terrace',
      name: 'Terrasse',
      category: ElementCategory.surface,
      defaultWidth: 4,
      defaultDepth: 3,
      shape: ElementShape.rect,
      fillColor: Color(0xFFD7CCC8),
      strokeColor: Color(0xFF8D6E63),
      collisionClass: CollisionClass.ground,
      icon: Icons.deck,
      pattern: ElementPattern.tiles,
    ),
    ElementType(
      id: 'vegetable_bed',
      name: 'Gemüsebeet',
      category: ElementCategory.surface,
      defaultWidth: 2.5,
      defaultDepth: 1.2,
      shape: ElementShape.rect,
      fillColor: Color(0xFFA1887F),
      strokeColor: Color(0xFF5D4037),
      collisionClass: CollisionClass.ground,
      icon: Icons.eco,
      pattern: ElementPattern.soil,
    ),
    ElementType(
      id: 'flower_bed',
      name: 'Blumenbeet',
      category: ElementCategory.surface,
      defaultWidth: 2,
      defaultDepth: 1,
      shape: ElementShape.rect,
      fillColor: Color(0xFFF8BBD0),
      strokeColor: Color(0xFFC2185B),
      collisionClass: CollisionClass.ground,
      icon: Icons.local_florist,
      pattern: ElementPattern.soil,
    ),
    ElementType(
      id: 'gravel',
      name: 'Kiesfläche',
      category: ElementCategory.surface,
      defaultWidth: 3,
      defaultDepth: 2,
      shape: ElementShape.rect,
      fillColor: Color(0xFFE0E0E0),
      strokeColor: Color(0xFF9E9E9E),
      collisionClass: CollisionClass.ground,
      icon: Icons.grain,
      pattern: ElementPattern.gravel,
    ),
    // --- Pflanzen ---
    ElementType(
      id: 'tree',
      name: 'Baum',
      category: ElementCategory.plant,
      defaultWidth: 4,
      defaultDepth: 4,
      shape: ElementShape.circle,
      fillColor: Color(0xFF66BB6A),
      strokeColor: Color(0xFF2E7D32),
      collisionClass: CollisionClass.plant,
      recommendedClearance: 2,
      minSize: 1,
      maxSize: 15,
      icon: Icons.park,
    ),
    ElementType(
      id: 'shrub',
      name: 'Strauch',
      category: ElementCategory.plant,
      defaultWidth: 1.5,
      defaultDepth: 1.5,
      shape: ElementShape.circle,
      fillColor: Color(0xFF81C784),
      strokeColor: Color(0xFF388E3C),
      collisionClass: CollisionClass.plant,
      minSize: 0.5,
      maxSize: 5,
      icon: Icons.spa,
    ),
    ElementType(
      id: 'hedge',
      name: 'Heckenabschnitt',
      category: ElementCategory.plant,
      defaultWidth: 4,
      defaultDepth: 0.8,
      shape: ElementShape.rect,
      fillColor: Color(0xFF558B2F),
      strokeColor: Color(0xFF33691E),
      collisionClass: CollisionClass.plant,
      maxSize: 40,
      icon: Icons.fence,
      pattern: ElementPattern.hedge,
    ),
    // --- Ausstattung ---
    ElementType(
      id: 'raised_bed',
      name: 'Hochbeet',
      category: ElementCategory.equipment,
      defaultWidth: 2,
      defaultDepth: 1,
      shape: ElementShape.rect,
      fillColor: Color(0xFFBCAAA4),
      strokeColor: Color(0xFF4E342E),
      collisionClass: CollisionClass.structure,
      recommendedClearance: 0.6,
      icon: Icons.yard,
      pattern: ElementPattern.soil,
    ),
    ElementType(
      id: 'greenhouse',
      name: 'Gewächshaus',
      category: ElementCategory.equipment,
      defaultWidth: 3,
      defaultDepth: 2,
      shape: ElementShape.rect,
      fillColor: Color(0xFFB3E5FC),
      strokeColor: Color(0xFF0277BD),
      collisionClass: CollisionClass.structure,
      recommendedClearance: 0.8,
      icon: Icons.house_siding,
    ),
    ElementType(
      id: 'shed',
      name: 'Gartenhaus',
      category: ElementCategory.equipment,
      defaultWidth: 3,
      defaultDepth: 2.5,
      shape: ElementShape.rect,
      fillColor: Color(0xFFBCAAA4),
      strokeColor: Color(0xFF3E2723),
      collisionClass: CollisionClass.structure,
      recommendedClearance: 1,
      icon: Icons.cabin,
    ),
    ElementType(
      id: 'seating',
      name: 'Sitzgruppe',
      category: ElementCategory.equipment,
      defaultWidth: 2,
      defaultDepth: 1.5,
      shape: ElementShape.rect,
      fillColor: Color(0xFFFFE0B2),
      strokeColor: Color(0xFFE65100),
      collisionClass: CollisionClass.furniture,
      icon: Icons.chair,
    ),
    ElementType(
      id: 'bbq',
      name: 'Grillplatz',
      category: ElementCategory.equipment,
      defaultWidth: 1.5,
      defaultDepth: 1,
      shape: ElementShape.rect,
      fillColor: Color(0xFFB0BEC5),
      strokeColor: Color(0xFF37474F),
      collisionClass: CollisionClass.furniture,
      recommendedClearance: 1,
      icon: Icons.outdoor_grill,
    ),
    ElementType(
      id: 'compost',
      name: 'Kompost',
      category: ElementCategory.equipment,
      defaultWidth: 1,
      defaultDepth: 1,
      shape: ElementShape.rect,
      fillColor: Color(0xFF8D6E63),
      strokeColor: Color(0xFF3E2723),
      collisionClass: CollisionClass.structure,
      recommendedClearance: 0.5,
      icon: Icons.recycling,
    ),
    ElementType(
      id: 'rain_barrel',
      name: 'Regentonne',
      category: ElementCategory.equipment,
      defaultWidth: 0.8,
      defaultDepth: 0.8,
      shape: ElementShape.circle,
      fillColor: Color(0xFF90A4AE),
      strokeColor: Color(0xFF263238),
      collisionClass: CollisionClass.furniture,
      minSize: 0.4,
      maxSize: 3,
      icon: Icons.water_drop,
    ),
    ElementType(
      id: 'pond',
      name: 'Teich',
      category: ElementCategory.equipment,
      defaultWidth: 3,
      defaultDepth: 2,
      shape: ElementShape.rect,
      fillColor: Color(0xFF81D4FA),
      strokeColor: Color(0xFF01579B),
      collisionClass: CollisionClass.structure,
      recommendedClearance: 1,
      icon: Icons.water,
      pattern: ElementPattern.water,
    ),
    ElementType(
      id: 'sandbox',
      name: 'Sandkasten',
      category: ElementCategory.equipment,
      defaultWidth: 1.5,
      defaultDepth: 1.5,
      shape: ElementShape.rect,
      fillColor: Color(0xFFFFF59D),
      strokeColor: Color(0xFFF9A825),
      collisionClass: CollisionClass.furniture,
      icon: Icons.beach_access,
      pattern: ElementPattern.sand,
    ),
    ElementType(
      id: 'play_area',
      name: 'Spielbereich',
      category: ElementCategory.equipment,
      defaultWidth: 4,
      defaultDepth: 3,
      shape: ElementShape.rect,
      fillColor: Color(0x66FFCC80),
      strokeColor: Color(0xFFEF6C00),
      collisionClass: CollisionClass.zone,
      recommendedClearance: 1.5,
      icon: Icons.toys,
    ),
    // --- Wege ---
    ElementType(
      id: 'path',
      name: 'Wegabschnitt',
      category: ElementCategory.path,
      defaultWidth: 1,
      defaultDepth: 4,
      shape: ElementShape.rect,
      fillColor: Color(0xFFCFD8DC),
      strokeColor: Color(0xFF607D8B),
      collisionClass: CollisionClass.ground,
      maxSize: 60,
      icon: Icons.route,
      pattern: ElementPattern.tiles,
    ),
  ];

  static final Map<String, ElementType> _byId = {for (final t in all) t.id: t};

  static ElementType? byId(String id) => _byId[id];

  static List<ElementType> byCategory(ElementCategory category) =>
      all.where((t) => t.category == category).toList();
}
