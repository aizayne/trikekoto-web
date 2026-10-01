import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trikekoto_app/core/firestore/collection_paths.dart';
import 'package:trikekoto_app/core/map/osm_map.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';
import 'package:trikekoto_app/features/commuter/application/commuter_location.dart';
import 'package:trikekoto_app/features/commuter/application/dispatch_controller.dart'
    as commuter;
import 'package:trikekoto_app/features/commuter/presentation/commuter_booking_screen.dart';
import 'package:trikekoto_app/features/drivers/application/driver_controllers.dart';
import 'package:trikekoto_app/features/drivers/data/driver.dart';
import 'package:trikekoto_app/features/drivers/presentation/driver_dashboard_screen.dart';
import 'package:trikekoto_app/features/identity/application/id_verification_service.dart';
import 'package:trikekoto_app/features/rides/data/ride.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

/// How far away the other party is, on both sides of a ride.
///
/// Two questions, one measure: the commuter's "how far is my trike", and the
/// driver's "how far is this pickup" — the one number that decides an accept,
/// which the offer used to leave to guesswork.

/// Straight-line 0.009° of latitude is ~1 km, so the fixtures sit at round
/// numbers and the assertions read as distances rather than as arithmetic.
const _pickup = GeoPoint(14.9700, 120.1500);
const _driverAt = GeoPoint(14.9880, 120.1500); // 2.0 km from the pickup
final _commuterAt = LatLng(14.9790, 120.1500); // 1.0 km from the driver

class _FixedTheme extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

/// Transparent tiles: the tracking map draws in a widget test without
/// reaching for the network, which a test cannot do.
class _BlankTiles extends TileProvider {
  static final _pixel = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_pixel);
}

Ride _ride(RideStatus status, {GeoPoint? driverLocation = _driverAt}) =>
    Ride.fromMap({
      'commuterUid': 'u1',
      'commuterName': 'Maria',
      'commuterPhone': '09181234567',
      'status': status.wire,
      'pickup': {'label': 'Plaza', 'geopoint': _pickup},
      'dropoff': {'label': 'Palengke', 'geopoint': const GeoPoint(14.96, 120.16)},
      'assignedDriver': 'juan@toda.ph',
      'driverSnapshot': {
        'email': 'juan@toda.ph',
        'firstName': 'Juan',
        'phone': '09171234567',
        'plateNumber': 'ABC1234',
      },
      'driverLocation': driverLocation,
      'createdAt': Timestamp.now(),
    }, 'r1');

Future<void> _pumpCommuter(WidgetTester tester, Ride ride,
    {LatLng? me}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(_FixedTheme.new),
      commuter.myActiveRideProvider.overrideWith((ref) => Stream.value(ride)),
      myRiderProfileProvider.overrideWith((ref) => Stream.value(null)),
      commuterPositionProvider.overrideWith((ref) => Stream.value(me)),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: const CommuterBookingScreen(),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Online, without touching GPS or Firestore.
class _OnlinePresence extends PresenceController {
  @override
  bool build() => true;
}

/// A driver whose app has already reported a fix, or has not yet.
class _FixedPosition extends DriverPosition {
  _FixedPosition(this.at);
  final GeoPoint? at;

  @override
  GeoPoint? build() => at;
}

Future<void> _pumpDriver(WidgetTester tester, {GeoPoint? at}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final driver = Driver.fromMap({
    'email': 'juan@toda.ph',
    'uid': 'uid-1',
    'firstName': 'Juan',
    'lastName': 'Dela Cruz',
    'phone': '09171234567',
    'plateNumber': 'ABC1234',
    'todaChapter': 'Barangay Uno TODA',
    'status': DriverStatus.approved,
  }, 'juan@toda.ph');

  await tester.pumpWidget(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(_FixedTheme.new),
      myDriverProfileProvider.overrideWith((ref) => Stream.value(driver)),
      myIdVerifiedProvider.overrideWith((ref) => Stream.value(true)),
      myOffersProvider
          .overrideWith((ref) => Stream.value([_ride(RideStatus.searching)])),
      myActiveRideProvider.overrideWith((ref) => Stream.value(null)),
      myActiveRidesProvider.overrideWith((ref) => Stream.value(const <Ride>[])),
      presenceProvider.overrideWith(_OnlinePresence.new),
      driverPositionProvider.overrideWith(() => _FixedPosition(at)),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: const DriverDashboardScreen(),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    OsmTiles.debugTileProvider = _BlankTiles();
    addTearDown(() => OsmTiles.debugTileProvider = null);
  });

  group('the commuter sees how far the trike is', () {
    testWidgets('measured to where the passenger is standing', (tester) async {
      await _pumpCommuter(tester, _ride(RideStatus.accepted),
          me: _commuterAt);

      expect(find.text('1.0 km from you'), findsOneWidget);
    });

    testWidgets('falls back to the pickup when the phone has no fix',
        (tester) async {
      await _pumpCommuter(tester, _ride(RideStatus.accepted));

      expect(find.text('2.0 km from the pickup'), findsOneWidget);
    });

    testWidgets('says nothing until the driver app has pinged',
        (tester) async {
      await _pumpCommuter(tester,
          _ride(RideStatus.accepted, driverLocation: null), me: _commuterAt);

      expect(find.textContaining('km from'), findsNothing);
      // The card itself still works without a position.
      expect(find.text('Juan'), findsOneWidget);
    });

    testWidgets('drops it once the passenger is aboard', (tester) async {
      await _pumpCommuter(tester, _ride(RideStatus.inTransit),
          me: _commuterAt);

      expect(find.textContaining('km from'), findsNothing);
      // Only the card's own heading says it now.
      expect(find.text('On the way to your drop-off'), findsOneWidget);
    });
  });

  group('the driver sees how far the pickup is', () {
    testWidgets('on the offer, before deciding', (tester) async {
      await _pumpDriver(tester, at: const GeoPoint(14.9880, 120.1500));

      expect(find.text('Pickup: 2.0 km away'), findsOneWidget);
    });

    testWidgets('and nothing at all without a fix', (tester) async {
      await _pumpDriver(tester);

      expect(find.textContaining('Pickup:'), findsNothing);
      // The offer is still there to accept or decline.
      expect(find.text('Accept'), findsOneWidget);
    });
  });
}
