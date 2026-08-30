import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/firestore/collection_paths.dart';

/// A document in `feedback/{feedbackId}`.
///
/// Anyone signed in — including an anonymous commuter — may file one and read
/// back their own. Only admins can list, resolve, or delete.
class FeedbackReport {
  const FeedbackReport({
    required this.id,
    required this.submittedByUid,
    required this.category,
    required this.role,
    required this.message,
    required this.resolved,
    this.contact,
    this.createdAt,
    this.resolvedBy,
    this.resolvedAt,
  });

  final String id;
  final String submittedByUid;
  final String category;
  final String role;
  final String message;
  final String? contact;
  final bool resolved;
  final Timestamp? createdAt;
  final String? resolvedBy;
  final Timestamp? resolvedAt;

  factory FeedbackReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
    SnapshotOptions? _,
  ) =>
      FeedbackReport.fromMap(snap.data(), snap.id);

  /// Parsing, separated from the Firestore plumbing so it can be exercised
  /// without a live snapshot. Reports filed by the web build carry no
  /// `submittedByUid`.
  factory FeedbackReport.fromMap(Map<String, dynamic>? data, String id) {
    final d = data ?? const <String, dynamic>{};
    return FeedbackReport(
      id: id,
      submittedByUid: d['submittedByUid'] as String? ?? '',
      category: d['category'] as String? ?? FeedbackCategory.other,
      role: d['role'] as String? ?? FeedbackRole.unknown,
      message: d['message'] as String? ?? '',
      contact: d['contact'] as String?,
      resolved: d['resolved'] as bool? ?? false,
      createdAt: d['createdAt'] as Timestamp?,
      resolvedBy: d['resolvedBy'] as String?,
      resolvedAt: d['resolvedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'submittedByUid': submittedByUid,
        'category': category,
        'role': role,
        'message': message,
        'contact': contact,
        'resolved': resolved,
        'createdAt': createdAt,
        'resolvedBy': resolvedBy,
        'resolvedAt': resolvedAt,
      };

  /// The exact payload the create rule accepts. `resolved` is forced to false
  /// so nobody can file a report that arrives pre-closed.
  static Map<String, dynamic> submitPayload({
    required String uid,
    required String category,
    required String role,
    required String message,
    String? contact,
  }) =>
      {
        'submittedByUid': uid,
        'category': category,
        'role': role,
        'message': message.trim(),
        'contact': (contact?.trim().isEmpty ?? true) ? null : contact!.trim(),
        'resolved': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
