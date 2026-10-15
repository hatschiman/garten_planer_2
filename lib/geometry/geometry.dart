import 'dart:math' as math;
import 'dart:ui';

import '../models/element_type.dart';
import '../models/garden_element.dart';

/// Geometrische Hilfsfunktionen. Alle Werte in Metern (Weltkoordinaten).

/// Liefert die vier Eckpunkte eines gedrehten Rechtecks (im Uhrzeigersinn).
List<Offset> rotatedRectCorners(
  double cx,
  double cy,
  double width,
  double depth,
  double rotationDegrees,
) {
  final rad = rotationDegrees * math.pi / 180;
  final c = math.cos(rad);
  final s = math.sin(rad);
  final hw = width / 2;
  final hd = depth / 2;
  Offset rot(double dx, double dy) =>
      Offset(cx + dx * c - dy * s, cy + dx * s + dy * c);
  return [rot(-hw, -hd), rot(hw, -hd), rot(hw, hd), rot(-hw, hd)];
}

/// Eckpunkte eines Elements als konvexes Polygon. Kreise werden als
/// umschreibendes (ungedrehtes) Quadrat behandelt und separat geprüft.
List<Offset> elementCorners(GardenElement e) =>
    rotatedRectCorners(e.x, e.y, e.width, e.depth, e.rotation);

/// Achsenparallele Hüllbox eines Elements (berücksichtigt Rotation).
Rect elementBounds(GardenElement e) {
  if (e.type.shape == ElementShape.circle) {
    final r = e.width / 2;
    return Rect.fromLTRB(e.x - r, e.y - r, e.x + r, e.y + r);
  }
  final corners = elementCorners(e);
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final c in corners) {
    minX = math.min(minX, c.dx);
    minY = math.min(minY, c.dy);
    maxX = math.max(maxX, c.dx);
    maxY = math.max(maxY, c.dy);
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Liegt das Element vollständig innerhalb des Gartens (0..width, 0..length)?
bool isInsideGarden(GardenElement e, double gardenWidth, double gardenLength) {
  const eps = 1e-6;
  final b = elementBounds(e);
  return b.left >= -eps &&
      b.top >= -eps &&
      b.right <= gardenWidth + eps &&
      b.bottom <= gardenLength + eps;
}

/// Prüft, ob der Punkt [p] innerhalb des Elements liegt (Treffertest für
/// Auswahl). Berücksichtigt Rotation und Kreisform.
bool elementContainsPoint(GardenElement e, Offset p) {
  if (e.type.shape == ElementShape.circle) {
    final r = e.width / 2;
    return (p - Offset(e.x, e.y)).distance <= r;
  }
  // Punkt in das lokale, ungedrehte Koordinatensystem zurückdrehen.
  final rad = -e.rotation * math.pi / 180;
  final dx = p.dx - e.x;
  final dy = p.dy - e.y;
  final lx = dx * math.cos(rad) - dy * math.sin(rad);
  final ly = dx * math.sin(rad) + dy * math.cos(rad);
  return lx.abs() <= e.width / 2 && ly.abs() <= e.depth / 2;
}

/// Überlappen sich zwei Elemente geometrisch (Fläche > 0)?
///
/// Rechtecke werden per Separating-Axis-Theorem geprüft, Kreise exakt gegen
/// Kreise bzw. gegen Rechtecke über den nächsten Punkt.
bool elementsOverlap(GardenElement a, GardenElement b) {
  final aCircle = a.type.shape == ElementShape.circle;
  final bCircle = b.type.shape == ElementShape.circle;
  if (aCircle && bCircle) {
    final d = (Offset(a.x, a.y) - Offset(b.x, b.y)).distance;
    return d < (a.width + b.width) / 2 - 1e-9;
  }
  if (aCircle) return _circleRectOverlap(a, b);
  if (bCircle) return _circleRectOverlap(b, a);
  return convexPolygonsOverlap(elementCorners(a), elementCorners(b));
}

bool _circleRectOverlap(GardenElement circle, GardenElement rect) {
  // Kreismittelpunkt in das lokale System des Rechtecks transformieren.
  final rad = -rect.rotation * math.pi / 180;
  final dx = circle.x - rect.x;
  final dy = circle.y - rect.y;
  final lx = dx * math.cos(rad) - dy * math.sin(rad);
  final ly = dx * math.sin(rad) + dy * math.cos(rad);
  final cx = lx.clamp(-rect.width / 2, rect.width / 2);
  final cy = ly.clamp(-rect.depth / 2, rect.depth / 2);
  final dist = math.sqrt((lx - cx) * (lx - cx) + (ly - cy) * (ly - cy));
  return dist < circle.width / 2 - 1e-9;
}

/// Separating Axis Theorem für zwei konvexe Polygone. Berührung an einer
/// Kante zählt nicht als Überlappung.
bool convexPolygonsOverlap(List<Offset> p1, List<Offset> p2) {
  for (final poly in [p1, p2]) {
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      final axis = Offset(-(b.dy - a.dy), b.dx - a.dx);
      final r1 = _project(p1, axis);
      final r2 = _project(p2, axis);
      const eps = 1e-9;
      if (r1.$2 <= r2.$1 + eps || r2.$2 <= r1.$1 + eps) return false;
    }
  }
  return true;
}

(double, double) _project(List<Offset> poly, Offset axis) {
  var minV = double.infinity;
  var maxV = -double.infinity;
  for (final p in poly) {
    final v = p.dx * axis.dx + p.dy * axis.dy;
    minV = math.min(minV, v);
    maxV = math.max(maxV, v);
  }
  return (minV, maxV);
}

/// Abstand zwischen den Hüllboxen zweier Elemente (0 bei Überlappung).
double boundsDistance(GardenElement a, GardenElement b) {
  final ra = elementBounds(a);
  final rb = elementBounds(b);
  final dx = math.max(0.0, math.max(rb.left - ra.right, ra.left - rb.right));
  final dy = math.max(0.0, math.max(rb.top - ra.bottom, ra.top - rb.bottom));
  return math.sqrt(dx * dx + dy * dy);
}

/// Rundet einen Wert auf das nächste Vielfache von [step].
double snapTo(double value, double step) => (value / step).round() * step;
