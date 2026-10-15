import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../geometry/collision_rules.dart';
import '../geometry/geometry.dart';
import '../models/element_type.dart';
import '../models/garden_element.dart';
import '../models/garden_project.dart';
import '../models/ids.dart';
import '../models/planning_settings.dart';

/// Ergebnis einer Bearbeitungsaktion mit optionaler Nutzermeldung.
class EditResult {
  const EditResult.ok() : success = true, message = null;
  const EditResult.fail(this.message) : success = false;
  final bool success;
  final String? message;
}

/// Zustand des Editors inkl. Undo/Redo. Hält das aktuelle Projekt.
///
/// Undo/Redo arbeitet mit Snapshots der Elementliste. Das ist bei typischen
/// Gartenplänen (wenige Dutzend Elemente) ausreichend und sehr robust.
class EditorController extends ChangeNotifier {
  EditorController({
    required GardenProject project,
    required Future<void> Function(GardenProject) onSave,
    this.autosaveDelay = const Duration(milliseconds: 800),
  }) : // Private Felder können keine benannten Initializing Formals sein.
       // ignore: prefer_initializing_formals
       _project = project,
       // ignore: prefer_initializing_formals
       _onSave = onSave;

  GardenProject _project;
  final Future<void> Function(GardenProject) _onSave;
  final Duration autosaveDelay;

  final List<List<GardenElement>> _undoStack = [];
  final List<List<GardenElement>> _redoStack = [];
  static const int _maxHistory = 100;

  String? _selectedId;
  bool snapToGrid = true;
  double gridStep = 0.5;

  Timer? _autosave;
  bool _dirty = false;

  // --- Drag-Zustand ---------------------------------------------------------
  GardenElement? _dragOriginal;
  bool _dragInvalid = false;

  GardenProject get project => _project;
  List<GardenElement> get elements => _project.elements;
  String? get selectedId => _selectedId;
  GardenElement? get selected => _selectedId == null
      ? null
      : _project.elements.cast<GardenElement?>().firstWhere(
          (e) => e!.id == _selectedId,
          orElse: () => null,
        );
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  bool get isDragging => _dragOriginal != null;

  /// Während eines Drags: Ist die aktuelle Position ungültig?
  bool get dragInvalid => _dragInvalid;
  bool get hasUnsavedChanges => _dirty;

  // --- Auswahl --------------------------------------------------------------

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  /// Treffertest an Weltposition [wx],[wy]. Oben liegende (zuletzt gezeichnete)
  /// Elemente werden bevorzugt; Flächen liegen unter Hindernissen.
  GardenElement? hitTest(double wx, double wy) {
    final ordered = drawOrder();
    for (final e in ordered.reversed) {
      if (elementContainsPoint(e, Offset(wx, wy))) return e;
    }
    return null;
  }

  /// Zeichenreihenfolge: Flächen zuerst (unten), dann Zonen, dann Hindernisse.
  List<GardenElement> drawOrder() {
    int rank(GardenElement e) => switch (e.type.collisionClass) {
      CollisionClass.ground => 0,
      CollisionClass.zone => 1,
      CollisionClass.furniture => 2,
      CollisionClass.structure => 3,
      CollisionClass.plant => 4,
    };
    final list = List<GardenElement>.from(_project.elements);
    // Stabil sortieren: bei gleichem Rang bleibt die Einfügereihenfolge.
    final indexed = list.asMap().entries.toList()
      ..sort((a, b) {
        final r = rank(a.value).compareTo(rank(b.value));
        return r != 0 ? r : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }

  // --- Undo/Redo ------------------------------------------------------------

  void _pushUndo() {
    _undoStack.add(List.unmodifiable(_project.elements));
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List.unmodifiable(_project.elements));
    final previous = _undoStack.removeLast();
    _setElements(previous, pushUndo: false);
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List.unmodifiable(_project.elements));
    final next = _redoStack.removeLast();
    _setElements(next, pushUndo: false);
  }

  void _setElements(List<GardenElement> elements, {bool pushUndo = true}) {
    if (pushUndo) _pushUndo();
    _project = _project.copyWith(
      elements: List.unmodifiable(elements),
      modifiedAt: DateTime.now(),
    );
    if (_selectedId != null && !elements.any((e) => e.id == _selectedId)) {
      _selectedId = null;
    }
    _markDirty();
    notifyListeners();
  }

  // --- Speichern ------------------------------------------------------------

  void _markDirty() {
    _dirty = true;
    _autosave?.cancel();
    _autosave = Timer(autosaveDelay, () => saveNow());
  }

  /// Speichert sofort (z. B. beim Verlassen des Editors).
  Future<void> saveNow() async {
    _autosave?.cancel();
    if (!_dirty) return;
    _dirty = false;
    await _onSave(_project);
  }

  // --- Elemente bearbeiten --------------------------------------------------

  /// Fügt ein neues Element vom Typ [type] hinzu. Bevorzugt wird die
  /// Position [nearX],[nearY] (z. B. Bildschirmmitte); liegt dort ein
  /// Konflikt vor, wird ein freier Platz auf dem Raster gesucht.
  EditResult addElement(ElementType type, {double? nearX, double? nearY}) {
    final w = type.defaultWidth.clamp(0.1, _project.width);
    final d = type.shape == ElementShape.circle
        ? w
        : type.defaultDepth.clamp(0.1, _project.length);
    if (w > _project.width || d > _project.length) {
      return const EditResult.fail('Das Element ist größer als der Garten.');
    }
    final base = GardenElement(
      id: newId('e-'),
      typeId: type.id,
      x: nearX ?? _project.width / 2,
      y: nearY ?? _project.length / 2,
      width: w,
      depth: d,
    );
    final placed = _findFreeSpot(base);
    if (placed == null) {
      return EditResult.fail('Kein freier Platz für „${type.name}“ gefunden.');
    }
    _setElements([..._project.elements, placed]);
    _selectedId = placed.id;
    notifyListeners();
    return const EditResult.ok();
  }

  /// Sucht ausgehend von der Wunschposition spiralförmig auf dem Raster.
  GardenElement? _findFreeSpot(GardenElement base) {
    final step = gridStep;
    final maxRadius = (_project.width + _project.length) / step;
    for (var ring = 0; ring <= maxRadius; ring++) {
      for (var dx = -ring; dx <= ring; dx++) {
        for (var dy = -ring; dy <= ring; dy++) {
          if (ring > 0 && dx.abs() != ring && dy.abs() != ring) continue;
          final candidate = base.copyWith(
            x: _clampX(snapTo(base.x + dx * step, step), base),
            y: _clampY(snapTo(base.y + dy * step, step), base),
          );
          final check = checkPlacement(
            candidate,
            _project.elements,
            _project.width,
            _project.length,
          );
          if (check.isValid) return candidate;
        }
      }
    }
    return null;
  }

  double _clampX(double x, GardenElement e) {
    final half = elementBounds(e.copyWith(x: 0, y: 0)).width / 2;
    if (half * 2 > _project.width) return _project.width / 2;
    return x.clamp(half, _project.width - half);
  }

  double _clampY(double y, GardenElement e) {
    final half = elementBounds(e.copyWith(x: 0, y: 0)).height / 2;
    if (half * 2 > _project.length) return _project.length / 2;
    return y.clamp(half, _project.length - half);
  }

  /// Ersetzt ein Element nach Validierung. Liefert eine Fehlermeldung bei
  /// ungültiger Platzierung (Grenze oder Kollision).
  EditResult updateElement(GardenElement updated, {bool validate = true}) {
    final idx = _project.elements.indexWhere((e) => e.id == updated.id);
    if (idx < 0) return const EditResult.fail('Element nicht gefunden.');
    if (validate) {
      final msg = _validationMessage(updated);
      if (msg != null) return EditResult.fail(msg);
    }
    final list = List<GardenElement>.from(_project.elements);
    list[idx] = updated;
    _setElements(list);
    return const EditResult.ok();
  }

  String? _validationMessage(GardenElement e) {
    if (e.width <= 0 || e.depth <= 0) return 'Maße müssen größer als 0 sein.';
    final check = checkPlacement(
      e,
      _project.elements,
      _project.width,
      _project.length,
    );
    if (!check.insideGarden) {
      return 'Das Element würde über die Grundstücksgrenze hinausragen.';
    }
    if (check.conflicts.isNotEmpty) {
      final names = check.conflicts
          .map((c) => c.displayName)
          .toSet()
          .join(', ');
      return 'Überlappung nicht erlaubt mit: $names.';
    }
    return null;
  }

  /// Breite/Tiefe ändern. Kreise verwenden den Durchmesser (width).
  EditResult resize(String id, {double? width, double? depth}) {
    final e = _byId(id);
    if (e == null) return const EditResult.fail('Element nicht gefunden.');
    if (e.locked) return const EditResult.fail('Das Element ist fixiert.');
    final t = e.type;
    var w = width ?? e.width;
    var d = depth ?? e.depth;
    if (t.shape == ElementShape.circle) d = w;
    if (w < t.minSize || d < t.minSize) {
      return EditResult.fail(
        'Mindestmaß für ${t.name}: ${t.minSize.toStringAsFixed(1)} m.',
      );
    }
    if (w > t.maxSize || d > t.maxSize) {
      return EditResult.fail(
        'Höchstmaß für ${t.name}: ${t.maxSize.toStringAsFixed(0)} m.',
      );
    }
    w = (w * 100).round() / 100;
    d = (d * 100).round() / 100;
    return updateElement(e.copyWith(width: w, depth: d));
  }

  /// Dreht um [degrees] (positiv = im Uhrzeigersinn).
  EditResult rotate(String id, double degrees) {
    final e = _byId(id);
    if (e == null) return const EditResult.fail('Element nicht gefunden.');
    if (e.locked) return const EditResult.fail('Das Element ist fixiert.');
    final r = ((e.rotation + degrees) % 360 + 360) % 360;
    return updateElement(e.copyWith(rotation: r));
  }

  EditResult rename(String id, String? name) {
    final e = _byId(id);
    if (e == null) return const EditResult.fail('Element nicht gefunden.');
    final trimmed = name?.trim();
    return updateElement(
      trimmed == null || trimmed.isEmpty
          ? e.copyWith(clearCustomName: true)
          : e.copyWith(customName: trimmed),
      validate: false,
    );
  }

  EditResult setLocked(String id, bool locked) {
    final e = _byId(id);
    if (e == null) return const EditResult.fail('Element nicht gefunden.');
    return updateElement(e.copyWith(locked: locked), validate: false);
  }

  EditResult duplicate(String id) {
    final e = _byId(id);
    if (e == null) return const EditResult.fail('Element nicht gefunden.');
    final copy = e.copyWith(
      id: newId('e-'),
      locked: false,
      x: e.x + gridStep,
      y: e.y + gridStep,
    );
    final placed = _findFreeSpot(copy);
    if (placed == null) {
      return const EditResult.fail('Kein freier Platz für die Kopie.');
    }
    _setElements([..._project.elements, placed]);
    _selectedId = placed.id;
    notifyListeners();
    return const EditResult.ok();
  }

  EditResult remove(String id) {
    final e = _byId(id);
    if (e == null) return const EditResult.fail('Element nicht gefunden.');
    if (e.locked) {
      return const EditResult.fail('Fixierte Elemente erst entsperren.');
    }
    _setElements(_project.elements.where((x) => x.id != id).toList());
    return const EditResult.ok();
  }

  /// Ersetzt den gesamten Plan (z. B. Übernahme eines Planungsvorschlags).
  /// Ein einzelner Undo-Schritt stellt den vorherigen Plan wieder her.
  void replaceAllElements(List<GardenElement> elements) {
    _setElements(elements);
  }

  void updatePlanningSettings(PlanningSettings settings) {
    _project = _project.copyWith(
      planning: settings,
      modifiedAt: DateTime.now(),
    );
    _markDirty();
    notifyListeners();
  }

  // --- Drag -----------------------------------------------------------------

  /// Beginnt das Verschieben. Liefert false, wenn das Element fixiert ist.
  bool beginDrag(String id) {
    final e = _byId(id);
    if (e == null || e.locked) return false;
    _dragOriginal = e;
    _dragInvalid = false;
    _selectedId = id;
    notifyListeners();
    return true;
  }

  /// Aktualisiert die Position während des Drags ohne Undo-Eintrag.
  /// [wx],[wy]: gewünschter Mittelpunkt in Weltkoordinaten.
  void updateDrag(double wx, double wy) {
    final orig = _dragOriginal;
    if (orig == null) return;
    var x = wx;
    var y = wy;
    if (snapToGrid) {
      x = snapTo(x, gridStep);
      y = snapTo(y, gridStep);
    }
    final moved = orig.copyWith(x: x, y: y);
    final check = checkPlacement(
      moved,
      _project.elements,
      _project.width,
      _project.length,
    );
    _dragInvalid = !check.isValid;
    final idx = _project.elements.indexWhere((e) => e.id == orig.id);
    if (idx < 0) return;
    final list = List<GardenElement>.from(_project.elements);
    list[idx] = moved;
    // Kein Undo-Eintrag, kein Autosave: nur temporärer Zustand.
    _project = _project.copyWith(elements: List.unmodifiable(list));
    notifyListeners();
  }

  /// Beendet den Drag. Bei ungültiger Endposition wird die Ausgangsposition
  /// wiederhergestellt und eine Meldung zurückgegeben.
  EditResult endDrag() {
    final orig = _dragOriginal;
    if (orig == null) return const EditResult.ok();
    final current = _byId(orig.id);
    _dragOriginal = null;
    final invalid = _dragInvalid;
    _dragInvalid = false;
    if (current == null) {
      notifyListeners();
      return const EditResult.ok();
    }
    final moved = current.x != orig.x || current.y != orig.y;
    if (!moved) {
      notifyListeners();
      return const EditResult.ok();
    }
    if (invalid) {
      _restore(orig);
      notifyListeners();
      final msg = _validationMessage(current) ?? 'Ungültige Position.';
      return EditResult.fail(msg);
    }
    // Gültig: Ausgangszustand als EINEN Undo-Eintrag sichern.
    final withOriginal = _project.elements
        .map((e) => e.id == orig.id ? orig : e)
        .toList();
    _undoStack.add(List.unmodifiable(withOriginal));
    if (_undoStack.length > _maxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
    _project = _project.copyWith(modifiedAt: DateTime.now());
    _markDirty();
    notifyListeners();
    return const EditResult.ok();
  }

  /// Bricht den Drag ab und stellt die Ausgangsposition wieder her.
  void cancelDrag() {
    final orig = _dragOriginal;
    if (orig == null) return;
    _dragOriginal = null;
    _dragInvalid = false;
    _restore(orig);
    notifyListeners();
  }

  void _restore(GardenElement orig) {
    final list = _project.elements
        .map((e) => e.id == orig.id ? orig : e)
        .toList();
    _project = _project.copyWith(elements: List.unmodifiable(list));
  }

  GardenElement? _byId(String id) {
    for (final e in _project.elements) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Alle Konflikte im aktuellen Plan (für Anzeige).
  Set<String> conflictingIds() {
    final result = <String>{};
    final els = _project.elements;
    for (var i = 0; i < els.length; i++) {
      final a = els[i];
      if (!isInsideGarden(a, _project.width, _project.length)) result.add(a.id);
      for (var j = i + 1; j < els.length; j++) {
        final b = els[j];
        if (mayOverlap(a.type.collisionClass, b.type.collisionClass)) continue;
        if (elementsOverlap(a, b)) {
          result.add(a.id);
          result.add(b.id);
        }
      }
    }
    return result;
  }

  @override
  void dispose() {
    _autosave?.cancel();
    super.dispose();
  }
}
