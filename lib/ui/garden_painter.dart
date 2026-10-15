import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../editor/viewport.dart';
import '../models/element_type.dart';
import '../models/garden_element.dart';
import '../models/garden_project.dart';

/// Zeichnet Grundstück, Raster, Elemente, Auswahl und Maßstab.
///
/// Alle Elementdaten liegen in Metern; die Umrechnung in Pixel übernimmt
/// ausschließlich [viewport]. Der Painter ändert keinen Zustand.
class GardenPainter extends CustomPainter {
  GardenPainter({
    required this.project,
    required this.elements,
    required this.viewport,
    required this.gridStep,
    this.selectedId,
    this.invalidIds = const {},
    this.dragInvalid = false,
    this.showScaleBar = true,
    this.showDimensions = true,
    this.highlightIds = const {},
    this.bottomInset = 0,
  });

  final GardenProject project;

  /// Elemente in Zeichenreihenfolge (unten zuerst).
  final List<GardenElement> elements;
  final PlanViewport viewport;
  final double gridStep;
  final String? selectedId;

  /// Elemente mit Regelverstoß (rot markiert).
  final Set<String> invalidIds;
  final bool dragInvalid;
  final bool showScaleBar;
  final bool showDimensions;

  /// Z. B. neu geplante Elemente in der Vorschau.
  final Set<String> highlightIds;

  /// Unterer Bereich (Pixel), der von Bedienelementen verdeckt ist.
  final double bottomInset;

  static const Color _plotFill = Color(0xFFE9E2CF);
  static const Color _plotBorder = Color(0xFF3F5F3F);
  static const Color _gridMinor = Color(0x1A000000);
  static const Color _gridMajor = Color(0x33000000);
  static const Color _selection = Color(0xFF1B5E20);
  static const Color _invalid = Color(0xFFC62828);

  @override
  void paint(Canvas canvas, Size size) {
    final topLeft = viewport.worldToScreen(Offset.zero);
    final bottomRight = viewport.worldToScreen(
      Offset(project.width, project.length),
    );
    final plot = Rect.fromPoints(topLeft, bottomRight);

    // Grundstück
    canvas.drawRect(plot, Paint()..color = _plotFill);
    _drawGrid(canvas, plot);

    // Elemente (Clip auf Grundstück nicht nötig: Elemente liegen innerhalb;
    // beim Ziehen über den Rand soll der Verstoß sichtbar sein).
    for (final e in elements) {
      _drawElement(canvas, e);
    }

    // Grundstücksgrenze zuletzt, damit sie über Flächen liegt.
    canvas.drawRect(
      plot,
      Paint()
        ..color = _plotBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    if (showDimensions) _drawDimensions(canvas, plot);
    if (showScaleBar) _drawScaleBar(canvas, size);
  }

  void _drawGrid(Canvas canvas, Rect plot) {
    final minorPx = viewport.metersToPixels(gridStep);
    final drawMinor = minorPx >= 10;
    final majorPx = viewport.metersToPixels(1);
    final drawMajor = majorPx >= 6;
    if (!drawMajor) return;

    final minor = Paint()
      ..color = _gridMinor
      ..strokeWidth = 1;
    final major = Paint()
      ..color = _gridMajor
      ..strokeWidth = 1;

    final step = drawMinor ? gridStep : 1.0;
    for (var x = 0.0; x <= project.width + 1e-9; x += step) {
      final isMajor = (x - x.round()).abs() < 1e-6;
      if (!isMajor && !drawMinor) continue;
      final sx = viewport.worldToScreen(Offset(x, 0)).dx;
      canvas.drawLine(
        Offset(sx, plot.top),
        Offset(sx, plot.bottom),
        isMajor ? major : minor,
      );
    }
    for (var y = 0.0; y <= project.length + 1e-9; y += step) {
      final isMajor = (y - y.round()).abs() < 1e-6;
      if (!isMajor && !drawMinor) continue;
      final sy = viewport.worldToScreen(Offset(0, y)).dy;
      canvas.drawLine(
        Offset(plot.left, sy),
        Offset(plot.right, sy),
        isMajor ? major : minor,
      );
    }
  }

  void _drawElement(Canvas canvas, GardenElement e) {
    final t = e.type;
    final center = viewport.worldToScreen(Offset(e.x, e.y));
    final w = viewport.metersToPixels(e.width);
    final d = viewport.metersToPixels(e.depth);
    final isSelected = e.id == selectedId;
    final isInvalid = invalidIds.contains(e.id) || (isSelected && dragInvalid);
    final isHighlight = highlightIds.contains(e.id);
    final isCircle = t.shape == ElementShape.circle;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (!isCircle) canvas.rotate(e.rotation * math.pi / 180);

    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: d);
    final path = Path();
    if (isCircle) {
      path.addOval(Rect.fromCircle(center: Offset.zero, radius: w / 2));
    } else {
      final radius = t.isSurface ? 2.0 : math.min(6.0, math.min(w, d) / 6);
      path.addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    }

    // Dezenter Schatten für Hindernisse.
    if (!t.isSurface && t.collisionClass != CollisionClass.zone) {
      canvas.drawPath(
        path.shift(const Offset(1.5, 2)),
        Paint()..color = Colors.black.withValues(alpha: 0.12),
      );
    }

    final fill = Paint()
      ..color = isInvalid
          ? Color.lerp(t.fillColor, _invalid, 0.45)!
          : t.fillColor;
    canvas.drawPath(path, fill);
    _drawPattern(canvas, e, path, rect, isCircle);

    final strokeColor = isInvalid
        ? _invalid
        : isSelected
        ? _selection
        : isHighlight
        ? const Color(0xFF1565C0)
        : t.strokeColor;
    final strokeWidth = isSelected || isInvalid || isHighlight ? 3.0 : 1.5;
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    if (isHighlight && !isSelected) {
      _drawDashedRect(canvas, rect.inflate(4), const Color(0xFF1565C0));
    }

    if (isSelected) {
      // Eckgriffe als Auswahlhinweis (dekorativ, Größe über Eigenschaften).
      final handle = Paint()..color = _selection;
      final white = Paint()..color = Colors.white;
      final r = isCircle
          ? Rect.fromCircle(center: Offset.zero, radius: w / 2)
          : rect;
      for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        canvas.drawCircle(c, 6, white);
        canvas.drawCircle(c, 4.5, handle);
      }
    }

    canvas.restore();

    // Beschriftung unrotiert über dem Mittelpunkt (lesbar bleiben).
    _drawLabel(canvas, e, center, w, d, isInvalid);
  }

  void _drawPattern(
    Canvas canvas,
    GardenElement e,
    Path clip,
    Rect rect,
    bool isCircle,
  ) {
    final pattern = e.type.pattern;
    if (pattern == ElementPattern.none) return;
    final pxPerM = viewport.scale;
    if (pxPerM < 14) return; // zu klein, Muster wäre nur Rauschen
    canvas.save();
    canvas.clipPath(clip);
    final paint = Paint()
      ..color = e.type.strokeColor.withValues(alpha: 0.35)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final spacing = pxPerM * 0.5;
    final area = isCircle
        ? Rect.fromCircle(center: Offset.zero, radius: rect.width / 2)
        : rect;
    switch (pattern) {
      case ElementPattern.grass:
        for (var y = area.top; y < area.bottom; y += spacing) {
          for (var x = area.left; x < area.right; x += spacing) {
            final jitter = ((x * 7 + y * 13) % 10) / 10 * spacing * 0.4;
            final p = Offset(x + jitter, y + jitter);
            canvas.drawLine(p, p + Offset(-2, -5), paint);
            canvas.drawLine(p, p + Offset(2, -5), paint);
          }
        }
      case ElementPattern.tiles:
        for (var x = area.left; x < area.right; x += spacing) {
          canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), paint);
        }
        for (var y = area.top; y < area.bottom; y += spacing) {
          canvas.drawLine(Offset(area.left, y), Offset(area.right, y), paint);
        }
      case ElementPattern.soil:
        final dot = Paint()..color = paint.color;
        for (var y = area.top + spacing / 2; y < area.bottom; y += spacing) {
          for (var x = area.left + spacing / 2; x < area.right; x += spacing) {
            canvas.drawCircle(Offset(x, y), 1.5, dot);
          }
        }
      case ElementPattern.gravel:
        for (var y = area.top + spacing / 3; y < area.bottom; y += spacing) {
          for (var x = area.left + spacing / 3; x < area.right; x += spacing) {
            final off = ((x + y) % 7) - 3;
            canvas.drawCircle(Offset(x + off, y - off), 2.5, paint);
          }
        }
      case ElementPattern.water:
        for (var y = area.top + spacing / 2; y < area.bottom; y += spacing) {
          final p = Path()..moveTo(area.left, y);
          for (var x = area.left; x < area.right; x += spacing) {
            p.quadraticBezierTo(x + spacing / 4, y - 3, x + spacing / 2, y);
            p.quadraticBezierTo(x + spacing * 3 / 4, y + 3, x + spacing, y);
          }
          canvas.drawPath(p, paint);
        }
      case ElementPattern.sand:
        final dot = Paint()..color = paint.color;
        for (
          var y = area.top + spacing / 3;
          y < area.bottom;
          y += spacing / 1.5
        ) {
          for (
            var x = area.left + spacing / 3;
            x < area.right;
            x += spacing / 1.5
          ) {
            canvas.drawCircle(Offset(x + ((y * 3) % 5), y), 1, dot);
          }
        }
      case ElementPattern.hedge:
        final s = spacing / 2;
        for (var x = area.left; x < area.right; x += s) {
          canvas.drawLine(
            Offset(x, area.bottom),
            Offset(x + s / 2, area.top),
            paint,
          );
          canvas.drawLine(
            Offset(x + s / 2, area.top),
            Offset(x + s, area.bottom),
            paint,
          );
        }
      case ElementPattern.none:
        break;
    }
    canvas.restore();
  }

  void _drawLabel(
    Canvas canvas,
    GardenElement e,
    Offset center,
    double w,
    double d,
    bool isInvalid,
  ) {
    final boxW = e.rotation % 180 == 90 ? d : w;
    final boxH = e.rotation % 180 == 90 ? w : d;
    if (boxW < 36 || boxH < 18) {
      if (e.locked) _drawLockIcon(canvas, center, 10);
      return;
    }
    var fontSize = (math.min(boxW, boxH) / 5).clamp(9.0, 14.0);
    TextPainter build(double size) => TextPainter(
      text: TextSpan(
        text: e.displayName,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: isInvalid ? Colors.white : const Color(0xDD1A1A1A),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
      textAlign: TextAlign.center,
    )..layout(maxWidth: boxW - 8);
    // Schrift verkleinern statt Wörter zu trennen; erst darunter kürzen.
    var tp = build(fontSize);
    while (tp.didExceedMaxLines && fontSize > 8) {
      fontSize -= 1;
      tp = build(fontSize);
    }
    final textOffset = center - Offset(tp.width / 2, tp.height / 2);
    // Leichter heller Hintergrund für Lesbarkeit auf Mustern.
    final bg = Rect.fromLTWH(
      textOffset.dx - 3,
      textOffset.dy - 1,
      tp.width + 6,
      tp.height + 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: isInvalid ? 0.0 : 0.55),
    );
    tp.paint(canvas, textOffset);
    if (e.locked) {
      _drawLockIcon(canvas, Offset(center.dx, textOffset.dy - 9), 12);
    }
  }

  void _drawLockIcon(Canvas canvas, Offset at, double size) {
    final icon = Icons.lock;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: const Color(0xFF3E2723),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawCircle(
      at,
      size * 0.7,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawDashedRect(Canvas canvas, Rect r, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dash = 6.0;
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      var pos = 0.0;
      while (pos < len) {
        final end = math.min(pos + dash, len);
        canvas.drawLine(a + dir * pos, a + dir * end, paint);
        pos += dash * 2;
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  void _drawDimensions(Canvas canvas, Rect plot) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: _plotBorder.withValues(alpha: 0.9),
    );
    final paint = Paint()
      ..color = _plotBorder.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    const gap = 10.0;

    // Breite oben
    final yTop = plot.top - gap;
    canvas.drawLine(Offset(plot.left, yTop), Offset(plot.right, yTop), paint);
    canvas.drawLine(
      Offset(plot.left, yTop - 4),
      Offset(plot.left, yTop + 4),
      paint,
    );
    canvas.drawLine(
      Offset(plot.right, yTop - 4),
      Offset(plot.right, yTop + 4),
      paint,
    );
    _text(canvas, _m(project.width), Offset(plot.center.dx, yTop - 10), style);

    // Länge links
    final xLeft = plot.left - gap;
    canvas.drawLine(Offset(xLeft, plot.top), Offset(xLeft, plot.bottom), paint);
    canvas.drawLine(
      Offset(xLeft - 4, plot.top),
      Offset(xLeft + 4, plot.top),
      paint,
    );
    canvas.drawLine(
      Offset(xLeft - 4, plot.bottom),
      Offset(xLeft + 4, plot.bottom),
      paint,
    );
    canvas.save();
    canvas.translate(xLeft - 10, plot.center.dy);
    canvas.rotate(-math.pi / 2);
    _text(canvas, _m(project.length), Offset.zero, style);
    canvas.restore();
  }

  void _drawScaleBar(Canvas canvas, Size size) {
    // Länge so wählen, dass der Balken 60–160 px breit ist.
    const options = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0];
    var meters = options.last;
    for (final o in options) {
      final px = viewport.metersToPixels(o);
      if (px >= 60) {
        meters = o;
        break;
      }
    }
    final px = viewport.metersToPixels(meters);
    final origin = Offset(16, size.height - 24 - bottomInset);
    final bg = Rect.fromLTWH(origin.dx - 8, origin.dy - 22, px + 16, 34);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, const Radius.circular(6)),
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 2;
    canvas.drawLine(origin, origin + Offset(px, 0), paint);
    canvas.drawLine(
      origin + const Offset(0, -5),
      origin + const Offset(0, 5),
      paint,
    );
    canvas.drawLine(origin + Offset(px, -5), origin + Offset(px, 5), paint);
    _text(
      canvas,
      _m(meters),
      origin + Offset(px / 2, -12),
      const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A)),
    );
  }

  static String _m(double v) =>
      '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1).replaceAll('.', ',')} m';

  void _text(Canvas canvas, String s, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GardenPainter old) =>
      old.project != project ||
      old.elements != elements ||
      old.viewport.scale != viewport.scale ||
      old.viewport.offset != viewport.offset ||
      old.selectedId != selectedId ||
      old.invalidIds != invalidIds ||
      old.dragInvalid != dragInvalid ||
      old.highlightIds != highlightIds ||
      old.bottomInset != bottomInset ||
      old.gridStep != gridStep;
}
