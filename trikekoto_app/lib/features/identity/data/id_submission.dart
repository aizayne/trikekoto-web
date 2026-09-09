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

  static String label(String key) => options[key] ?? key;
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
        'idNumber': idNumber.trim(),
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
