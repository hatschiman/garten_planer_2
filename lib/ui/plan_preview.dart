import 'package:flutter/material.dart';

import '../editor/viewport.dart';
import '../models/garden_element.dart';
import '../models/garden_project.dart';
import 'garden_painter.dart';

/// Nicht-interaktive Vorschau eines Plans (für Planungsvorschläge).
class PlanPreview extends StatelessWidget {
  const PlanPreview({
    super.key,
    required this.project,
    required this.elements,
    this.highlightIds = const {},
  });

  final GardenProject project;
  final List<GardenElement> elements;
  final Set<String> highlightIds;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: project.width / project.length,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final vp = PlanViewport.fitGarden(
            project.width,
            project.length,
            size,
            padding: 6,
          );
          return CustomPaint(
            size: size,
            painter: GardenPainter(
              project: project,
              elements: elements,
              viewport: vp,
              gridStep: 1,
              showScaleBar: false,
              showDimensions: false,
              highlightIds: highlightIds,
            ),
          );
        },
      ),
    );
  }
}
