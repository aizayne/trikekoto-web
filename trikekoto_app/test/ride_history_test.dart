import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/features/rides/application/ride_history.dart';
import 'package:trikekoto_app/features/rides/data/ride.dart';
import 'package:trikekoto_app/features/rides/presentation/ride_history_screen.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

/// Ride history, as each audience sees it.
///
/// The property worth pinning is who sees what about whom: a driver keeps a
/// passenger's name but not their phone number once the ride is over.

const _juan = {
  'email': 'juan@toda.ph',
  'firstName': 'Juan',
  'phone': '09171234567',
  'plateNumber': 'ABC 1234',
};

Ride _ride(
  String id, {
  String status = 'completed',
  String? cancelledBy,
  int? rating,
  bool withDriver = true,
  String service = 'regular',
}) =>
    Ride.fromMap({
      'commuterUid': 'u1',
      'commuterName': 'Maria',
      'commuterPhone': '09181234567',
      'status': status,
      'cancelledBy': ?cancelledBy,
      'rating': rating,
      'serviceType': service,
      'pickup': {'label': 'Plaza'},
      'dropoff': {'label': 'Palengke'},
      'assignedDriver': withDriver ? 'juan@toda.ph' : null,
      'driverSnapshot': withDriver ? _juan : null,
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 15, 8, 30)),
    }, id);

Future<void> _pump(
    WidgetTester tester, HistoryAudience audience, List<Ride> rides) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [
      rideHistoryProvider.overrideWith((ref, _) => Stream.value(rides)),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: RideHistoryScreen(audience: audience),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a commuter sees the route, the outcome, the driver and the rating',
      (tester) async {
    await _pump(tester, HistoryAudience.commuter, [_ride('r1', rating: 5)]);

    expect(find.text('Plaza  →  Palengke'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Driver: Juan · ABC 1234'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Regular — 1 passenger'), findsOneWidget);
  });

  testWidgets('a driver sees the passenger by name, never by phone number',
      (tester) async {
    await _pump(tester, HistoryAudience.driver, [_ride('r1')]);

    expect(find.text('Commuter: Maria'), findsOneWidget);
    expect(find.textContaining('09181234567'), findsNothing);
  });

  testWidgets('an admin sees both parties in full, and can filter',
      (tester) async {
    await _pump(tester, HistoryAudience.admin, [_ride('r1')]);

    expect(find.text('Commuter: Maria · 09181234567'), findsOneWidget);
    expect(find.text('Driver: Juan · ABC 1234'), findsOneWidget);
    for (final chip in ['All', 'Completed', 'Cancelled', 'No driver found']) {
      expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget);
    }
  });

  testWidgets('each outcome is named, including who called it off',
      (tester) async {
    await _pump(tester, HistoryAudience.commuter, [
      _ride('c1', status: 'cancelled', cancelledBy: 'driver'),
      _ride('c2', status: 'cancelled', cancelledBy: 'commuter'),
      _ride('e1', status: 'expired', withDriver: false),
      _ride('s1', status: 'searching', withDriver: false),
    ]);

    expect(find.text('Cancelled by driver'), findsOneWidget);
    expect(find.text('Cancelled by commuter'), findsOneWidget);
    expect(find.text('No driver found'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
  });

  testWidgets('a special trip is labelled as one', (tester) async {
    await _pump(tester, HistoryAudience.driver, [_ride('r1', service: 'special')]);
    expect(find.text('Special trip — fare for 5 passengers'), findsOneWidget);
  });

  testWidgets('no rides says so rather than showing a blank screen',
      (tester) async {
    await _pump(tester, HistoryAudience.commuter, const []);
    expect(find.text('No rides yet'), findsOneWidget);
  });

  testWidgets('"Show more" appears only when a whole page came back',
      (tester) async {
    await _pump(tester, HistoryAudience.driver,
        [for (var i = 0; i < historyPageSize - 1; i++) _ride('r$i')]);
    await tester.scrollUntilVisible(find.text('Plaza  →  Palengke').last, 400);
    expect(find.text('Show more'), findsNothing);
  });

  testWidgets('a full page offers more', (tester) async {
    await _pump(tester, HistoryAudience.driver,
        [for (var i = 0; i < historyPageSize; i++) _ride('r$i')]);
    await tester.scrollUntilVisible(find.text('Show more'), 400);
    expect(find.text('Show more'), findsOneWidget);
  });
}
