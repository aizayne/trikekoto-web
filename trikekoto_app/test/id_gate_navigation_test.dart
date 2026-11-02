import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trikekoto_app/core/auth/session_controller.dart';
import 'package:trikekoto_app/core/router/app_router.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';
import 'package:trikekoto_app/features/identity/application/id_verification_service.dart';
import 'package:trikekoto_app/features/identity/presentation/id_verification_screen.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

/// The ID screen must have nothing behind it.
///
/// GoRouter builds a nested route on top of its parent, and going back does
/// not run the redirect. So an ID screen nested under `/commuter` put the
/// booking screen one back-press away from someone the gate had just stopped.
/// This drives the real router, because the redirect alone looks correct.
class _User extends Fake implements User {
  @override
  String get uid => 'u1';

  @override
  String? get phoneNumber => '+639170000000';
}

class _FixedTheme extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

class _FakeSession extends SessionController {
  _FakeSession(this.role);
  final AppRole role;

  @override
  SessionState build() =>
      SessionState(user: _User(), role: role, loading: false);
}

Future<(GoRouter, ProviderContainer)> _pumpUnverified(WidgetTester tester, AppRole role) async {
  final container = ProviderContainer(overrides: [
    themeModeProvider.overrideWith(_FixedTheme.new),
    sessionProvider.overrideWith(() => _FakeSession(role)),
    myIdVerifiedProvider.overrideWith((ref) => Stream.value(false)),
    myIdSubmissionProvider.overrideWith((ref) => Stream.value(null)),
  ]);
  // Listened to, as the app's `ref.watch` does. A provider nobody listens to
  // is paused, and would never hear the ID check answer.
  final router = container.listen(routerProvider, (_, _) {}).read();

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  return (router, container);
}

void main() {
  for (final (role, path) in [
    (AppRole.commuter, '/commuter/id'),
    (AppRole.driver, '/driver/id'),
  ]) {
    testWidgets('an unverified ${role.name} has no way back from the ID screen',
        (tester) async {
      final (router, container) = await _pumpUnverified(tester, role);
      addTearDown(container.dispose);

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        path,
      );
      expect(find.byType(IdVerificationScreen), findsOneWidget);
      expect(router.canPop(), isFalse,
          reason: 'a screen behind the gate can be reached with the back button');
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  }

  testWidgets('opened from another screen, the ID screen still goes back',
      (tester) async {
    final (router, container) = await _pumpUnverified(tester, AppRole.commuter);

    router.go('/commuter/profile');
    await tester.pumpAndSettle();
    expect(router.canPop(), isFalse,
        reason: 'the profile must not have the booking screen behind it');

    router.push('/commuter/id');
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/commuter/profile');

    // The profile retries a Firebase read this test has no backend for, and
    // that timer has to go before the test ends.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
