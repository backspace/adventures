import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:landgrab/widgets/liberated_zone_layer.dart';

void main() {
  group('LiberatedZoneStyle.copyWith', () {
    test('replaces only the named field, keeps the rest', () {
      const base = LiberatedZoneStyle();
      final wider = base.copyWith(spacing: 30);

      expect(wider.spacing, 30);
      // Untouched fields carry through.
      expect(wider.strokeWidth, base.strokeWidth);
      expect(wider.speed, base.speed);
      expect(wider.angleDeg, base.angleDeg);
      expect(wider.washAlpha, base.washAlpha);
      expect(wider.lineAlpha, base.lineAlpha);
    });
  });

  group('LiberatedZoneLayer', () {
    testWidgets('renders nothing when there are no liberated shapes',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LiberatedZoneLayer(shapes: [], phase: 0),
        ),
      );

      // The empty shortcut returns before touching the map camera, so it
      // paints nothing and needs no FlutterMap ancestor.
      expect(find.byType(CustomPaint).evaluate().where((e) {
        final w = e.widget as CustomPaint;
        return w.painter.runtimeType.toString().contains('Hatch');
      }), isEmpty);
    });

    test('a shape carries its ring and holes through unchanged', () {
      final ring = [
        const LatLng(49.88, -97.13),
        const LatLng(49.89, -97.13),
        const LatLng(49.89, -97.12),
      ];
      final hole = [
        const LatLng(49.885, -97.128),
        const LatLng(49.887, -97.128),
        const LatLng(49.887, -97.126),
      ];
      final shape = LiberatedShape(ring: ring, holes: [hole]);

      expect(shape.ring, ring);
      expect(shape.holes.single, hole);
    });
  });
}
