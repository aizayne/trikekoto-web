import 'package:cloud_firestore/cloud_firestore.dart';

/// A government ID submitted for manual review.
///
/// **This is the only sensitive personal information the system holds**, in
/// the sense the Data Privacy Act of 2012 (RA 10173) uses the term. Everything
/// else — a name, a phone number, a selfie — is ordinary personal information.
/// That difference is why this lives in its own collection with its own rules
/// rather than as a field on `riders/` or `drivers/`.
///
/// Three consequences shape this class:
///
/// * It stores a **path**, never a download URL. A Firebase download URL
///   carries a token that bypasses the Storage rules and keeps working after
///   the document is deleted. Acceptable for a profile photo; not for an ID.
/// * `consentAt` is a stored field rather than something inferred from the
///   act of submitting. Without a timestamp there is no evidence consent was
///   ever given, which is the first thing an audit asks for.
/// * The subject may delete it. Withdrawal has to be an action a person can
///   take, not a request they have to make.
class IdSubmission {
  const IdSubmission({
    required this.subjectUid,
    required this.role,
    required this.idType,
    required this.idNumber,
    required this.idPhotoPath,
    required this.status,
    this.consentAt,
    this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  final String subjectUid;

  /// `driver` or `rider`. Held here rather than derived, so the review queue
  /// can be filtered without reading two other collections.
  final String role;

  final String idType;
  final String idNumber;

  /// Storage path, always `ids/{uid}/card`. Never a URL — see the class note.
  final String idPhotoPath;

  /// `pending`, `approved` or `rejected`.
  final String status;

  final Timestamp? consentAt;
  final Timestamp? submittedAt;
  final String? reviewedBy;
  final Timestamp? reviewedAt;
  final String? rejectionReason;

  bool get isPending => status == IdStatus.pending;
  bool get isApproved => status == IdStatus.approved;
  bool get isRejected => status == IdStatus.rejected;

  factory IdSubmission.fromMap(Map<String, dynamic>? data, String uid) {
    final d = data ?? const <String, dynamic>{};
    return IdSubmission(
      subjectUid: d['subjectUid'] as String? ?? uid,
      role: d['role'] as String? ?? IdRole.rider,
      idType: d['idType'] as String? ?? '',
      idNumber: d['idNumber'] as String? ?? '',
      idPhotoPath: d['idPhotoPath'] as String? ?? IdPaths.card(uid),
      // An unreadable status must not read as approved. Defaulting to
      // pending means a malformed document blocks rather than admits.
      status: d['status'] as String? ?? IdStatus.pending,
      consentAt: d['consentAt'] as Timestamp?,
      submittedAt: d['submittedAt'] as Timestamp?,
      reviewedBy: d['reviewedBy'] as String?,
      reviewedAt: d['reviewedAt'] as Timestamp?,
      rejectionReason: d['rejectionReason'] as String?,
    );
  }

  factory IdSubmission.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) =>
      IdSubmission.fromMap(snap.data(), snap.id);
}

class IdStatus {
  const IdStatus._();
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

class IdRole {
  const IdRole._();
  static const driver = 'driver';
  static const rider = 'rider';
}

class IdPaths {
  const IdPaths._();

  /// The one Storage path a submission may cite. Pinned to the subject's uid
  /// and asserted in the security rules, so a submission cannot point at an
  /// image belonging to somebody else.
  static String card(String uid) => 'ids/$uid/card';
}

/// The ID types a Philippine commuter or driver is likely to hold.
///
/// A closed list rather than free text: an admin comparing a card against a
/// document should not also have to decide whether "drivers licence",
/// "DL" and "LTO license" are the same thing.
class IdTypes {
  const IdTypes._();

  static const options = <String, String>{
    'national_id': 'PhilSys National ID',
    'drivers_license': "Driver's License (LTO)",
    'umid': 'UMID',
    'philhealth': 'PhilHealth ID',
    'postal': 'Postal ID',
    'voters': "Voter's ID",
    'passport': 'Passport',
    'senior': 'Senior Citizen ID',
    'student': 'Student ID',
    'barangay': 'Barangay ID',
  };

  /// What the number on each card looks like, as the app accepts it: letters
  /// and digits only, with the spaces and dashes printed on the card dropped.
  ///
  /// An exact length only where a national format fixes one. Senior Citizen,
  /// student and barangay IDs are numbered by whichever LGU or school issues
  /// them, and Postal and Voter's IDs have changed format over the years, so
  /// an invented exact length would refuse genuine cards; those get a range.
  /// Every limit sits inside the 4–40 the security rules allow.
  static const formats = <String, IdNumberFormat>{
    // PhilSys Card Number, printed 1234-5678-9012-3456.
    'national_id': IdNumberFormat.exact(16, digitsOnly: true),
    // LTO licence number, printed N01-23-456789: a letter and ten digits.
    'drivers_license': IdNumberFormat.exact(11),
    // UMID Common Reference Number, printed 0111-1234567-8.
    'umid': IdNumberFormat.exact(12, digitsOnly: true),
    // PhilHealth Identification Number, printed 12-345678901-2.
    'philhealth': IdNumberFormat.exact(12, digitsOnly: true),
    // Philippine passport, P1234567A (older books: EB1234567).
    'passport': IdNumberFormat.exact(9),
    'postal': IdNumberFormat.range(8, 20),
    'voters': IdNumberFormat.range(8, 30),
    'senior': IdNumberFormat.range(4, 20),
    'student': IdNumberFormat.range(4, 20),
    'barangay': IdNumberFormat.range(4, 20),
  };

  /// The format for [key]. An unknown key gets the rules' own bounds rather
  /// than refusing every number.
  static IdNumberFormat format(String key) =>
      formats[key] ?? const IdNumberFormat.range(4, 40);

  static String label(String key) => options[key] ?? key;

  /// Drops the spaces and dashes people copy off the card, and capitalises,
  /// so one card is stored one way however it was typed.
  static String normalize(String raw) =>
      raw.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
}

/// Why an ID number does not fit its type. Null from [IdNumberFormat.check]
/// means it fits.
enum IdNumberProblem {
  empty,
  notDigits,
  notAlphanumeric,
  wrongLength,
  tooShort,
  tooLong,
}

class IdNumberFormat {
  const IdNumberFormat.exact(int length, {this.digitsOnly = false})
      : minLength = length,
        maxLength = length;

  const IdNumberFormat.range(this.minLength, this.maxLength)
      : digitsOnly = false;

  final int minLength;
  final int maxLength;
  final bool digitsOnly;

  bool get isExact => minLength == maxLength;

  IdNumberProblem? check(String raw) {
    final n = IdTypes.normalize(raw);
    if (n.isEmpty) return IdNumberProblem.empty;
    if (digitsOnly && !RegExp(r'^[0-9]+$').hasMatch(n)) {
      return IdNumberProblem.notDigits;
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(n)) {
      return IdNumberProblem.notAlphanumeric;
    }
    if (isExact && n.length != minLength) return IdNumberProblem.wrongLength;
    if (n.length < minLength) return IdNumberProblem.tooShort;
    if (n.length > maxLength) return IdNumberProblem.tooLong;
    return null;
  }
}

/// Write payloads, one per permitted rules clause.
class IdSubmissionWrites {
  const IdSubmissionWrites._();

  /// A new submission. `status` is fixed at `pending` and the reviewer fields
  /// are absent — both asserted by the rules, so sending anything else is
  /// refused rather than quietly accepted.
  ///
  /// `consentAt` and `submittedAt` are server timestamps the rules require to
  /// equal request time, so neither can be back-dated from a device clock.
  static Map<String, dynamic> create({
    required String subjectUid,
    required String role,
    required String idType,
    required String idNumber,
  }) =>
      {
        'subjectUid': subjectUid,
        'role': role,
        'idType': idType,
        'idNumber': IdTypes.normalize(idNumber),
        'idPhotoPath': IdPaths.card(subjectUid),
        'status': IdStatus.pending,
        'consentAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
      };

  /// An admin decision. Deliberately cannot carry any submitted field, so an
  /// approval cannot rewrite the ID number it is approving.
  static Map<String, dynamic> approve({required String reviewerEmail}) => {
        'status': IdStatus.approved,
        'reviewedBy': reviewerEmail,
        'reviewedAt': FieldValue.serverTimestamp(),
      };

  /// A rejection must say why. The rules refuse one without a reason, because
  /// a rejection the subject cannot act on is a dead end for them.
  static Map<String, dynamic> reject({
    required String reviewerEmail,
    required String reason,
  }) =>
      {
        'status': IdStatus.rejected,
        'reviewedBy': reviewerEmail,
        'reviewedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason.trim(),
      };
}
