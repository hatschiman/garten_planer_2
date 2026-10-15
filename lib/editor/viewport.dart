import 'dart:math' as math;
import 'dart:ui';

/// Abbildung zwischen Weltkoordinaten (Meter) und Ansichtskoordinaten (Pixel).
///
/// screen = world * scale + offset
/// world  = (screen - offset) / scale
///
/// [scale] ist Pixel pro Meter, [offset] die Bildschirmposition des
/// Garten-Ursprungs (linke obere Ecke des Grundstücks).
class PlanViewport {
  const PlanViewport({required this.scale, required this.offset});

  final double scale;
  final Offset offset;

  static const double minScale = 4;
  static const double maxScale = 400;

  Offset worldToScreen(Offset world) => world * scale + offset;

  Offset screenToWorld(Offset screen) => (screen - offset) / scale;

  double metersToPixels(double meters) => meters * scale;

  double pixelsToMeters(double pixels) => pixels / scale;

  PlanViewport copyWith({double? scale, Offset? offset}) =>
      PlanViewport(scale: scale ?? this.scale, offset: offset ?? this.offset);

  /// Verschiebt die Ansicht um [delta] Bildschirmpixel.
  PlanViewport pan(Offset delta) => copyWith(offset: offset + delta);

  /// Zoomt um den Faktor [factor] um den Bildschirmpunkt [focal], sodass der
  /// darunter liegende Weltpunkt an derselben Stelle bleibt.
  PlanViewport zoomAt(double factor, Offset focal) {
    final newScale = (scale * factor).clamp(minScale, maxScale);
    final effective = newScale / scale;
    // Der Weltpunkt unter dem Finger bleibt fix:
    // focal = w*scale + offset  =>  w = (focal - offset)/scale
    // focal = w*newScale + newOffset => newOffset = focal - (focal-offset)*effective
    final newOffset = focal - (focal - offset) * effective;
    return PlanViewport(scale: newScale, offset: newOffset);
  }

  /// Erzeugt einen Viewport, der den gesamten Garten in [viewSize] zeigt.
  static PlanViewport fitGarden(
    double gardenWidth,
    double gardenLength,
    Size viewSize, {
    double padding = 32,
  }) {
    final availW = math.max(1.0, viewSize.width - padding * 2);
    final availH = math.max(1.0, viewSize.height - padding * 2);
    final s = math
        .min(availW / gardenWidth, availH / gardenLength)
        .clamp(minScale, maxScale);
    final contentW = gardenWidth * s;
    final contentH = gardenLength * s;
    final offset = Offset(
      (viewSize.width - contentW) / 2,
      (viewSize.height - contentH) / 2,
    );
    return PlanViewport(scale: s, offset: offset);
  }
}
