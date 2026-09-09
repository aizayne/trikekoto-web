import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/features/commuter/data/rider.dart';
import 'package:trikekoto_app/features/commuter/data/phone_number.dart';

/// Rider accounts.
///
/// Two things carry real consequences. The phone number must reach Firebase in
/// E.164 or verification fails with an error that reads like the number is
/// wrong; and the write payloads must never carry a key the rules refuse,
/// because a rejected write during onboarding leaves someone signed in with no
/// profile and nowhere to go.

void main() {
  group('phone number normalisation', () {
    // Filipinos write their number three ways and all three are correct.
    // Rejecting two of them would be a barrier over formatting, not identity.
    const expected = '+639171234567';

    test('accepts the 09 form people actually type', () {
      expect(toE164Ph('09171234567'), expected);
    });

    test('accepts it with spaces and dashes', () {
      expect(toE164Ph('0917 123 4567'), expected);
      expect(toE164Ph('0917-123-4567'), expected);
    });

    test('accepts the bare 9 form', () {
      expect(toE164Ph('9171234567'), expected);
    });

    test('passes through an already-E.164 number', () {
      expect(toE164Ph('+639171234567'), expected);
    });

    test('rejects a landline', () {
      expect(toE164Ph('0472345678'), isNull);
    });

    test('rejects a number of the wrong length', () {
      expect(toE164Ph('0917123456'), isNull);
      expect(toE164Ph('091712345678'), isNull);
    });

    test('rejects empty and nonsense', () {
      expect(toE164Ph(''), isNull);
      expect(toE164Ph('hello'), isNull);
    });
  });

  group('the create payload', () {
    test('starts unrated and with no saved places', () {
      final m = RiderWrites.create(name: 'Maria', phone: '+639171234567');
      // Seeding either would let someone arrive with a standing they never
      // earned. The rules refuse it too; this is the client half.
      expect(m['ratingSum'], 0);
      expect(m['ratingCount'], 0);
      expect(m['savedAddresses'], isEmpty);
    });

    test('trims the name', () {
      final m = RiderWrites.create(name: '  Maria  ', phone: '+63917');
      expect(m['name'], 'Maria');
    });

    test('never carries a photo URL', () {
      // The photo is uploaded after the document exists. Writing a URL here
      // would mean an upload that failed halfway leaves a profile pointing at
      // an object that is not there.
      final m = RiderWrites.create(name: 'Maria', phone: '+63917');
      expect(m['profilePhotoUrl'], isNull);
    });

    test('carries the phone through verbatim', () {
      // It comes from the verified token, so altering it here would break the
      // rule that requires the two to match.
      final m = RiderWrites.create(name: 'Maria', phone: '+639171234567');
      expect(m['phone'], '+639171234567');
    });
  });

  group('the rename payload', () {
    test('touches the name and nothing else', () async {
      // The whole point: renaming must not carry profilePhotoUrl, or saving
      // a corrected spelling would silently delete the rider's picture.
      final m = RiderWrites.updateName('Maria S.');
      expect(m.keys.toSet(), {'name', 'updatedAt'});
      expect(m['name'], 'Maria S.');
    });

    test('trims', () {
      expect(RiderWrites.updateName('  Maria  ')['name'], 'Maria');
    });

    test('cannot reach the phone, the rating, or createdAt', () {
      final m = RiderWrites.updateName('Maria');
      for (final key in ['phone', 'ratingSum', 'ratingCount', 'createdAt']) {
        expect(m.containsKey(key), isFalse, reason: '$key must stay unwritable');
      }
    });
  });

  group('the profile-edit payload', () {
    test('clears the photo when no URL is supplied — the documented trap', () {
      // Asserted deliberately. This is why the profile screen calls
      // updateName() instead: a caller that omits the URL here is not leaving
      // the photo alone, it is deleting it.
      final m = RiderWrites.updateProfile(name: 'Maria');
      expect(m.containsKey('profilePhotoUrl'), isTrue);
      expect(m['profilePhotoUrl'], isNull);
    });

    test('cannot touch the phone, the rating, or createdAt', () {
      final m = RiderWrites.updateProfile(name: 'Maria S.');
      // Every one of these is refused by the rules. Keeping them out of the
      // payload means the refusal never happens in front of a user.
      expect(m.containsKey('phone'), isFalse);
      expect(m.containsKey('ratingSum'), isFalse);
      expect(m.containsKey('ratingCount'), isFalse);
      expect(m.containsKey('createdAt'), isFalse);
    });

    test('touches only what the update clause admits', () {
      final m = RiderWrites.updateProfile(name: 'Maria');
      expect(m.keys.toSet(),
          {'name', 'profilePhotoUrl', 'updatedAt'});
    });
  });

  group('the photo payload', () {
    test('sets a URL and nothing else of consequence', () {
      final m = RiderWrites.setPhoto('https://example.test/p.jpg');
      expect(m['profilePhotoUrl'], 'https://example.test/p.jpg');
      expect(m.keys.toSet(), {'profilePhotoUrl', 'updatedAt'});
    });

    test('clears with an explicit null rather than omitting the key', () {
      // Omitting it would leave the old URL in place, so "remove photo"
      // would silently do nothing.
      final m = RiderWrites.setPhoto(null);
      expect(m.containsKey('profilePhotoUrl'), isTrue);
      expect(m['profilePhotoUrl'], isNull);
    });

    test('cannot smuggle in a rating or a phone change', () {
      final m = RiderWrites.setPhoto('https://example.test/p.jpg');
      expect(m.containsKey('phone'), isFalse);
      expect(m.containsKey('ratingSum'), isFalse);
    });
  });

  group('parsing', () {
    test('a missing document yields an empty rider rather than throwing', () {
      final r = Rider.fromMap(null, 'uid-1');
      expect(r.uid, 'uid-1');
      expect(r.name, '');
      expect(r.savedAddresses, isEmpty);
    });

    test('rating is null until somebody rates them', () {
      expect(Rider.fromMap(const {}, 'u').rating, isNull);
      expect(
        Rider.fromMap(const {'ratingSum': 9, 'ratingCount': 2}, 'u').rating,
        4.5,
      );
    });

    test('skips a malformed saved address instead of failing the profile', () {
      final r = Rider.fromMap(const {
        'savedAddresses': [
          'not-a-map',
          {'label': 'Bahay', 'point': GeoPoint(14.6, 121.0)},
        ],
      }, 'u');
      expect(r.savedAddresses, hasLength(1));
      expect(r.savedAddresses.single.label, 'Bahay');
    });

    test('survives a saved address with no point', () {
      final r = Rider.fromMap(const {
        'savedAddresses': [
          {'label': 'Bahay'},
        ],
      }, 'u');
      expect(r.savedAddresses.single.point, const GeoPoint(0, 0));
    });
  });
}
