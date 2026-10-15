import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../editor/viewport.dart';
import '../models/garden_element.dart';
import '../models/garden_project.dart';
import '../storage/project_repository.dart';
import 'garden_painter.dart';

/// Export als JSON-Datei bzw. PNG-Bild über den Android-Teilen-Dialog.
class ExportService {
  static String _safeName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[^A-Za-z0-9äöüÄÖÜß_\- ]'), '')
        .trim();
    return cleaned.isEmpty ? 'garten' : cleaned.replaceAll(' ', '_');
  }

  static Future<void> shareJson(GardenProject project) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}${_safeName(project.name)}.gartenplan.json',
    );
    await file.writeAsString(
      ProjectRepository.exportJson(project),
      flush: true,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        title: 'Gartenplan „${project.name}“',
      ),
    );
  }

  /// Rendert den gesamten Plan in ein PNG (längste Seite ca. 2400 px).
  static Future<void> sharePng(
    GardenProject project,
    List<GardenElement> drawOrder,
  ) async {
    const maxSide = 2400.0;
    final ratio = project.width / project.length;
    final size = ratio >= 1
        ? Size(maxSide, maxSide / ratio)
        : Size(maxSide * ratio, maxSide);
    final full = Size(size.width + 160, size.height + 160);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Offset.zero & full,
      Paint()..color = const Color(0xFFFAF7F0),
    );
    final vp = PlanViewport.fitGarden(
      project.width,
      project.length,
      full,
      padding: 80,
    );
    GardenPainter(
      project: project,
      elements: drawOrder,
      viewport: vp,
      gridStep: 0.5,
    ).paint(canvas, full);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      full.width.round(),
      full.height.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('PNG konnte nicht erzeugt werden.');
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}${_safeName(project.name)}.png',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        title: 'Gartenplan „${project.name}“',
      ),
    );
  }
}
