import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/features/commuter/presentation/commuter_booking_screen.dart';
import 'package:trikekoto_app/l10n/app_localizations.dart';

void main() {
  final en = lookupL(const Locale('en'));
  final fil = lookupL(const Locale('fil'));

  test('before anyone is asked, it does not mention a total', () {
    expect(searchProgressText(en, 0),
        'No driver has been asked yet. Still looking nearby.');
    expect(searchProgressText(en, 0), isNot(contains('10')));
    expect(searchProgressText(fil, 0), isNot(contains('10')));
  });

  test('once drivers are asked, the total reads as a ceiling', () {
    expect(searchProgressText(en, 3), 'Asked 3 of up to 10 drivers');
    expect(searchProgressText(fil, 3),
        'Natanong na ang 3 sa hanggang 10 driver');
  });

  test('it never claims that many drivers are nearby', () {
    expect(searchProgressText(en, 3), isNot(contains('nearby')));
  });
}
