import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/collection_paths.dart';

/// A document in `drivers/{driverEmail}`.
///
/// Contains PII and is readable only by the driver themselves and admins.
/// Whatever a commuter needs to see is denormalised onto the ride document at
/// accept time — see `RideDriverSnapshot`.
class Driver {
  const Driver({
    required this.email,
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.plateNumber,
    required this.todaChapter,
    required this.status,
    this.todaBodyNumber,
    this.verification,
    this.ratingSum = 0,
    this.ratingCount = 0,
    this.fcmToken,
    this.createdAt,
    this.updatedAt,
  });

  final String email;
  final String uid;
  final String firstName;
  final String lastName;
  final String phone;
  final String plateNumber;
  final String todaChapter;
  final String? todaBodyNumber;
  final String status;
  final Map<String, dynamic>? verification;
  final int ratingSum;
  final int ratingCount;
  final String? fcmToken;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  String get fullName => '$firstName $lastName';

  bool get isApproved => status == DriverStatus.approved;
  bool get isSuspended => status == DriverStatus.suspended;

  /// Derived, never stored: security rules cannot validate floating-point
  /// equality, so a persisted average would be an unforgeable-in-theory field
  /// that is trivially forgeable in practice. See SCHEMA.md.
  double? get ratingAverage =>
      ratingCount == 0 ? null : ratingSum / ratingCount;

  factory Driver.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
    SnapshotOptions? _,
  ) =>
      Driver.fromMap(snap.data(), snap.id);

  /// Parsing, separated from the Firestore plumbing so it can be exercised
  /// without a live snapshot.
  ///
  /// Every field tolerates absence. Documents written by the previous web
  /// build predate `uid`, `todaChapter`, and the rating counters, and a
  /// listener sees them the moment an admin lists drivers — a throw here
  /// would fail the whole query, not just one row.
  factory Driver.fromMap(Map<String, dynamic>? data, String id) {
    final d = data ?? const <String, dynamic>{};
    return Driver(
      email: d['email'] as String? ?? id,
      uid: d['uid'] as String? ?? '',
      firstName: d['firstName'] as String? ?? '',
      lastName: d['lastName'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      plateNumber: d['plateNumber'] as String? ?? '',
      todaChapter: d['todaChapter'] as String? ?? '',
      todaBodyNumber: d['todaBodyNumber'] as String?,
      status: d['status'] as String? ?? DriverStatus.pending,
      verification: (d['verification'] as Map?)?.cast<String, dynamic>(),
      ratingSum: (d['ratingSum'] as num?)?.toInt() ?? 0,
      ratingCount: (d['ratingCount'] as num?)?.toInt() ?? 0,
      fcmToken: d['fcmToken'] as String?,
      createdAt: d['createdAt'] as Timestamp?,
      updatedAt: d['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'uid': uid,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'plateNumber': plateNumber,
        'todaChapter': todaChapter,
        'todaBodyNumber': todaBodyNumber,
        'status': status,
        'verification': verification,
        'ratingSum': ratingSum,
        'ratingCount': ratingCount,
        'fcmToken': fcmToken,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  /// The exact payload the `drivers` create rule accepts.
  ///
  /// `status` is forced to `pending` and the counters to zero because the rule
  /// requires it — a driver cannot register themselves into an approved state.
  static Map<String, dynamic> registrationPayload({
    required String email,
    required String uid,
    required String firstName,
    required String lastName,
    required String phone,
    required String plateNumber,
    required String todaChapter,
    String? todaBodyNumber,
  }) =>
      {
        'email': normalizeEmail(email),
        'uid': uid,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phone': phone.trim(),
        'plateNumber': plateNumber.trim().toUpperCase(),
        'todaChapter': todaChapter.trim(),
        'todaBodyNumber': todaBodyNumber?.trim(),
        'status': DriverStatus.pending,
        'ratingSum': 0,
        'ratingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
