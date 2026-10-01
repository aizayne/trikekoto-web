import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/firestore/collection_paths.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';
import 'package:trikekoto_app/features/drivers/application/driver_controllers.dart';
import 'package:trikekoto_app/features/drivers/data/driver.dart';
import 'package:trikekoto_app/features/drivers/presentation/driver_dashboard_screen.dart';
import 'package:trikekoto_app/features/identity/application/id_verification_service.dart';
import 'package:trikekoto_app/features/notifications/application/notifications.dart';
import 'package:trikekoto_app/features/notifications/data/app_notification.dart';
import 'package:trikekoto_app/features/notifications/presentation/notifications_screen.dart';
import 'package:trikekoto_app/features/rides/data/ride.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

/// Telling a driver an admin approved their registration.
///
/// Registration is followed by a wait of hours or days. Nobody watches a
/// screen for that long, so the approval has to survive being missed: a
/// document that stays unread until it is read, not only a push that is gone
/// when it is swiped away.

class _FixedTheme extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

AppNotification _notice({
  String type = NoticeTypes.accountApproved,
  String title = 'Account approved',
  String body = 'Your account has been approved by the admin. You can now log in.',
  bool read = false,
}) =>
    AppNotification.fromMap({
      'type': type,
      'title': title,
      'body': body,
      'createdAt': Timestamp.fromDate(DateTime(2026, 9, 20, 14, 30)),
      'readAt': read ? Timestamp.now() : null,
    }, 'account_approved');

Future<void> _pumpScreen(
  WidgetTester tester,
  List<AppNotification> notices, {
  MarkNoticeRead? markRead,
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(_FixedTheme.new),
      myNotificationsProvider.overrideWith((ref) => Stream.value(notices)),
      if (markRead != null)
        markNoticeReadProvider.overrideWithValue(markRead),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: const NotificationsScreen(),
    ),
  ));
  await tester.pump();
}

class _OfflinePresence extends PresenceController {
  @override
  bool build() => false;
}

/// The dashboard a pending driver is looking at while they wait.
Future<void> _pumpDashboard(
    WidgetTester tester, List<AppNotification> notices) async {
  tester.view.physicalSize = const Size(900, 1600);
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
    'status': DriverStatus.pending,
  }, 'juan@toda.ph');

  await tester.pumpWidget(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(_FixedTheme.new),
      myDriverProfileProvider.overrideWith((ref) => Stream.value(driver)),
      myIdVerifiedProvider.overrideWith((ref) => Stream.value(true)),
      myOffersProvider.overrideWith((ref) => Stream.value(const <Ride>[])),
      myActiveRideProvider.overrideWith((ref) => Stream.value(null)),
      myActiveRidesProvider.overrideWith((ref) => Stream.value(const <Ride>[])),
      presenceProvider.overrideWith(_OfflinePresence.new),
      myNotificationsProvider.overrideWith((ref) => Stream.value(notices)),
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
}

void main() {
  group('the notification itself', () {
    test('unread until it is read', () {
      expect(_notice().isRead, isFalse);
      expect(_notice(read: true).isRead, isTrue);
    });

    test('an empty document parses rather than throwing', () {
      // A notice written by a later build may carry a shape this one has
      // never seen; a throw here would fail the whole listener.
      final notice = AppNotification.fromMap(null, 'x');
      expect(notice.type, isEmpty);
      expect(notice.isRead, isFalse);
    });
  });

  group('the notification area', () {
    testWidgets('shows the approval in the app\'s own words', (tester) async {
      await _pumpScreen(tester, [_notice()]);

      expect(find.text('Account approved'), findsOneWidget);
      expect(
          find.text(
              'Your account has been approved by the admin. You can now log in.'),
          findsOneWidget);
    });

    testWidgets('a type this build has never heard of still reads',
        (tester) async {
      await _pumpScreen(tester, [
        _notice(type: 'something_new', title: 'Server said', body: 'Details'),
      ]);

      expect(find.text('Server said'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
    });

    testWidgets('tapping an unread notice marks it read', (tester) async {
      final marked = <String>[];
      await _pumpScreen(tester, [_notice()],
          markRead: (n) async => marked.add(n.id));

      await tester.tap(find.text('Account approved'));
      await tester.pump();

      expect(marked, ['account_approved']);
    });

    testWidgets('a notice already read is not marked again', (tester) async {
      final marked = <String>[];
      await _pumpScreen(tester, [_notice(read: true)],
          markRead: (n) async => marked.add(n.id));

      await tester.tap(find.text('Account approved'));
      await tester.pump();

      expect(marked, isEmpty);
      // Read, but still there: the record outlives the badge.
      expect(find.text('Account approved'), findsOneWidget);
    });

    testWidgets('marking all read covers every unread notice', (tester) async {
      final marked = <String>[];
      await _pumpScreen(
        tester,
        [_notice(), _notice(type: 'other', title: 'Another')],
        markRead: (n) async => marked.add(n.type),
      );

      await tester.tap(find.text('Mark all read'));
      await tester.pump();

      expect(marked, [NoticeTypes.accountApproved, 'other']);
    });

    testWidgets('says so when there is nothing', (tester) async {
      await _pumpScreen(tester, const []);

      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.text('Mark all read'), findsNothing);
    });
  });

  group('the bell on the driver dashboard', () {
    testWidgets('counts what is waiting', (tester) async {
      await _pumpDashboard(tester, [_notice()]);

      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('is quiet once everything is read', (tester) async {
      await _pumpDashboard(tester, [_notice(read: true)]);

      expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
      expect(find.byType(Badge), findsNothing);
    });
  });
}
