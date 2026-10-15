import 'package:flutter/material.dart';

import '../models/element_type.dart';
import 'theme.dart';

/// Elementkatalog, gegliedert nach Kategorien.
class CatalogList extends StatelessWidget {
  const CatalogList({super.key, required this.onSelect, this.scrollController});

  final void Function(ElementType type) onSelect;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (final cat in ElementCategory.values) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            cat.label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
      for (final t in ElementCatalog.byCategory(cat)) {
        children.add(
          ListTile(
            leading: _Swatch(type: t),
            title: Text(t.name),
            subtitle: Text(
              t.shape == ElementShape.circle
                  ? 'Ø ${fmtMeters(t.defaultWidth)}'
                  : '${fmtMeters(t.defaultWidth)} × ${fmtMeters(t.defaultDepth)}',
            ),
            trailing: const Icon(Icons.add_circle_outline),
            onTap: () => onSelect(t),
          ),
        );
      }
    }
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.type});
  final ElementType type;

  @override
  Widget build(BuildContext context) {
    final circle = type.shape == ElementShape.circle;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: type.fillColor.withValues(alpha: 1),
        border: Border.all(color: type.strokeColor, width: 2),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(6),
      ),
      child: Icon(type.icon, size: 20, color: type.strokeColor),
    );
  }
}

/// Öffnet den Katalog als Bottom Sheet. Liefert den gewählten Typ.
Future<ElementType?> showCatalogSheet(BuildContext context) {
  return showModalBottomSheet<ElementType>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Element hinzufügen',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: CatalogList(
              scrollController: scroll,
              onSelect: (t) => Navigator.of(ctx).pop(t),
            ),
          ),
        ],
      ),
    ),
  );
}
