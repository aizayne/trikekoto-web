import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trikekoto_app/core/ui/locale_controller.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart'
    show sharedPreferencesProvider;
import 'package:trikekoto_app/features/landing/presentation/landing_screen.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

/// The language switch.
///
/// Worth testing rather than eyeballing, because the failure mode is quiet:
/// a screen that was migrated to `context.l` but whose ARB key is missing
/// still compiles, and a locale that never reaches `MaterialApp` still shows
/// *a* language — just always the same one. Both look fine until someone
/// presses the button.

Widget _app(WidgetRef Function()? _, {SharedPreferences? prefs}) =>
    ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const _Harness(),
    );

class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        locale: ref.watch(localeProvider).locale,
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: const LandingScreen(),
      );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('starts in Filipino, not the device language', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();

    // The default has to be Filipino for the people this is built for. A
    // handset set to English is not evidence its owner prefers English.
    expect(find.text('Mag-book ng ride'), findsOneWidget);
    expect(find.text('Book a ride'), findsNothing);
  });

  testWidgets('the toggle switches the whole screen', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();

    // Labelled with the language it switches TO.
    expect(find.text('EN'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('Book a ride'), findsOneWidget);
    expect(find.text('Mag-book ng ride'), findsNothing);
    // And now offers the way back.
    expect(find.text('FIL'), findsOneWidget);
  });

  testWidgets('every screen string moves, not just the button', (tester) async {
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();
    expect(find.text('Kailangan ng number para makapag-book.'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    // A screen that switched its buttons but not its body text would be the
    // exact mixed-language problem this feature exists to remove.
    expect(find.text('You need a mobile number to book.'), findsOneWidget);
    expect(find.textContaining('Kailangan'), findsNothing);
  });

  testWidgets('the choice survives a restart', (tester) async {
    SharedPreferences.setMockInitialValues({'locale': 'en'});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_app(null, prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('Book a ride'), findsOneWidget);
  });

  testWidgets('a missing preference store does not break the app',
      (tester) async {
    // sharedPreferencesProvider defaults to null, which is what happens on a
    // platform where the store is unavailable. The language must still work
    // for the session; it simply forgets. The sibling ThemeController learned
    // this the hard way — an escaping failure rendered a blank page.
    await tester.pumpWidget(_app(null));
    await tester.pumpAndSettle();

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('Book a ride'), findsOneWidget);
  });
}
