import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:trikekoto_app/core/map/osm_map.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';

/// The commuter's own position marker.
///
/// The property worth protecting is a privacy one: this position is read on
/// the device and drawn on the device. Nothing writes it anywhere. If a future
/// change starts sending it to Firestore, that is a standing record of where
/// an anonymous passenger physically is, created for no operational gain —
/// the driver already has the pickup point.

const _manila = LatLng(14.5995, 120.9842);

Future<void> _pump(WidgetTester tester, List<Marker> markers) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(builder: (context) => Stack(children: [
            for (final m in markers) SizedBox(width: 24, height: 24, child: m.child),
          ])),
    ),
  ));
}

void main() {
  group('the you-marker', () {
    testWidgets('is a plain dot, not a pin', (tester) async {
      late Marker marker;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(builder: (context) {
          marker = MapMarkers.you(context, _manila);
          return const SizedBox.shrink();
        }),
      ));

      // Pins mark places someone chose. This marks where you happen to be
      // standing, and must not compete with them for attention.
      expect(marker.width, 22);
      expect(marker.height, 22);
      expect(marker.point, _manila);
    });

    testWidgets('carries no icon glyph', (tester) async {
      late Marker you;
      late Marker pickup;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(builder: (context) {
          you = MapMarkers.you(context, _manila);
          pickup = MapMarkers.pickup(context, _manila);
          return const SizedBox.shrink();
        }),
      ));

      await _pump(tester, [you]);
      expect(find.byType(Icon), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, [pickup]);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('is smaller than the pins it sits among', (tester) async {
      late Marker you;
      late Marker driver;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(builder: (context) {
          you = MapMarkers.you(context, _manila);
          driver = MapMarkers.driver(context, _manila);
          return const SizedBox.shrink();
        }),
      ));

      expect(you.width, lessThan(driver.width));
    });
  });
}
