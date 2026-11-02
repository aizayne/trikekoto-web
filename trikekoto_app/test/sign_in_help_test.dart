import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/auth/session_controller.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';
import 'package:trikekoto_app/features/commuter/presentation/rider_sign_in_screen.dart';
import 'package:trikekoto_app/features/landing/presentation/staff_login_screen.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

class _FixedTheme extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

class _FakeSession extends SessionController {
  final resets = <String>[];

  @override
  SessionState build() =>
      const SessionState(user: null, role: AppRole.none, loading: false);

  @override
  Future<void> sendPasswordReset(String email) async => resets.add(email);
}

Future<_FakeSession> _pump(WidgetTester tester) async {
  final session = _FakeSession();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(_FixedTheme.new),
      sessionProvider.overrideWith(() => session),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: const StaffLoginScreen(),
    ),
  ));
  await tester.pump();
  return session;
}

void main() {
  group('forgot password', () {
    testWidgets('asks for the email before sending anything', (tester) async {
      final session = await _pump(tester);
      await tester.tap(find.text('Forgot password?'));
      await tester.pump();
      expect(session.resets, isEmpty);
      expect(find.text('Enter your email above first.'), findsOneWidget);
    });

    testWidgets('sends the link to the address typed', (tester) async {
      final session = await _pump(tester);
      await tester.enterText(find.byType(TextFormField).first, 'driver@toda.ph ');
      await tester.tap(find.text('Forgot password?'));
      await tester.pump();
      expect(session.resets, ['driver@toda.ph']);
      expect(find.textContaining('we sent a link'), findsOneWidget);
    });
  });

  group('phone sign-in error 39', () {
    test('is recognised from the message, since its code is only "unknown"', () {
      expect(
        isSmsRefused(FirebaseAuthException(
          code: 'unknown',
          message: 'An internal error has occurred. [ Error code:39 ]',
        )),
        isTrue,
      );
    });

    test('other errors keep their own explanation', () {
      expect(
        isSmsRefused(FirebaseAuthException(
          code: 'unknown',
          message: 'An internal error has occurred. [ Error code:17 ]',
        )),
        isFalse,
      );
      expect(isSmsRefused(FirebaseAuthException(code: 'unknown')), isFalse);
    });
  });
}
