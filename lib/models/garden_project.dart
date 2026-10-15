import 'garden_element.dart';
import 'planning_settings.dart';

/// Aktuelle Version des JSON-Formats. Beim Laden älterer Versionen kann hier
/// künftig migriert werden.
const int kProjectSchemaVersion = 1;

/// Obergrenzen für Gartenmaße (Meter). Verhindert unrealistische Eingaben.
const double kMinGardenSize = 1;
const double kMaxGardenSize = 200;

/// Ein Gartenprojekt. Unveränderlich; Änderungen erzeugen Kopien.
class GardenProject {
  const GardenProject({
    required this.id,
    required this.name,
    required this.width,
    required this.length,
    required this.createdAt,
    required this.modifiedAt,
    this.elements = const [],
    this.planning = const PlanningSettings(),
    this.isSample = false,
  });

  final String id;
  final String name;

  /// Gartenbreite in Metern (x-Richtung).
  final double width;

  /// Gartenlänge in Metern (y-Richtung).
  final double length;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final List<GardenElement> elements;
  final PlanningSettings planning;

  /// Kennzeichnet den mitgelieferten Beispielgarten.
  final bool isSample;

  double get area => width * length;

  GardenProject copyWith({
    String? name,
    double? width,
    double? length,
    DateTime? modifiedAt,
    List<GardenElement>? elements,
    PlanningSettings? planning,
    bool? isSample,
  }) => GardenProject(
    id: id,
    name: name ?? this.name,
    width: width ?? this.width,
    length: length ?? this.length,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    elements: elements ?? this.elements,
    planning: planning ?? this.planning,
    isSample: isSample ?? this.isSample,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': kProjectSchemaVersion,
    'id': id,
    'name': name,
    'width': width,
    'length': length,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
    'isSample': isSample,
    'planning': planning.toJson(),
    'elements': elements.map((e) => e.toJson()).toList(),
  };

  /// Erstellt ein Projekt aus JSON. Wirft [FormatException] bei
  /// beschädigten oder unplausiblen Daten.
  static GardenProject fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version is! int || version < 1 || version > kProjectSchemaVersion) {
      throw FormatException('Nicht unterstützte Schemaversion "$version".');
    }
    final id = json['id'];
    final name = json['name'];
    final width = json['width'];
    final length = json['length'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Projekt ohne gültige ID.');
    }
    if (name is! String) {
      throw const FormatException('Projekt ohne Namen.');
    }
    if (width is! num || length is! num) {
      throw const FormatException('Projekt ohne gültige Maße.');
    }
    final w = width.toDouble();
    final l = length.toDouble();
    if (!isValidGardenSize(w) || !isValidGardenSize(l)) {
      throw FormatException('Unplausible Gartenmaße ($w × $l m).');
    }
    final rawElements = json['elements'];
    final elements = <GardenElement>[];
    if (rawElements is List) {
      for (final raw in rawElements) {
        if (raw is Map<String, dynamic>) {
          elements.add(GardenElement.fromJson(raw));
        } else if (raw is Map) {
          elements.add(GardenElement.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    final planningRaw = json['planning'];
    return GardenProject(
      id: id,
      name: name,
      width: w,
      length: l,
      createdAt: _parseDate(json['createdAt']),
      modifiedAt: _parseDate(json['modifiedAt']),
      isSample: json['isSample'] == true,
      planning: PlanningSettings.fromJson(
        planningRaw is Map ? Map<String, dynamic>.from(planningRaw) : null,
      ),
      elements: elements,
    );
  }

  static DateTime _parseDate(Object? raw) {
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  static bool isValidGardenSize(double v) =>
      v.isFinite && v >= kMinGardenSize && v <= kMaxGardenSize;
}
