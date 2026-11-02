import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/features/commuter/presentation/commuter_booking_screen.dart';
import 'package:trikekoto_app/features/rides/data/ride.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

void main() {
  Future<List<(int, String)>> pump(WidgetTester tester) async {
    final sent = <(int, String)>[];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: RateCard(
            ride: Ride.fromMap(const {
              'commuterUid': 'u1',
              'status': 'completed',
            }, 'r1'),
            onRate: (stars, feedback) async => sent.add((stars, feedback)),
          ),
        ),
      ),
    ));
    return sent;
  }

  FilledButton send(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Send rating'));

  testWidgets('nothing can be sent before choosing stars', (tester) async {
    await pump(tester);
    expect(send(tester).onPressed, isNull);
  });

  testWidgets('tapping a star does not send, so it can still change',
      (tester) async {
    final sent = await pump(tester);

    await tester.tap(find.byTooltip('5'));
    await tester.pump();
    await tester.tap(find.byTooltip('4'));
    await tester.pump();

    expect(sent, isEmpty);
    expect(find.byIcon(Icons.star), findsNWidgets(4));
  });

  testWidgets('sends the stars with the feedback', (tester) async {
    final sent = await pump(tester);

    await tester.tap(find.byTooltip('4'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Mabait ang driver');
    await tester.tap(find.text('Send rating'));
    await tester.pump();

    expect(sent, [(4, 'Mabait ang driver')]);
  });

  testWidgets('feedback is optional', (tester) async {
    final sent = await pump(tester);

    await tester.tap(find.byTooltip('5'));
    await tester.pump();
    await tester.tap(find.text('Send rating'));
    await tester.pump();

    expect(sent, [(5, '')]);
  });

  test('blank feedback is stored as nothing', () {
    expect(RideWrites.rate(stars: 5, feedback: '   ')['feedback'], isNull);
    expect(RideWrites.rate(stars: 5, feedback: ' Okay ')['feedback'], 'Okay');
  });
}
