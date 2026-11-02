import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:trikekoto_app/core/map/landmarks.dart';
import 'package:trikekoto_app/core/map/location_picker_screen.dart';
import 'package:trikekoto_app/core/routing/geocoding_service.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

const _plaza = Landmark(id: 'a', name: 'Plaza Uno', point: LatLng(14.6, 120.98));
const _tapat = Landmark(id: 'b', name: 'Tapat ng Plaza', point: LatLng(14.7, 120.9));
const _palengke = Landmark(id: 'c', name: 'Palengke', point: LatLng(14.61, 120.99));
const _terminal = Landmark(id: 'd', name: 'TODA Terminal', point: LatLng(14.62, 121));

void main() {
  group('matching a name', () {
    final all = [_tapat, _terminal, _plaza, _palengke];
    List<String> names(String q) =>
        matchLandmarks(all, q).map((l) => l.name).toList();

    test('ignores case and spaces around the words', () {
      expect(names('  TODA '), ['TODA Terminal']);
    });

    test('a name starting with it ranks above a word inside one', () {
      expect(names('plaza'), ['Plaza Uno', 'Tapat ng Plaza']);
    });

    test('a word starting with it ranks above letters mid-word', () {
      expect(names('ter'), ['TODA Terminal']);
      expect(names('la').first, 'Plaza Uno');
    });

    test('nothing typed matches nothing, rather than everything', () {
      expect(names('   '), isEmpty);
    });

    test('keeps the list short enough to read over the map', () {
      final many = [
        for (var i = 0; i < 20; i++)
          Landmark(id: '$i', name: 'Tindahan $i', point: const LatLng(14, 120)),
      ];
      expect(matchLandmarks(many, 'tin').length, 6);
    });
  });

  group('reading a landmark', () {
    test('needs a name and a point', () {
      final good = Landmark.fromMap(
          'a', {'name': ' Plaza ', 'point': const GeoPoint(14.6, 120.9)});
      expect(good?.name, 'Plaza');
      expect(good?.point, const LatLng(14.6, 120.9));
    });

    test('a bad row is skipped, not thrown', () {
      expect(Landmark.fromMap('a', null), isNull);
      expect(Landmark.fromMap('a', {'name': 'Plaza'}), isNull);
      expect(
        Landmark.fromMap('a', {'name': '  ', 'point': const GeoPoint(1, 1)}),
        isNull,
      );
    });
  });

  group('the map picker', () {
    late int osmCalls;

    Future<void> pump(WidgetTester tester, void Function(Object?) onPicked) async {
      osmCalls = 0;
      final client = MockClient((_) async {
        osmCalls++;
        return http.Response('[]', 200);
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          landmarksProvider
              .overrideWith((ref) => Stream.value(const [_plaza, _palengke])),
          geocodingServiceProvider.overrideWithValue(
              GeocodingService(baseUrl: 'https://example.test', client: client)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => onPicked(
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const LocationPickerScreen(
                        title: 'Pick',
                        initialCenter: LatLng(14.6, 120.98),
                      ),
                    )),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('finds a landmark while typing, without calling OSM',
        (tester) async {
      await pump(tester, (_) {});

      await tester.enterText(find.byType(TextField).first, 'pal');
      await tester.pump();

      expect(find.widgetWithText(ListTile, 'Palengke'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Plaza Uno'), findsNothing);
      expect(osmCalls, 0);
    });

    testWidgets('choosing one fills in its name for the driver', (tester) async {
      Object? picked;
      await pump(tester, (p) => picked = p);

      await tester.enterText(find.byType(TextField).first, 'pal');
      await tester.pump();
      await tester.tap(find.widgetWithText(ListTile, 'Palengke'));
      await tester.pump();
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();

      final location = picked as PickedLocation;
      expect(location.label, 'Palengke');
      expect(location.point, _palengke.point);
    });

    testWidgets('a landmark in view is a named pin that can be tapped',
        (tester) async {
      Object? picked;
      await pump(tester, (p) => picked = p);

      await tester.tap(find.text('Plaza Uno'));
      await tester.pump();
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();

      final location = picked as PickedLocation;
      expect(location.label, 'Plaza Uno');
      expect(location.point, _plaza.point);
    });
  });
}
