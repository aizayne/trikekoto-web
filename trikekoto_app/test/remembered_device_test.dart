import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/auth/remembered_device.dart';
import 'package:trikekoto_app/core/auth/session_controller.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';
import 'package:trikekoto_app/features/commuter/presentation/rider_sign_in_screen.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

const _device = RememberedDevice(
  uid: 'u1',
  phone: '+639171234567',
  secret: 'a-long-random-secret',
);

class _FixedTheme extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

class _FakeSession extends SessionController {
  _FakeSession({this.refuse = false});
  final bool refuse;
  final used = <RememberedDevice>[];

  @override
  SessionState build() =>
      const SessionState(user: null, role: AppRole.none, loading: false);

  @override
  Future<void> continueOnRememberedPhone(RememberedDevice device) async {
    used.add(device);
    if (refuse) throw StateError('permission-denied');
  }
}

Future<void> _pump(
  WidgetTester tester,
  _FakeSession session,
  RememberedDevice? device,
) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(_FixedTheme.new),
      sessionProvider.overrideWith(() => session),
      rememberedDeviceProvider.overrideWith((ref) async => device),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: const RiderSignInScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('what is kept on the phone', () {
    test('survives being stored', () {
      final back = RememberedDevice.decode(_device.encode())!;
      expect(back.uid, 'u1');
      expect(back.phone, '+639171234567');
      expect(back.secret, 'a-long-random-secret');
    });

    test('anything unreadable just means a code is needed', () {
      for (final raw in [null, '', 'not json', '{"uid":"u1"}']) {
        expect(RememberedDevice.decode(raw), isNull, reason: '$raw');
      }
    });

    test('shows only enough of the number to recognise it', () {
      expect(_device.maskedPhone, '+63•••••••4567');
    });
  });

  group('the sign-in screen', () {
    testWidgets('a new phone asks for a number', (tester) async {
      await _pump(tester, _FakeSession(), null);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.textContaining('Continue as'), findsNothing);
    });

    testWidgets('a remembered phone continues without a code', (tester) async {
      final session = _FakeSession();
      await _pump(tester, session, _device);

      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Continue as +63•••••••4567'));
      await tester.pumpAndSettle();

      expect(session.used, [_device]);
    });

    testWidgets('someone else can still use their own number', (tester) async {
      final session = _FakeSession();
      await _pump(tester, session, _device);

      await tester.tap(find.text('Use a different number'));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsOneWidget);
      expect(session.used, isEmpty);
    });

    testWidgets('a refused phone falls back to a code', (tester) async {
      await _pump(tester, _FakeSession(refuse: true), _device);

      await tester.tap(find.textContaining('Continue as'));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Could not confirm this phone. Use a code instead.'),
          findsOneWidget);
    });
  });
}
