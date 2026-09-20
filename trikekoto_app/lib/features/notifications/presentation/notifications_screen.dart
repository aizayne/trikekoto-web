import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/locale_controller.dart';
import '../application/notifications.dart';
import '../data/app_notification.dart';

/// The notices waiting for whoever is signed in.
///
/// One screen for every role: a notice is addressed to a uid, and what the
/// rules admit is the caller's own. Today the only kind is an admin approving
/// a driver's registration; the shape holds for whatever is told to whom
/// next.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(myNotificationsProvider);
    final unread = ref.watch(unreadNoticeCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l.noticesTitle),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                final markRead = ref.read(markNoticeReadProvider);
                for (final notice in notices.value ?? const <AppNotification>[]) {
                  await markRead(notice);
                }
              },
              child: Text(context.l.noticesMarkAllRead),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: notices.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: AppEmptyState(
                    icon: Icons.cloud_off,
                    title: context.l.noticesFailed,
                    body: describeError(e),
                  ),
                ),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: AppEmptyState(
                        icon: Icons.notifications_none_outlined,
                        title: context.l.noticesEmptyTitle,
                        body: context.l.noticesEmptyBody,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _NoticeTile(notice: rows[i]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeTile extends ConsumerWidget {
  const _NoticeTile({required this.notice});

  final AppNotification notice;

  /// The app's own wording for a type it knows, and the server's for one it
  /// does not. An older build meeting a newer notice shows the English
  /// sentence the server wrote rather than an empty row.
  (String title, String body) _words(BuildContext context) =>
      switch (notice.type) {
        NoticeTypes.accountApproved => (
            context.l.noticeApprovedTitle,
            context.l.noticeApprovedBody,
          ),
        _ => (notice.title, notice.body),
      };

  IconData get _icon => switch (notice.type) {
        NoticeTypes.accountApproved => Icons.verified_user_outlined,
        _ => Icons.notifications_none_outlined,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (title, body) = _words(context);
    final unread = !notice.isRead;
    final at = notice.createdAt?.toDate();

    return Card(
      // Unread sits on the accent container rather than carrying a coloured
      // dot alone: the difference has to survive a phone held at arm's length
      // in daylight, which a 8dp dot does not.
      color: unread ? context.scheme.secondaryContainer : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        leading: Icon(_icon,
            color: unread
                ? context.semantic.success
                : context.scheme.onSurfaceVariant),
        title: Text(
          title,
          style: context.text.titleSmall?.copyWith(
            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(AppSpacing.xs),
            Text(body, style: context.text.bodySmall),
            if (at != null) ...[
              const Gap(AppSpacing.xs),
              Text(
                DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag())
                    .add_jm()
                    .format(at),
                style: context.text.labelSmall
                    ?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
        trailing: unread
            ? Icon(Icons.circle, size: 10, color: context.semantic.success)
            : null,
        // Reading it is the tap. Marking every notice read on open would let
        // one that arrived while the screen was already up be dismissed
        // before it was seen.
        onTap: unread
            ? () => ref.read(markNoticeReadProvider)(notice)
            : null,
      ),
    );
  }
}
