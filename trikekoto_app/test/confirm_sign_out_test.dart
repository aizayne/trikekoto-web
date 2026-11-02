import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/core/ui/confirm_sign_out.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

void main() {
  Future<List<bool>> pump(WidgetTester tester) async {
    final answers = <bool>[];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => answers.add(await confirmSignOut(context)),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answers;
  }

  testWidgets('signing out needs a second, deliberate tap', (tester) async {
    final answers = await pump(tester);
    expect(find.text('Sign out?'), findsOneWidget);
    expect(answers, isEmpty);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(answers, [true]);
  });

  testWidgets('staying signed in is the way out', (tester) async {
    final answers = await pump(tester);

    await tester.tap(find.text('Stay signed in'));
    await tester.pumpAndSettle();
    expect(answers, [false]);
  });

  testWidgets('tapping outside the dialog does not sign out', (tester) async {
    final answers = await pump(tester);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(answers, [false]);
  });
}
