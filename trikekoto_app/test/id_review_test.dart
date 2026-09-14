import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/ui/app_theme.dart';
import 'package:trikekoto_app/features/identity/application/id_verification_service.dart';
import 'package:trikekoto_app/features/identity/data/id_submission.dart';
import 'package:trikekoto_app/features/identity/presentation/id_review_screen.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

/// The ID review queue.
///
/// Approval is the whole of the scam and troll protection: it is what lets an
/// account book, go online, or accept a ride. So it must mean somebody looked
/// at the card. Before this, Aprubahan worked on a card whose photo had never
/// been opened — or had failed to load.

/// A 1x1 PNG, so Image.memory has something real to decode.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class _FakeIdService implements IdVerificationService {
  @override
  Future<Uint8List?> reviewerImage(String uid) async => _png;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness() {
  final sub = IdSubmission.fromMap(const {
    'subjectUid': 'driver-uid-1',
    'role': 'driver',
    'idType': 'national_id',
    'idNumber': '2957-1479-4351-8261',
    'idPhotoPath': 'ids/driver-uid-1/card',
    'status': 'pending',
  }, 'driver-uid-1');

  return ProviderScope(
    overrides: [
      pendingIdSubmissionsProvider.overrideWith((ref) => Stream.value([sub])),
      idVerificationServiceProvider.overrideWithValue(_FakeIdService()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: AppTheme.light,
      home: const IdReviewScreen(),
    ),
  );
}

FilledButton _approve(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Approve'));

void main() {
  testWidgets('approve is off until the photo has been opened, and says why',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(_approve(tester).onPressed, isNull);
    expect(find.text('Open the ID before approving it.'), findsOneWidget);
  });

  testWidgets('opening the photo enables approve', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('View the ID'));
    await tester.pumpAndSettle();

    expect(_approve(tester).onPressed, isNotNull);
    expect(find.text('Open the ID before approving it.'), findsNothing);
  });

  testWidgets('rejecting never needs the photo', (tester) async {
    // Refusing an unseen ID cannot let anyone in, and a reviewer may reject
    // on the number alone.
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final reject =
        tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Not accepted'));
    expect(reject.onPressed, isNotNull);
  });
}
