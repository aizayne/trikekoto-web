import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/firestore/collection_paths.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';
import 'package:trikekoto_app/core/auth/session_controller.dart';
import 'package:trikekoto_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trikekoto_app/features/admin/data/ride_analytics.dart';
import 'package:trikekoto_app/features/admin/presentation/ride_analytics_panel.dart';
import 'package:trikekoto_app/features/drivers/data/driver.dart';
import 'package:trikekoto_app/features/rides/data/ride.dart';

/// Widget tests for the admin panel.
///
/// The verification queue is the one screen where a rendering mistake has a
/// safety consequence: an admin who cannot see a pending driver leaves them
/// unable to work, and one who sees Approve on an already-approved driver
/// will eventually click it by accident.

Driver _driver(String email, String status) => Driver.fromMap({
      'email': email,
      'firstName': 'Juan',
      'lastName': email.split('@').first,
      'phone': '09171234567',
      'plateNumber': 'ABC1234',
      'todaChapter': 'Barangay Uno TODA',
      'status': status,
    }, email);

final _now = DateTime(2026, 8, 26, 14, 30);

Ride _ride(RideStatus status, {int? rating, String? driver}) => Ride(
      id: 'r${identityHashCode(status)}_$rating${driver ?? ''}',
      commuterUid: 'uid',
      commuterName: 'Commuter',
      commuterPhone: '09171234567',
      pickup: const RidePlace(label: 'A'),
      dropoff: const RidePlace(label: 'B'),
      dispatch: const RideDispatch(),
      status: status,
      assignedDriver: driver,
      rating: rating,
      createdAt: Timestamp.fromDate(_now),
    );

RideAnalytics _analytics(List<Ride> rides) => RideAnalytics.from(
      rides,
      window: AnalyticsWindow.today,
      now: _now,
    );

/// Theme pinned to light, so widget tests never touch SharedPreferences.
class _FixedTheme extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

/// A session fixed at build time, so widget tests never reach for Firebase.
class _FixedSession extends SessionController {
  _FixedSession(this._state);
  final SessionState _state;

  @override
  SessionState build() => _state;
}

Widget _harness({
  required List<Driver> drivers,
  List<Ride>? rides,
  int openFeedback = 0,
  bool emailVerified = true,
}) {
  return ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(_FixedTheme.new),
      sessionProvider.overrideWith(() => _FixedSession(SessionState(
            user: null,
            role: AppRole.admin,
            loading: false,
            emailVerified: emailVerified,
          ))),
      allDriversProvider.overrideWith((ref) => Stream.value(drivers)),
      rideAnalyticsProvider
          .overrideWith((ref) async => _analytics(rides ?? const [])),
      openFeedbackCountProvider
          .overrideWith((ref) => Stream.value(openFeedback)),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const AdminDashboardScreen(),
    ),
  );
}

/// Pumps on a tall surface.
///
/// The dashboard is a ListView, and the default 800x600 test viewport cuts it
/// off above the driver tiles — a finder then reports "0 widgets" for content
/// that renders perfectly on a real phone. Explicit sizing beats scrolling in
/// every test.
Future<void> pumpTall(WidgetTester tester, Widget widget) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

void main() {
  group('admin dashboard — verification queue', () {
    testWidgets('a pending driver appears with an Approve action',
        (tester) async {
      await pumpTall(tester, _harness(
        drivers: [_driver('juan@toda.ph', DriverStatus.pending)],
      ));

      expect(find.text('Pending verification'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Suspend'), findsNothing);
    });

    testWidgets('an approved driver offers Suspend, not Approve',
        (tester) async {
      await pumpTall(tester, _harness(
        drivers: [_driver('juan@toda.ph', DriverStatus.approved)],
      ));

      expect(find.text('Suspend'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
    });

    testWidgets('a suspended driver can be approved again', (tester) async {
      await pumpTall(tester, _harness(
        drivers: [_driver('juan@toda.ph', DriverStatus.suspended)],
      ));

      expect(find.text('Approve'), findsOneWidget);
    });

    testWidgets('pending and non-pending drivers are separated',
        (tester) async {
      await pumpTall(tester, _harness(drivers: [
        _driver('one@toda.ph', DriverStatus.pending),
        _driver('two@toda.ph', DriverStatus.approved),
        _driver('three@toda.ph', DriverStatus.suspended),
      ]));

      expect(find.text('Pending verification'), findsOneWidget);
      // Two drivers are not pending.
      expect(find.text('All drivers (2)'), findsOneWidget);
    });

    testWidgets('an empty queue says so rather than showing nothing',
        (tester) async {
      await pumpTall(tester, _harness(drivers: const []));

      expect(find.text('Nothing waiting for review'), findsOneWidget);
      expect(find.text('No drivers yet'), findsOneWidget);
    });

    testWidgets('every driver shows a status pill, not colour alone',
        (tester) async {
      await pumpTall(tester, _harness(drivers: [
        _driver('one@toda.ph', DriverStatus.approved),
      ]));

      // Colour-blind and dark-mode safe: the state is spelled out.
      expect(find.text(DriverStatus.approved), findsOneWidget);
    });
  });

  group('admin dashboard — analytics and links', () {
    testWidgets('headline figures render for the window', (tester) async {
      await pumpTall(tester, _harness(
        drivers: const [],
        rides: [
          _ride(RideStatus.completed, rating: 5),
          _ride(RideStatus.completed, rating: 3),
          _ride(RideStatus.completed),
          _ride(RideStatus.cancelled),
          // Still in flight, so it must not drag the completion rate down.
          _ride(RideStatus.inTransit),
        ],
      ));

      expect(find.text('Rides'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // completed
      expect(find.text('75%'), findsOneWidget); // 3 of 4 concluded
      expect(find.text('4.00'), findsOneWidget); // avg of 5 and 3
    });

    testWidgets('an empty window says so rather than showing zeroes',
        (tester) async {
      await pumpTall(tester, _harness(drivers: const [], rides: const []));

      // A row of 0% and ₱0 reads as total failure rather than no data.
      expect(find.text('No rides in this window.'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
    });

    testWidgets('the window selector offers all three ranges', (tester) async {
      await pumpTall(tester, _harness(drivers: const []));

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
    });

    testWidgets('a driver breakdown appears once rides are attributed',
        (tester) async {
      await pumpTall(tester, _harness(
        drivers: const [],
        rides: [
          _ride(RideStatus.completed, driver: 'ana@x.ph'),
          _ride(RideStatus.completed, driver: 'ana@x.ph'),
        ],
      ));

      expect(find.text('By driver'), findsOneWidget);
      expect(find.text('ana@x.ph'), findsOneWidget);
    });

    // Split rather than pumped twice: re-pumping a second ProviderScope in
    // one test reuses the element, so the new overrides never take effect and
    // the assertion silently tests the first state again.
    testWidgets('no badge when the feedback queue is clear', (tester) async {
      // Every analytics tile is non-zero so a stray "0" can only come from
      // the badge itself — an all-completed window would render 0 for both
      // cancelled and expired and fail this for the wrong reason.
      await pumpTall(
        tester,
        _harness(
          drivers: const [],
          rides: [
            for (var i = 0; i < 5; i++)
              _ride(RideStatus.completed, rating: 4),
            _ride(RideStatus.cancelled),
            _ride(RideStatus.expired),
          ],
          openFeedback: 0,
        ),
      );

      expect(find.text('Feedback'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a badge appears when reports are waiting', (tester) async {
      await pumpTall(
        tester,
        _harness(
          drivers: const [],
          rides: [
            for (var i = 0; i < 5; i++)
              _ride(RideStatus.completed, rating: 4),
            _ride(RideStatus.cancelled),
            _ride(RideStatus.expired),
          ],
          openFeedback: 4,
        ),
      );

      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('both admin sub-screens are reachable', (tester) async {
      await pumpTall(tester, _harness(drivers: const []));

      expect(find.text('Feedback'), findsOneWidget);
      expect(find.text('Dispatch'), findsOneWidget);
    });
  });

  group('admin dashboard — email verification gate', () {
    testWidgets('an unverified admin sees the confirm screen, not the panel',
        (tester) async {
      await pumpTall(tester, _harness(
        drivers: [_driver('juan@toda.ph', DriverStatus.pending)],
        emailVerified: false,
      ));

      // The rules require email_verified for admin reads, but the router only
      // checks the admins document — so without this gate the panel renders
      // and every query fails with an unexplained permission error.
      expect(find.text('Confirm your email to open the admin panel'),
          findsOneWidget);
      expect(find.text('Send verification email'), findsOneWidget);
      expect(find.text('Pending verification'), findsNothing);
    });

    testWidgets('a verified admin sees the panel', (tester) async {
      await pumpTall(tester, _harness(
        drivers: [_driver('juan@toda.ph', DriverStatus.pending)],
        emailVerified: true,
      ));

      expect(find.text('Pending verification'), findsOneWidget);
      expect(find.textContaining('Confirm your email'), findsNothing);
    });

    testWidgets('the resend button is offered before anything is sent',
        (tester) async {
      await pumpTall(tester, _harness(drivers: const [], emailVerified: false));

      // "I have confirmed it" must be reachable without sending first — the
      // console can create a verified user by other means, and a returning
      // admin should not have to send a fresh mail to re-check.
      expect(find.text('I have confirmed it'), findsOneWidget);
    });
  });
}
