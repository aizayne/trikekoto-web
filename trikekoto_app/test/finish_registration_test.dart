import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';
import 'package:trikekoto_app/features/drivers/presentation/driver_register_screen.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

class _FixedTheme extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

Future<void> _pump(WidgetTester tester, {required bool finishing}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [themeModeProvider.overrideWith(_FixedTheme.new)],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: DriverRegisterScreen(finishing: finishing),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('finishing asks only for what is missing', (tester) async {
    await _pump(tester, finishing: true);

    expect(find.widgetWithText(TextFormField, 'Password'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Email'), findsNothing);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Plate number'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.widgetWithText(TextFormField, 'Plate number'), findsOneWidget);
  });

  testWidgets('a new registration still asks for a sign-in', (tester) async {
    await _pump(tester, finishing: false);

    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Password'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
  });
}
