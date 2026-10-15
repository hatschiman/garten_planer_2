import 'package:flutter/material.dart';

import '../app_state.dart';
import '../editor/editor_controller.dart';
import '../models/element_type.dart';
import '../models/garden_element.dart';
import '../models/garden_project.dart';
import 'catalog_sheet.dart';
import 'export_service.dart';
import 'garden_canvas.dart';
import 'planner_screen.dart';
import 'properties_sheet.dart';
import 'theme.dart';

/// Editor für ein Gartenprojekt.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.store, required this.projectId});

  final ProjectStore store;
  final String projectId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  late final EditorController _controller;
  final _canvasKey = GlobalKey<GardenCanvasState>();
  bool _sidePanelCatalog = true;

  @override
  void initState() {
    super.initState();
    final project = widget.store.byId(widget.projectId)!;
    _controller = EditorController(project: project, onSave: widget.store.save);
    _controller.addListener(_onChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onChanged);
    _controller.saveNow();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Beim Wechsel in den Hintergrund sofort speichern.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller.saveNow();
    }
  }

  String? _lastSelectedId;

  void _onChanged() {
    // Im breiten Layout bei neuer Auswahl automatisch die Eigenschaften zeigen.
    final sel = _controller.selectedId;
    if (sel != null && sel != _lastSelectedId) _sidePanelCatalog = false;
    if (sel == null) _sidePanelCatalog = true;
    _lastSelectedId = sel;
    setState(() {});
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addElement() async {
    final type = await showCatalogSheet(context);
    if (type == null || !mounted) return;
    _addType(type);
  }

  void _addType(ElementType type) {
    final center = _canvasKey.currentState?.centerWorld;
    final r = _controller.addElement(
      type,
      nearX: center?.dx.clamp(0, _controller.project.width),
      nearY: center?.dy.clamp(0, _controller.project.length),
    );
    if (!r.success) {
      _showMessage(r.message ?? 'Element konnte nicht hinzugefügt werden.');
    }
  }

  Future<void> _openPlanner() async {
    final applied = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PlannerScreen(controller: _controller)),
    );
    if (applied == true && mounted) {
      _canvasKey.currentState?.fitAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vorschlag übernommen.'),
          action: SnackBarAction(
            label: 'Rückgängig',
            onPressed: _controller.undo,
          ),
        ),
      );
    }
  }

  Future<void> _openProperties() async {
    final id = _controller.selectedId;
    if (id == null) return;
    await showPropertiesSheet(
      context,
      controller: _controller,
      elementId: id,
      onMessage: _showMessage,
    );
  }

  Future<void> _export(String what) async {
    try {
      if (what == 'json') {
        await ExportService.shareJson(_controller.project);
      } else {
        await ExportService.sharePng(
          _controller.project,
          _controller.drawOrder(),
        );
      }
    } catch (e) {
      if (mounted) _showMessage('Export fehlgeschlagen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final project = c.project;
    final selected = c.selected;
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900 && size.width > size.height;

    final canvas = GardenCanvas(
      key: _canvasKey,
      controller: c,
      onMessage: _showMessage,
      selectionBarInset: !wide,
    );

    return PopScope(
      onPopInvokedWithResult: (_, _) => c.saveNow(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(project.name, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Rückgängig',
              onPressed: c.canUndo ? c.undo : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Wiederholen',
              onPressed: c.canRedo ? c.redo : null,
              icon: const Icon(Icons.redo),
            ),
            IconButton(
              tooltip: 'Gesamten Garten anzeigen',
              onPressed: () => _canvasKey.currentState?.fitAll(),
              icon: const Icon(Icons.fit_screen),
            ),
            PopupMenuButton<String>(
              tooltip: 'Weitere Optionen',
              onSelected: (v) {
                switch (v) {
                  case 'snap':
                    setState(() => c.snapToGrid = !c.snapToGrid);
                  case 'json':
                  case 'png':
                    _export(v);
                }
              },
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: 'snap',
                  checked: c.snapToGrid,
                  child: const Text('Am Raster einrasten (0,5 m)'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'json',
                  child: ListTile(
                    leading: Icon(Icons.data_object),
                    title: Text('Als JSON teilen'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'png',
                  child: ListTile(
                    leading: Icon(Icons.image_outlined),
                    title: Text('Plan als Bild teilen'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: wide
            ? Row(
                children: [
                  Expanded(
                    child: _canvasWithOverlay(
                      canvas,
                      selected,
                      project,
                      showSelectionBar: false,
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: _SidePanel(
                      controller: c,
                      showCatalog: _sidePanelCatalog || selected == null,
                      onToggle: (v) => setState(() => _sidePanelCatalog = v),
                      onAdd: _addType,
                      onMessage: _showMessage,
                    ),
                  ),
                ],
              )
            : _canvasWithOverlay(canvas, selected, project),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _addElement,
                    icon: const Icon(Icons.add),
                    label: const Text('Element hinzufügen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openPlanner,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Automatisch planen'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _canvasWithOverlay(
    Widget canvas,
    GardenElement? selected,
    GardenProject project, {
    bool showSelectionBar = true,
  }) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(child: canvas),
        Positioned(
          top: 8,
          right: 8,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${fmtMeters(project.width)} × ${fmtMeters(project.length)}'
                ' · ${project.elements.length} Elemente'
                '${_controller.snapToGrid ? ' · Raster an' : ''}',
                style: theme.textTheme.labelMedium,
              ),
            ),
          ),
        ),
        if (selected != null && showSelectionBar)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _SelectionBar(
              controller: _controller,
              onProperties: _openProperties,
              onMessage: _showMessage,
            ),
          ),
        if (selected == null && project.elements.isEmpty)
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: IgnorePointer(
              child: Card(
                color: theme.colorScheme.surfaceContainerLow,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Der Garten ist noch leer. Füge Elemente über „Element '
                    'hinzufügen“ ein oder lass dir Vorschläge berechnen. '
                    'Zum Verschieben ein Element antippen und dann ziehen.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Leiste für das ausgewählte Element mit den wichtigsten Aktionen.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.controller,
    required this.onProperties,
    required this.onMessage,
  });

  final EditorController controller;
  final VoidCallback onProperties;
  final void Function(String) onMessage;

  void _report(EditResult r) {
    if (!r.success && r.message != null) onMessage(r.message!);
  }

  @override
  Widget build(BuildContext context) {
    final e = controller.selected;
    if (e == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: [
            Icon(e.type.icon, color: e.type.strokeColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.displayName,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${fmtMeters(e.width)} × ${fmtMeters(e.depth)}'
                    '${e.locked ? ' · fixiert' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '90° drehen',
              onPressed: e.locked
                  ? null
                  : () => _report(controller.rotate(e.id, 90)),
              icon: const Icon(Icons.rotate_right),
            ),
            IconButton(
              tooltip: e.locked ? 'Entsperren' : 'Fixieren',
              onPressed: () => _report(controller.setLocked(e.id, !e.locked)),
              icon: Icon(e.locked ? Icons.lock : Icons.lock_open),
            ),
            IconButton(
              tooltip: 'Eigenschaften',
              onPressed: onProperties,
              icon: const Icon(Icons.tune),
            ),
            IconButton(
              tooltip: 'Auswahl aufheben',
              onPressed: () => controller.select(null),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seitenpanel für breite Bildschirme (Tablet im Querformat).
class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.controller,
    required this.showCatalog,
    required this.onToggle,
    required this.onAdd,
    required this.onMessage,
  });

  final EditorController controller;
  final bool showCatalog;
  final ValueChanged<bool> onToggle;
  final void Function(ElementType) onAdd;
  final void Function(String) onMessage;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedId;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: [
                const ButtonSegment(value: true, label: Text('Katalog')),
                ButtonSegment(
                  value: false,
                  label: const Text('Eigenschaften'),
                  enabled: selected != null,
                ),
              ],
              selected: {showCatalog},
              onSelectionChanged: (s) => onToggle(s.first),
            ),
          ),
          Expanded(
            child: showCatalog || selected == null
                ? CatalogList(onSelect: onAdd)
                : PropertiesPanel(
                    key: ValueKey(selected),
                    controller: controller,
                    elementId: selected,
                    onMessage: onMessage,
                    onClose: () => onToggle(true),
                  ),
          ),
        ],
      ),
    );
  }
}
