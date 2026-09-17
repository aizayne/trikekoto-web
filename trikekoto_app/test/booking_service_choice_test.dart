import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';
import 'package:trikekoto_app/features/commuter/application/commuter_location.dart';
import 'package:trikekoto_app/features/commuter/application/dispatch_controller.dart';
import 'package:trikekoto_app/features/commuter/presentation/commuter_booking_screen.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

/// Choosing a regular or special trip on the booking screen.
class _FixedTheme extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

Widget _harness() => ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(_FixedTheme.new),
        myActiveRideProvider.overrideWith((ref) => Stream.value(null)),
        myRiderProfileProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        theme: AppTheme.light,
        home: const CommuterBookingScreen(),
      ),
    );

/// Whether the option card showing [title] is the selected one.
Finder _checked(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(InkWell)),
      matching: find.byIcon(Icons.radio_button_checked),
    );

void main() {
  Future<void> pumpTall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
  }

  testWidgets('regular is selected until the commuter chooses special',
      (tester) async {
    await pumpTall(tester);

    // Special costs a full load's fare, so it is never the default.
    expect(_checked('Regular — 1 passenger'), findsOneWidget);
    expect(_checked('Special — whole tricycle'), findsNothing);
    expect(find.text('You agree to pay the fare for 5 passengers. '
        'The tricycle is yours alone.'), findsOneWidget);
  });

  testWidgets('tapping special selects it, and only it', (tester) async {
    await pumpTall(tester);

    await tester.tap(find.text('Special — whole tricycle'));
    await tester.pumpAndSettle();

    expect(_checked('Special — whole tricycle'), findsOneWidget);
    expect(_checked('Regular — 1 passenger'), findsNothing);

    await tester.tap(find.text('Regular — 1 passenger'));
    await tester.pumpAndSettle();
    expect(_checked('Regular — 1 passenger'), findsOneWidget);
  });
}
