import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/garden_project.dart';

/// Ergebnis des Projektdialogs.
class ProjectFormResult {
  const ProjectFormResult({
    required this.name,
    required this.width,
    required this.length,
  });
  final String name;
  final double width;
  final double length;
}

/// Dialog zum Anlegen oder Bearbeiten eines Projekts (Name und Maße).
Future<ProjectFormResult?> showProjectFormDialog(
  BuildContext context, {
  String title = 'Neuer Garten',
  String confirmLabel = 'Anlegen',
  String initialName = 'Mein Garten',
  double initialWidth = 12,
  double initialLength = 8,
  bool sizeEditable = true,
}) {
  return showDialog<ProjectFormResult>(
    context: context,
    builder: (_) => _ProjectFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      initialWidth: initialWidth,
      initialLength: initialLength,
      sizeEditable: sizeEditable,
    ),
  );
}

class _ProjectFormDialog extends StatefulWidget {
  const _ProjectFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
    required this.initialWidth,
    required this.initialLength,
    required this.sizeEditable,
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final double initialWidth;
  final double initialLength;
  final bool sizeEditable;

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _width;
  late final TextEditingController _length;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _width = TextEditingController(text: _fmt(widget.initialWidth));
    _length = TextEditingController(text: _fmt(widget.initialLength));
  }

  @override
  void dispose() {
    _name.dispose();
    _width.dispose();
    _length.dispose();
    super.dispose();
  }

  static String _fmt(double v) =>
      v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1).replaceAll('.', ',');

  static double? parseMeters(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String? _validateSize(String? text) {
    final v = parseMeters(text ?? '');
    if (v == null) return 'Bitte eine Zahl eingeben.';
    if (v < kMinGardenSize) {
      return 'Mindestens ${kMinGardenSize.toStringAsFixed(0)} m.';
    }
    if (v > kMaxGardenSize) {
      return 'Höchstens ${kMaxGardenSize.toStringAsFixed(0)} m.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ProjectFormResult(
        name: _name.text.trim(),
        width: parseMeters(_width.text)!,
        length: parseMeters(_length.text)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Name',
                counterText: '',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Bitte Namen angeben.'
                  : null,
            ),
            if (widget.sizeEditable) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _width,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Breite (m)',
                        helperText: 'links → rechts',
                      ),
                      validator: _validateSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _length,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Länge (m)',
                        helperText: 'oben → unten',
                      ),
                      validator: _validateSize,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Bestätigungsdialog. Liefert true bei Bestätigung.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Löschen',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
