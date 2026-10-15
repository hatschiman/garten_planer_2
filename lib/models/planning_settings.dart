/// Gartenstil für die automatische Planung.
enum GardenStyle {
  family('Familiengarten'),
  kitchen('Nutzgarten'),
  relax('Entspannung');

  const GardenStyle(this.label);
  final String label;

  static GardenStyle fromName(Object? name) => GardenStyle.values.firstWhere(
    (s) => s.name == name,
    orElse: () => GardenStyle.family,
  );
}

/// Einstellungen der automatischen Planung. Werden mit dem Projekt gespeichert.
class PlanningSettings {
  const PlanningSettings({
    this.style = GardenStyle.family,
    this.targetLawnShare = 0.4,
    this.keepExisting = true,
    this.wishes = const {},
  });

  final GardenStyle style;

  /// Gewünschter freier Anteil (0..1) der Gartenfläche, der nicht von
  /// Hindernissen belegt ist (Rasen/Freifläche).
  final double targetLawnShare;

  /// Bereits platzierte Elemente beibehalten (fixierte immer).
  final bool keepExisting;

  /// Gewünschte Elemente: Typ-ID -> Anzahl.
  final Map<String, int> wishes;

  PlanningSettings copyWith({
    GardenStyle? style,
    double? targetLawnShare,
    bool? keepExisting,
    Map<String, int>? wishes,
  }) => PlanningSettings(
    style: style ?? this.style,
    targetLawnShare: targetLawnShare ?? this.targetLawnShare,
    keepExisting: keepExisting ?? this.keepExisting,
    wishes: wishes ?? this.wishes,
  );

  Map<String, dynamic> toJson() => {
    'style': style.name,
    'targetLawnShare': targetLawnShare,
    'keepExisting': keepExisting,
    'wishes': wishes,
  };

  static PlanningSettings fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PlanningSettings();
    final rawWishes = json['wishes'];
    final wishes = <String, int>{};
    if (rawWishes is Map) {
      for (final entry in rawWishes.entries) {
        final v = entry.value;
        if (entry.key is String && v is num && v > 0) {
          wishes[entry.key as String] = v.toInt();
        }
      }
    }
    final share = json['targetLawnShare'];
    return PlanningSettings(
      style: GardenStyle.fromName(json['style']),
      targetLawnShare: share is num ? share.toDouble().clamp(0.0, 0.9) : 0.4,
      keepExisting: json['keepExisting'] != false,
      wishes: wishes,
    );
  }
}
