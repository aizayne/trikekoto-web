import 'package:cloud_firestore/cloud_firestore.dart';

/// What a notice is about.
///
/// The type is what the app renders from, not the stored text: a sentence
/// written once by the server would be the one string in this app that
/// ignores the language switch. The title and body that come with it are the
/// fallback — for a type a build has never heard of, and for the push, which
/// Android draws before the app is ever opened.
class NoticeTypes {
  const NoticeTypes._();

  /// An admin approved a driver's registration. Written by `onDriverApproved`.
  static const accountApproved = 'account_approved';
}

/// A document in `notifications/{uid}/items/{noticeId}`.
///
/// Written only by Cloud Functions. The owner may set [readAt] and nothing
/// else, which is the whole of what the rules allow a client to do here.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;

  /// The server's own wording, shown when [type] means nothing to this build.
  final String title;
  final String body;

  final Timestamp? createdAt;

  /// When the owner opened it. Null until then — the unread count is exactly
  /// the notices with nothing here.
  final Timestamp? readAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
    SnapshotOptions? _,
  ) =>
      AppNotification.fromMap(snap.data(), snap.id);

  /// Tolerates absence in every field. A notice written by a later build may
  /// carry a type or a shape this one has never seen, and a throw here would
  /// fail the whole listener rather than one row.
  factory AppNotification.fromMap(Map<String, dynamic>? data, String id) {
    final d = data ?? const <String, dynamic>{};
    return AppNotification(
      id: id,
      type: d['type'] as String? ?? '',
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp?,
      readAt: d['readAt'] as Timestamp?,
    );
  }

  /// Here for the typed reference's sake. Nothing in the app writes a notice —
  /// the rules refuse it — so this is never the path a document takes.
  Map<String, dynamic> toMap() => {
        'type': type,
        'title': title,
        'body': body,
        'createdAt': createdAt,
        'readAt': readAt,
      };
}
