import 'element_type.dart';

/// Ein im Garten platziertes Element. Alle Maße in Metern.
///
/// [x] und [y] bezeichnen den Mittelpunkt des Elements in Gartenkoordinaten
/// (Ursprung links oben, x nach rechts, y nach unten).
/// [rotation] in Grad, im Uhrzeigersinn, um den Mittelpunkt.
class GardenElement {
  const GardenElement({
    required this.id,
    required this.typeId,
    required this.x,
    required this.y,
    required this.width,
    required this.depth,
    this.rotation = 0,
    this.customName,
    this.locked = false,
  });

  final String id;
  final String typeId;
  final double x;
  final double y;
  final double width;
  final double depth;
  final double rotation;
  final String? customName;
  final bool locked;

  ElementType get type =>
      ElementCatalog.byId(typeId) ??
      ElementCatalog.all.first; // Fallback für unbekannte Typen.

  String get displayName =>
      (customName != null && customName!.trim().isNotEmpty)
      ? customName!.trim()
      : type.name;

  GardenElement copyWith({
    String? id,
    String? typeId,
    double? x,
    double? y,
    double? width,
    double? depth,
    double? rotation,
    String? customName,
    bool clearCustomName = false,
    bool? locked,
  }) {
    return GardenElement(
      id: id ?? this.id,
      typeId: typeId ?? this.typeId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      depth: depth ?? this.depth,
      rotation: rotation ?? this.rotation,
      customName: clearCustomName ? null : (customName ?? this.customName),
      locked: locked ?? this.locked,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'typeId': typeId,
    'x': x,
    'y': y,
    'width': width,
    'depth': depth,
    'rotation': rotation,
    if (customName != null) 'customName': customName,
    'locked': locked,
  };

  static GardenElement fromJson(Map<String, dynamic> json) {
    double readNum(String key, {double fallback = 0}) {
      final v = json[key];
      if (v is num) return v.toDouble();
      return fallback;
    }

    final id = json['id'];
    final typeId = json['typeId'];
    if (id is! String || id.isEmpty || typeId is! String) {
      throw const FormatException('Element ohne gültige ID oder Typ.');
    }
    if (ElementCatalog.byId(typeId) == null) {
      throw FormatException('Unbekannter Elementtyp "$typeId".');
    }
    final width = readNum('width', fallback: 1);
    final depth = readNum('depth', fallback: 1);
    if (width <= 0 || depth <= 0 || !width.isFinite || !depth.isFinite) {
      throw FormatException('Ungültige Maße für Element "$id".');
    }
    return GardenElement(
      id: id,
      typeId: typeId,
      x: readNum('x'),
      y: readNum('y'),
      width: width,
      depth: depth,
      rotation: readNum('rotation'),
      customName: json['customName'] is String
          ? json['customName'] as String
          : null,
      locked: json['locked'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GardenElement &&
      other.id == id &&
      other.typeId == typeId &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.depth == depth &&
      other.rotation == rotation &&
      other.customName == customName &&
      other.locked == locked;

  @override
  int get hashCode =>
      Object.hash(id, typeId, x, y, width, depth, rotation, customName, locked);
}
