import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/firestore/collection_paths.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/core/ui/theme_controller.dart';
import 'package:trikekoto_app/features/admin/presentation/feedback_inbox_screen.dart';
import 'package:trikekoto_app/features/feedback/data/feedback_report.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

class _FixedTheme extends ThemeController {
  @override
  ThemeMode build() => ThemeMode.light;
}

const _report = FeedbackReport(
  id: 'f1',
  submittedByUid: 'u1',
  category: FeedbackCategory.issue,
  role: 'commuter',
  message: 'The map did not load',
  resolved: false,
);

Future<List<String>> _pump(WidgetTester tester, {bool fails = false}) async {
  final deleted = <String>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(_FixedTheme.new),
      allFeedbackProvider.overrideWith((ref) => Stream.value(const [_report])),
      deleteFeedbackProvider.overrideWithValue((id) async {
        if (fails) throw StateError('permission-denied');
        deleted.add(id);
      }),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: const FeedbackInboxScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return deleted;
}

void main() {
  testWidgets('deleting a report asks first, then removes it', (tester) async {
    final deleted = await _pump(tester);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this report?'), findsOneWidget);
    expect(deleted, isEmpty, reason: 'nothing goes before the answer');

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(deleted, ['f1']);
    expect(find.text('Report deleted.'), findsOneWidget);
  });

  testWidgets('keeping it deletes nothing', (tester) async {
    final deleted = await _pump(tester);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();

    expect(deleted, isEmpty);
    expect(find.text('The map did not load'), findsOneWidget);
  });

  testWidgets('a refused delete says so', (tester) async {
    await _pump(tester, fails: true);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('refused'), findsOneWidget);
    expect(find.text('Report deleted.'), findsNothing);
  });
}
