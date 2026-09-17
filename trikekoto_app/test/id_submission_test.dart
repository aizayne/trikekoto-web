import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/features/identity/data/id_submission.dart';

/// Government ID payloads.
///
/// The security boundary is the ruleset — see `test_rules/id_submissions.test.mjs`,
/// which proves nobody reads someone else's ID and nobody approves their own.
/// These cover the client half: that a payload can never carry a field the
/// rules refuse, because a refused write during submission leaves someone
/// having uploaded an identity document with no record explaining why it was
/// rejected.

void main() {
  const uid = 'rider-uid-1';

  group('the submission payload', () {
    test('starts pending and unreviewed', () {
      final m = IdSubmissionWrites.create(
        subjectUid: uid,
        role: IdRole.rider,
        idType: 'national_id',
        idNumber: '1234-5678',
      );
      // Seeding either would let someone arrive already verified. The rules
      // refuse it too; this is the client half.
      expect(m['status'], IdStatus.pending);
      expect(m.containsKey('reviewedBy'), isFalse);
      expect(m.containsKey('reviewedAt'), isFalse);
    });

    test('pins the photo path to the subject', () {
      // A submission citing another uid's image is the impersonation route
      // this closes.
      final m = IdSubmissionWrites.create(
        subjectUid: uid,
        role: IdRole.rider,
        idType: 'national_id',
        idNumber: '1234-5678',
      );
      expect(m['idPhotoPath'], 'ids/$uid/card');
    });

    test('carries a consent timestamp', () {
      // Without one the rules refuse the write, and rightly: a consent with
      // no record of when it was given is not evidence of anything.
      final m = IdSubmissionWrites.create(
        subjectUid: uid,
        role: IdRole.rider,
        idType: 'national_id',
        idNumber: '1234-5678',
      );
      expect(m.containsKey('consentAt'), isTrue);
      expect(m['consentAt'], isNotNull);
    });

    test('stores the number without spaces or dashes, in capitals', () {
      // One card, one stored form, however it was typed — so an admin
      // comparing two submissions is not fooled by punctuation.
      final m = IdSubmissionWrites.create(
        subjectUid: uid,
        role: IdRole.driver,
        idType: 'drivers_license',
        idNumber: '  n01-23-456789  ',
      );
      expect(m['idNumber'], 'N0123456789');
    });

    test('never carries a download URL', () {
      // The whole point of storing a path. A URL would bypass the Storage
      // rules and keep working after the submission was deleted.
      final m = IdSubmissionWrites.create(
        subjectUid: uid,
        role: IdRole.rider,
        idType: 'national_id',
        idNumber: '1234-5678',
      );
      expect(m.keys.any((k) => k.toLowerCase().contains('url')), isFalse);
    });
  });

  group('the review payloads', () {
    test('an approval touches only the decision', () {
      // If approving could rewrite the ID number, the approval would mean
      // nothing. The rules refuse it; the payload cannot express it.
      final m = IdSubmissionWrites.approve(reviewerEmail: 'a@t.ph');
      expect(m.keys.toSet(),
          {'status', 'reviewedBy', 'reviewedAt'});
      expect(m['status'], IdStatus.approved);
    });

    test('a rejection carries a reason', () {
      final m = IdSubmissionWrites.reject(
          reviewerEmail: 'a@t.ph', reason: '  Blurry  ');
      expect(m['status'], IdStatus.rejected);
      expect(m['rejectionReason'], 'Blurry');
    });

    test('neither can touch the submitted content', () {
      for (final m in [
        IdSubmissionWrites.approve(reviewerEmail: 'a@t.ph'),
        IdSubmissionWrites.reject(reviewerEmail: 'a@t.ph', reason: 'no'),
      ]) {
        for (final k in ['idNumber', 'idType', 'idPhotoPath', 'consentAt',
            'subjectUid', 'role']) {
          expect(m.containsKey(k), isFalse,
              reason: '$k must not be writable by a reviewer');
        }
      }
    });
  });

  group('parsing', () {
    test('a missing document does not read as approved', () {
      // The dangerous default. An unreadable or absent status must block,
      // never admit.
      final s = IdSubmission.fromMap(null, uid);
      expect(s.status, IdStatus.pending);
      expect(s.isApproved, isFalse);
    });

    test('an unknown status is neither approved nor rejected', () {
      final s = IdSubmission.fromMap(const {'status': 'weird'}, uid);
      expect(s.isApproved, isFalse);
      expect(s.isRejected, isFalse);
    });

    test('falls back to the pinned photo path', () {
      final s = IdSubmission.fromMap(const {}, uid);
      expect(s.idPhotoPath, 'ids/$uid/card');
    });

    test('reads a full submission', () {
      final s = IdSubmission.fromMap(const {
        'subjectUid': uid,
        'role': 'driver',
        'idType': 'drivers_license',
        'idNumber': 'N01-23-456789',
        'idPhotoPath': 'ids/$uid/card',
        'status': 'approved',
      }, uid);
      expect(s.role, IdRole.driver);
      expect(s.isApproved, isTrue);
      expect(s.idNumber, 'N01-23-456789');
    });
  });

  group('ID types', () {
    test('the list is closed, so an admin compares like with like', () {
      // Free text would leave "drivers licence", "DL" and "LTO license" as
      // three different things to reconcile by eye.
      expect(IdTypes.options.containsKey('national_id'), isTrue);
      expect(IdTypes.options.containsKey('drivers_license'), isTrue);
      expect(IdTypes.label('national_id'), 'PhilSys National ID');
    });

    test('an unrecognised key shows itself rather than an empty box', () {
      expect(IdTypes.label('something_else'), 'something_else');
    });
  });

  group('ID number formats', () {
    test('every ID type on the list has a format', () {
      expect(IdTypes.formats.keys.toSet(), IdTypes.options.keys.toSet());
    });

    test('PhilSys takes exactly 16 digits', () {
      final f = IdTypes.format('national_id');
      expect(f.check('1234567890123456'), isNull);
      expect(f.check('1234-5678-9012-3456'), isNull,
          reason: 'dashes copied off the card are ignored');
      expect(f.check('123456789012345'), IdNumberProblem.wrongLength);
      expect(f.check('12345678901234567'), IdNumberProblem.wrongLength);
      expect(f.check('12345678901234AB'), IdNumberProblem.notDigits);
    });

    test('an LTO licence is a letter and ten digits, 11 characters', () {
      final f = IdTypes.format('drivers_license');
      expect(f.check('N01-23-456789'), isNull);
      expect(f.check('N01-23-45678'), IdNumberProblem.wrongLength);
    });

    test('UMID and PhilHealth are 12 digits; a passport is 9 characters', () {
      expect(IdTypes.format('umid').check('0111-1234567-8'), isNull);
      expect(IdTypes.format('philhealth').check('12-345678901-2'), isNull);
      expect(IdTypes.format('passport').check('P1234567A'), isNull);
      expect(IdTypes.format('passport').check('P1234567'),
          IdNumberProblem.wrongLength);
    });

    test('locally issued IDs take a range, not an invented exact length', () {
      final f = IdTypes.format('barangay');
      expect(f.isExact, isFalse);
      expect(f.check('B-123'), isNull);
      expect(f.check('B1'), IdNumberProblem.tooShort);
      expect(f.check('A' * 21), IdNumberProblem.tooLong);
    });

    test('an empty number and symbols are refused', () {
      expect(IdTypes.format('student').check('   '), IdNumberProblem.empty);
      expect(IdTypes.format('student').check('AB#123'),
          IdNumberProblem.notAlphanumeric);
    });

    test('every limit sits inside what the security rules accept (4-40)', () {
      for (final f in IdTypes.formats.values) {
        expect(f.minLength, greaterThanOrEqualTo(4));
        expect(f.maxLength, lessThanOrEqualTo(40));
      }
    });
  });
}
