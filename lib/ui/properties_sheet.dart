import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor/editor_controller.dart';
import '../models/element_type.dart';
import '../models/garden_element.dart';
import 'theme.dart';

/// Eigenschaften des ausgewählten Elements.
class PropertiesPanel extends StatefulWidget {
  const PropertiesPanel({
    super.key,
    required this.controller,
    required this.elementId,
    required this.onMessage,
    this.onClose,
  });

  final EditorController controller;
  final String elementId;
  final void Function(String) onMessage;
  final VoidCallback? onClose;

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<PropertiesPanel> {
  late final TextEditingController _name;
  late final TextEditingController _width;
  late final TextEditingController _depth;
  String? _syncedForId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _width = TextEditingController();
    _depth = TextEditingController();
    widget.controller.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _name.dispose();
    _width.dispose();
    _depth.dispose();
    super.dispose();
  }

  GardenElement? get _element => widget.controller.elements
      .cast<GardenElement?>()
      .firstWhere((e) => e!.id == widget.elementId, orElse: () => null);

  static String _num(double v) => v
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '')
      .replaceAll('.', ',');

  static double? _parse(String s) =>
      double.tryParse(s.trim().replaceAll(',', '.'));

  void _sync() {
    final e = _element;
    if (!mounted) return;
    if (e == null) {
      widget.onClose?.call();
      return;
    }
    // Textfelder nur neu befüllen, wenn sich die Werte extern geändert haben.
    if (_syncedForId != e.id || _parse(_width.text) != e.width) {
      _width.text = _num(e.width);
    }
    if (_syncedForId != e.id || _parse(_depth.text) != e.depth) {
      _depth.text = _num(e.depth);
    }
    if (_syncedForId != e.id) {
      _name.text = e.customName ?? '';
    }
    _syncedForId = e.id;
    setState(() {});
  }

  void _report(EditResult r) {
    if (!r.success && r.message != null) widget.onMessage(r.message!);
  }

  void _applySize() {
    final e = _element;
    if (e == null) return;
    final w = _parse(_width.text);
    final d = e.type.shape == ElementShape.circle ? w : _parse(_depth.text);
    if (w == null || d == null) {
      widget.onMessage('Bitte gültige Zahlen eingeben.');
      return;
    }
    final r = widget.controller.resize(e.id, width: w, depth: d);
    _report(r);
    if (!r.success) {
      _width.text = _num(e.width);
      _depth.text = _num(e.depth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _element;
    if (e == null) return const SizedBox.shrink();
    final c = widget.controller;
    final theme = Theme.of(context);
    final isCircle = e.type.shape == ElementShape.circle;
    final locked = e.locked;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      shrinkWrap: true,
      children: [
        Row(
          children: [
            Icon(e.type.icon, color: e.type.strokeColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(e.type.name, style: theme.textTheme.titleLarge),
            ),
            if (locked)
              Chip(
                avatar: const Icon(Icons.lock, size: 16),
                label: const Text('fixiert'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Eigener Name (optional)',
            hintText: 'z. B. Apfelbaum',
          ),
          maxLength: 40,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => _report(c.rename(e.id, v)),
          onTapOutside: (_) {
            if (_name.text.trim() != (e.customName ?? '')) {
              _report(c.rename(e.id, _name.text));
            }
          },
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _width,
                enabled: !locked,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: isCircle ? 'Durchmesser (m)' : 'Breite (m)',
                ),
                onSubmitted: (_) => _applySize(),
              ),
            ),
            if (!isCircle) ...[
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _depth,
                  enabled: !locked,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(labelText: 'Tiefe (m)'),
                  onSubmitted: (_) => _applySize(),
                ),
              ),
            ],
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: locked ? null : _applySize,
              child: const Text('Übernehmen'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Position: ${fmtMeters(e.x, decimals: 2)} / ${fmtMeters(e.y, decimals: 2)}'
          ' · Drehung: ${e.rotation.round()}°',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: locked ? null : () => _report(c.rotate(e.id, -90)),
              icon: const Icon(Icons.rotate_left),
              label: const Text('90° links'),
            ),
            OutlinedButton.icon(
              onPressed: locked ? null : () => _report(c.rotate(e.id, 90)),
              icon: const Icon(Icons.rotate_right),
              label: const Text('90° rechts'),
            ),
            OutlinedButton.icon(
              onPressed: locked ? null : () => _report(c.rotate(e.id, 15)),
              icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
              label: const Text('+15°'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fixieren'),
          subtitle: const Text(
            'Fixierte Elemente lassen sich nicht verschieben, ändern oder '
            'durch die automatische Planung verändern.',
          ),
          secondary: Icon(locked ? Icons.lock : Icons.lock_open),
          value: locked,
          onChanged: (v) => _report(c.setLocked(e.id, v)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _report(c.duplicate(e.id)),
                icon: const Icon(Icons.copy),
                label: const Text('Duplizieren'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
                onPressed: locked
                    ? null
                    : () {
                        final r = c.remove(e.id);
                        _report(r);
                        if (r.success) widget.onClose?.call();
                      },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Löschen'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Öffnet die Eigenschaften als Bottom Sheet.
Future<void> showPropertiesSheet(
  BuildContext context, {
  required EditorController controller,
  required String elementId,
  required void Function(String) onMessage,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: PropertiesPanel(
        controller: controller,
        elementId: elementId,
        onMessage: onMessage,
        onClose: () {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        },
      ),
    ),
  );
}
