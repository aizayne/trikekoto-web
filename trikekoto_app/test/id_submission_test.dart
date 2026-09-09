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

    test('trims the number', () {
      final m = IdSubmissionWrites.create(
        subjectUid: uid,
        role: IdRole.driver,
        idType: 'drivers_license',
        idNumber: '  N01-23-456789  ',
      );
      expect(m['idNumber'], 'N01-23-456789');
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
}
