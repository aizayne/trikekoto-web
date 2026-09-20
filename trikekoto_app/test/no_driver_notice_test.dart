import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';
import 'package:trikekoto_app/features/commuter/application/commuter_location.dart';
import 'package:trikekoto_app/features/commuter/application/dispatch_controller.dart';
import 'package:trikekoto_app/features/commuter/presentation/commuter_booking_screen.dart';
import 'package:trikekoto_app/features/rides/data/ride.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

/// Telling a waiting commuter that nobody has accepted.
///
/// The progress bar and the "asked 3 of 10" line say what the system is
/// doing, not what the passenger wants to know. These pin the two moments
/// where the app says it plainly: at three minutes, and when the search ends.

class _FixedTheme extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

Ride _searching({required Duration ago, String id = 'r1'}) => Ride.fromMap({
      'commuterUid': 'u1',
      'commuterName': 'Maria',
      'commuterPhone': '09181234567',
      'status': 'searching',
      'pickup': {'label': 'Plaza'},
      'dropoff': {'label': 'Palengke'},
      'dispatch': {'depth': 2, 'attemptedDrivers': ['a@toda.ph', 'b@toda.ph']},
      'createdAt': Timestamp.fromDate(DateTime.now().subtract(ago)),
    }, id);

Ride _expired() => Ride.fromMap({
      'commuterUid': 'u1',
      'commuterName': 'Maria',
      'commuterPhone': '09181234567',
      'status': 'expired',
      'cancelledBy': 'system',
      'pickup': {'label': 'Plaza'},
      'dropoff': {'label': 'Palengke'},
      'createdAt': Timestamp.fromDate(DateTime.now()),
    }, 'r1');

Future<void> _pump(WidgetTester tester, Stream<Ride?> rides) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(_FixedTheme.new),
      myActiveRideProvider.overrideWith((ref) => rides),
      myRiderProfileProvider.overrideWith((ref) => Stream.value(null)),
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
}

void main() {
  testWidgets('after three minutes with nobody accepting, the app says so',
      (tester) async {
    await _pump(tester, Stream.value(_searching(ago: const Duration(minutes: 4))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('No driver has accepted yet'), findsOneWidget);
    expect(find.text('Keep waiting'), findsOneWidget);
    expect(find.text('Cancel ride'), findsWidgets);
  });

  testWidgets('a search that has just started says nothing', (tester) async {
    await _pump(tester, Stream.value(_searching(ago: const Duration(seconds: 20))));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('No driver has accepted yet'), findsNothing);
  });

  testWidgets('keeping waiting dismisses it and leaves the ride alone',
      (tester) async {
    await _pump(tester, Stream.value(_searching(ago: const Duration(minutes: 4))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Keep waiting'));
    // Not pumpAndSettle: the searching card spins forever by design, so
    // "settled" never arrives.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('No driver has accepted yet'), findsNothing);
    // The ride is still on screen, still searching.
    expect(find.text('Looking for a driver…'), findsOneWidget);
  });

  testWidgets('it appears once per booking, not on every rebuild',
      (tester) async {
    final rides = StreamController<Ride?>();
    addTearDown(rides.close);
    await _pump(tester, rides.stream);

    rides.add(_searching(ago: const Duration(minutes: 4)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Keep waiting'));
    // Not pumpAndSettle: the searching card spins forever by design, so
    // "settled" never arrives.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The same ride arrives again, as it does on every dispatch write.
    rides.add(_searching(ago: const Duration(minutes: 4)));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('No driver has accepted yet'), findsNothing);
  });

  testWidgets('when the search gives up, it says why', (tester) async {
    final rides = StreamController<Ride?>();
    addTearDown(rides.close);
    await _pump(tester, rides.stream);

    rides.add(_searching(ago: const Duration(seconds: 30)));
    await tester.pump();
    rides.add(_expired());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No driver found. Try again in a few minutes.'),
        findsOneWidget);
  });
}
