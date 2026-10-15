import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gartenplan/editor/viewport.dart';

void main() {
  group('PlanViewport', () {
    test('Hin- und Rücktransformation sind invers', () {
      const vp = PlanViewport(scale: 37.5, offset: Offset(120, -40));
      const world = Offset(3.25, 7.5);
      final screen = vp.worldToScreen(world);
      final back = vp.screenToWorld(screen);
      expect(back.dx, closeTo(world.dx, 1e-9));
      expect(back.dy, closeTo(world.dy, 1e-9));
    });

    test('Zoom um Fokuspunkt lässt Weltpunkt darunter fix', () {
      const vp = PlanViewport(scale: 20, offset: Offset(50, 60));
      const focal = Offset(200, 300);
      final worldBefore = vp.screenToWorld(focal);
      final zoomed = vp.zoomAt(2.0, focal);
      final worldAfter = zoomed.screenToWorld(focal);
      expect(zoomed.scale, 40);
      expect(worldAfter.dx, closeTo(worldBefore.dx, 1e-9));
      expect(worldAfter.dy, closeTo(worldBefore.dy, 1e-9));
    });

    test('Pan verschiebt Weltpunkte um Pixelbetrag', () {
      const vp = PlanViewport(scale: 10, offset: Offset.zero);
      final panned = vp.pan(const Offset(30, -20));
      final screen = panned.worldToScreen(const Offset(1, 1));
      expect(screen, const Offset(40, -10));
      // Nach Pan und Zoom bleibt Treffertest konsistent.
      final zoomed = panned.zoomAt(1.5, const Offset(100, 100));
      final w = zoomed.screenToWorld(zoomed.worldToScreen(const Offset(4, 2)));
      expect(w.dx, closeTo(4, 1e-9));
      expect(w.dy, closeTo(2, 1e-9));
    });

    test('fitGarden zeigt den gesamten Garten zentriert', () {
      final vp = PlanViewport.fitGarden(
        10,
        5,
        const Size(400, 400),
        padding: 0,
      );
      expect(vp.scale, 40);
      expect(vp.worldToScreen(Offset.zero), const Offset(0, 100));
      expect(vp.worldToScreen(const Offset(10, 5)), const Offset(400, 300));
    });

    test('Zoom bleibt in Grenzen', () {
      const vp = PlanViewport(scale: 10, offset: Offset.zero);
      expect(vp.zoomAt(1000, Offset.zero).scale, PlanViewport.maxScale);
      expect(vp.zoomAt(0.0001, Offset.zero).scale, PlanViewport.minScale);
    });
  });
}
