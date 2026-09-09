import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/firestore/collection_paths.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';
import 'package:trikekoto_app/features/drivers/application/driver_controllers.dart';
import 'package:trikekoto_app/features/drivers/data/driver.dart';
import 'package:trikekoto_app/features/drivers/presentation/driver_dashboard_screen.dart';
import 'package:trikekoto_app/features/rides/data/ride.dart';

/// Widget tests for the driver dashboard.
///
/// The feature providers are overridden rather than Firestore itself: what is
/// under test is what a driver *sees* for a given state, and going through a
/// fake database would only add a layer that can break independently.
///
/// The gate these cover is a safety one — an unapproved or suspended driver
/// must never be shown the controls that put them on the road.

class _FakePresence extends PresenceController {
  _FakePresence({required this.online});
  final bool online;

  @override
  bool build() => online;
}

Driver _driver(String status) => Driver.fromMap({
      'email': 'juan@toda.ph',
      'uid': 'uid-1',
      'firstName': 'Juan',
      'lastName': 'Dela Cruz',
      'phone': '09171234567',
      'plateNumber': 'ABC1234',
      'todaChapter': 'Barangay Uno TODA',
      'status': status,
      'ratingSum': 22,
      'ratingCount': 5,
    }, 'juan@toda.ph');

/// Theme pinned to light, so widget tests never touch SharedPreferences.
class _FixedTheme extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

Widget _harness({
  required Driver? driver,
  bool online = false,
  List<Ride> offers = const [],
  Ride? activeRide,
}) {
  return ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(_FixedTheme.new),
      myDriverProfileProvider.overrideWith((ref) => Stream.value(driver)),
      myOffersProvider.overrideWith((ref) => Stream.value(offers)),
      myActiveRideProvider.overrideWith((ref) => Stream.value(activeRide)),
      presenceProvider.overrideWith(() => _FakePresence(online: online)),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const DriverDashboardScreen(),
    ),
  );
}

void main() {
  group('driver dashboard — verification gate', () {
    testWidgets('an approved driver gets the online toggle', (tester) async {
      await tester.pumpWidget(_harness(driver: _driver(DriverStatus.approved)));
      await tester.pumpAndSettle();

      expect(find.text('Verified TODA driver'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('a pending driver cannot go online', (tester) async {
      await tester.pumpWidget(_harness(driver: _driver(DriverStatus.pending)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pending verification'), findsOneWidget);
      // The safety property: no route to the road before an admin approves.
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('a suspended driver cannot go online', (tester) async {
      await tester.pumpWidget(_harness(driver: _driver(DriverStatus.suspended)));
      await tester.pumpAndSettle();

      expect(find.textContaining('suspended'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('a rejected driver cannot go online', (tester) async {
      await tester.pumpWidget(_harness(driver: _driver(DriverStatus.rejected)));
      await tester.pumpAndSettle();

      expect(find.textContaining('rejected'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('shows the driver name, plate, and rating', (tester) async {
      await tester.pumpWidget(_harness(driver: _driver(DriverStatus.approved)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Juan Dela Cruz'), findsOneWidget);
      expect(find.textContaining('ABC1234'), findsOneWidget);
      // 22 / 5 = 4.4
      expect(find.textContaining('4.4'), findsOneWidget);
    });

    testWidgets('a missing profile does not render a broken screen',
        (tester) async {
      await tester.pumpWidget(_harness(driver: null));
      await tester.pumpAndSettle();

      expect(find.text('No driver profile found.'), findsOneWidget);
    });
  });

  group('driver dashboard — offers', () {
    testWidgets('an offline driver is told why nothing is arriving',
        (tester) async {
      await tester.pumpWidget(_harness(
        driver: _driver(DriverStatus.approved),
        online: false,
      ));
      await tester.pumpAndSettle();

      // The bug this guards: a driver who forgot the toggle used to stare at
      // an empty list with no explanation.
      expect(find.text('You are offline'), findsOneWidget);
      expect(find.textContaining('Go online'), findsWidgets);
    });

    testWidgets('an online driver with no offers is told to wait',
        (tester) async {
      await tester.pumpWidget(_harness(
        driver: _driver(DriverStatus.approved),
        online: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Waiting for a ride'), findsOneWidget);
    });

    testWidgets('an offer shows the route and both actions', (tester) async {
      final offer = Ride.fromMap(const {
        'commuterUid': 'uid-1',
        'commuterName': 'Maria',
        'commuterPhone': '09181234567',
        'status': 'searching',
        'pickup': {'label': 'Plaza'},
        'dropoff': {'label': 'Palengke'},
        'dispatch': {'offeredTo': 'juan@toda.ph', 'depth': 1},
      }, 'r1');

      await tester.pumpWidget(_harness(
        driver: _driver(DriverStatus.approved),
        online: true,
        offers: [offer],
      ));
      await tester.pumpAndSettle();

      expect(find.text('New ride offer'), findsOneWidget);
      expect(find.textContaining('Plaza'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('a driver already carrying someone is shown no new offers',
        (tester) async {
      final active = Ride.fromMap(const {
        'commuterName': 'Maria',
        'commuterPhone': '09181234567',
        'status': 'accepted',
        'assignedDriver': 'juan@toda.ph',
        'pickup': {'label': 'Plaza'},
        'dropoff': {'label': 'Palengke'},
      }, 'r1');

      final waiting = Ride.fromMap(const {
        'commuterName': 'Jose',
        'status': 'searching',
        'pickup': {'label': 'Simbahan'},
        'dropoff': {'label': 'Terminal'},
        'dispatch': {'offeredTo': 'juan@toda.ph', 'depth': 1},
      }, 'r2');

      await tester.pumpWidget(_harness(
        driver: _driver(DriverStatus.approved),
        online: true,
        offers: [waiting],
        activeRide: active,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Current ride'), findsOneWidget);
      expect(find.text('New ride offer'), findsNothing);
    });
  });

  group('driver dashboard — ride lifecycle controls', () {
    testWidgets('an accepted ride offers Start, not Complete', (tester) async {
      final ride = Ride.fromMap(const {
        'commuterName': 'Maria',
        'commuterPhone': '09181234567',
        'status': 'accepted',
        'assignedDriver': 'juan@toda.ph',
        'pickup': {'label': 'Plaza'},
        'dropoff': {'label': 'Palengke'},
      }, 'r1');

      await tester.pumpWidget(_harness(
        driver: _driver(DriverStatus.approved),
        online: true,
        activeRide: ride,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Start trip'), findsOneWidget);
      expect(find.text('Complete ride'), findsNothing);
    });

    testWidgets('a trip in transit offers Complete', (tester) async {
      final ride = Ride.fromMap(const {
        'commuterName': 'Maria',
        'commuterPhone': '09181234567',
        'status': 'in_transit',
        'assignedDriver': 'juan@toda.ph',
        'pickup': {'label': 'Plaza'},
        'dropoff': {'label': 'Palengke'},
      }, 'r1');

      await tester.pumpWidget(_harness(
        driver: _driver(DriverStatus.approved),
        online: true,
        activeRide: ride,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Complete ride'), findsOneWidget);
      expect(find.text('Start trip'), findsNothing);
    });

    testWidgets('the commuter phone number is reachable on an active ride',
        (tester) async {
      final ride = Ride.fromMap(const {
        'commuterName': 'Maria',
        'commuterPhone': '09181234567',
        'status': 'accepted',
        'assignedDriver': 'juan@toda.ph',
        'pickup': {'label': 'Plaza'},
        'dropoff': {'label': 'Palengke'},
      }, 'r1');

      await tester.pumpWidget(_harness(
        driver: _driver(DriverStatus.approved),
        online: true,
        activeRide: ride,
      ));
      await tester.pumpAndSettle();

      expect(find.text('09181234567'), findsOneWidget);
      expect(find.text('Maria'), findsOneWidget);
    });
  });
}
