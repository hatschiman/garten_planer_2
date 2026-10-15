import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor/editor_controller.dart';
import '../editor/viewport.dart';
import 'garden_painter.dart';

/// Interaktive Zeichenfläche: Zoom, Pan, Auswahl und Verschieben.
///
/// Gestenlogik:
/// - Tippen: Element auswählen (oder Auswahl aufheben).
/// - Ziehen mit einem Finger auf dem AUSGEWÄHLTEN Element: Element verschieben.
/// - Ziehen mit einem Finger auf einem anderen Element oder leerer Fläche:
///   Ansicht verschieben. Langes Drücken auf ein Element startet ebenfalls
///   sofort das Verschieben (auch ohne vorherige Auswahl).
/// - Zwei Finger: Pinch-Zoom um den Fokuspunkt plus Verschieben. Ein
///   laufendes Element-Ziehen wird dabei abgebrochen und zurückgesetzt.
/// - Doppeltippen: Hineinzoomen am Tippunkt.
class GardenCanvas extends StatefulWidget {
  const GardenCanvas({
    super.key,
    required this.controller,
    required this.onMessage,
    this.selectionBarInset = true,
  });

  final EditorController controller;
  final void Function(String message) onMessage;

  /// Ob unten Platz für die Auswahlleiste freigehalten werden muss.
  final bool selectionBarInset;

  @override
  State<GardenCanvas> createState() => GardenCanvasState();
}

class GardenCanvasState extends State<GardenCanvas> {
  PlanViewport? _viewport;
  Size _lastSize = Size.zero;

  // Gestenzustand
  Offset _lastFocal = Offset.zero;
  double _lastScale = 1;
  bool _draggingElement = false;
  Offset _grabOffset = Offset.zero; // Weltvektor: Elementmitte - Griffpunkt
  Offset? _doubleTapPosition;

  PlanViewport get viewport =>
      _viewport ??
      PlanViewport.fitGarden(
        widget.controller.project.width,
        widget.controller.project.length,
        _lastSize == Size.zero ? const Size(360, 480) : _lastSize,
      );

  /// Zeigt den gesamten Garten.
  void fitAll() {
    setState(() {
      _viewport = PlanViewport.fitGarden(
        widget.controller.project.width,
        widget.controller.project.length,
        _lastSize,
        padding: 48,
      );
    });
  }

  /// Weltpunkt in der Mitte der sichtbaren Fläche (für neue Elemente).
  Offset get centerWorld =>
      viewport.screenToWorld(Offset(_lastSize.width / 2, _lastSize.height / 2));

  void _onTapUp(TapUpDetails d) {
    final w = viewport.screenToWorld(d.localPosition);
    final hit = widget.controller.hitTest(w.dx, w.dy);
    widget.controller.select(hit?.id);
  }

  void _onDoubleTap() {
    final p = _doubleTapPosition;
    if (p == null) return;
    setState(() => _viewport = viewport.zoomAt(1.6, p));
  }

  void _onScaleStart(ScaleStartDetails d) {
    _lastFocal = d.localFocalPoint;
    _lastScale = 1;
    _draggingElement = false;
    if (d.pointerCount == 1) {
      final c = widget.controller;
      final w = viewport.screenToWorld(d.localFocalPoint);
      final hit = c.hitTest(w.dx, w.dy);
      if (hit != null && hit.id == c.selectedId && !hit.locked) {
        if (c.beginDrag(hit.id)) {
          _draggingElement = true;
          _grabOffset = Offset(hit.x, hit.y) - w;
        }
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final c = widget.controller;
    if (_draggingElement) {
      if (d.pointerCount > 1) {
        // Zweiter Finger: Element-Drag abbrechen, zu Zoom/Pan wechseln.
        c.cancelDrag();
        _draggingElement = false;
        _lastFocal = d.localFocalPoint;
        _lastScale = d.scale;
        return;
      }
      final w = viewport.screenToWorld(d.localFocalPoint) + _grabOffset;
      c.updateDrag(w.dx, w.dy);
      return;
    }
    final factor = d.scale / _lastScale;
    final delta = d.localFocalPoint - _lastFocal;
    setState(() {
      _viewport = viewport.zoomAt(factor, d.localFocalPoint).pan(delta);
    });
    _lastFocal = d.localFocalPoint;
    _lastScale = d.scale;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_draggingElement) {
      _draggingElement = false;
      final r = widget.controller.endDrag();
      if (!r.success && r.message != null) widget.onMessage(r.message!);
    }
  }

  void _onLongPressStart(LongPressStartDetails d) {
    final c = widget.controller;
    final w = viewport.screenToWorld(d.localPosition);
    final hit = c.hitTest(w.dx, w.dy);
    if (hit == null) return;
    c.select(hit.id);
    if (hit.locked) {
      widget.onMessage(
        '„${hit.displayName}“ ist fixiert. Zum Verschieben erst entsperren.',
      );
      return;
    }
    if (c.beginDrag(hit.id)) {
      HapticFeedback.selectionClick();
      _draggingElement = true;
      _grabOffset = Offset(hit.x, hit.y) - w;
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails d) {
    if (!_draggingElement) return;
    final w = viewport.screenToWorld(d.localPosition) + _grabOffset;
    widget.controller.updateDrag(w.dx, w.dy);
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    if (!_draggingElement) return;
    _draggingElement = false;
    final r = widget.controller.endDrag();
    if (!r.success && r.message != null) widget.onMessage(r.message!);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _lastSize) {
          // Erste Anzeige oder Größenänderung (z. B. Drehung des Geräts):
          // gesamten Garten einpassen.
          _lastSize = size;
          _viewport = PlanViewport.fitGarden(
            widget.controller.project.width,
            widget.controller.project.length,
            size,
            padding: 48,
          );
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _onTapUp,
          onDoubleTapDown: (d) => _doubleTapPosition = d.localPosition,
          onDoubleTap: _onDoubleTap,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          onLongPressStart: _onLongPressStart,
          onLongPressMoveUpdate: _onLongPressMoveUpdate,
          onLongPressEnd: _onLongPressEnd,
          onLongPressCancel: () {
            if (_draggingElement) {
              _draggingElement = false;
              widget.controller.cancelDrag();
            }
          },
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final c = widget.controller;
              return Semantics(
                label:
                    'Gartenplan ${c.project.name}, ${c.elements.length} Elemente',
                child: CustomPaint(
                  size: size,
                  painter: GardenPainter(
                    project: c.project,
                    elements: c.drawOrder(),
                    viewport: viewport,
                    gridStep: c.gridStep,
                    selectedId: c.selectedId,
                    invalidIds: c.isDragging ? const {} : c.conflictingIds(),
                    dragInvalid: c.dragInvalid,
                    // Platz für die Auswahlleiste unten freihalten.
                    bottomInset:
                        c.selectedId != null && widget.selectionBarInset
                        ? 96
                        : 0,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
