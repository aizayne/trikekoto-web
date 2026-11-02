import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/providers.dart';
import '../data/app_notification.dart';

/// The signed-in user's notices, newest first.
///
/// Capped by `recentNotices` in the query, and autoDispose so the listener
/// ends with the last screen watching it. Both matter: this is a live
/// listener on a collection that grows for the life of an account, and the
/// badge in an app bar would otherwise hold every notice a driver has ever
/// received for as long as the app is open.
///
/// Empty rather than an error when nobody is signed in. The bell is built
/// during sign-out too, for the frame between the session ending and the
/// router moving.
final myNotificationsProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final uid = ref.watch(sessionProvider.select((s) => s.user?.uid));
  if (uid == null) return Stream.value(const <AppNotification>[]);

  return ref
      .watch(refsProvider)
      .recentNotices(uid)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
});

/// How many notices are waiting. What the badge on the bell counts.
final unreadNoticeCountProvider = Provider.autoDispose<int>((ref) {
  final notices = ref.watch(myNotificationsProvider).value;
  if (notices == null) return 0;
  return notices.where((n) => !n.isRead).length;
});

/// Marks one notice read.
///
/// The only write a client is allowed to make in this collection — the rules
/// admit `readAt` and nothing else — so it is one function rather than a
/// controller. Idempotent, and silent on an already-read notice: reopening
/// the screen should not bill a write per row.
typedef MarkNoticeRead = Future<void> Function(AppNotification notice);

final markNoticeReadProvider = Provider<MarkNoticeRead>((ref) {
  final uid = ref.watch(sessionProvider.select((s) => s.user?.uid));
  final refs = ref.watch(refsProvider);

  return (notice) async {
    if (uid == null || notice.isRead) return;
    await refs
        .notice(uid, notice.id)
        .update({'readAt': FieldValue.serverTimestamp()});
  };
});
