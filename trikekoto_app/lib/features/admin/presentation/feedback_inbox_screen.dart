import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/collection_paths.dart';
import '../../../core/providers.dart';
import '../../../core/ui/app_theme.dart';
import '../../feedback/data/feedback_report.dart';
import '../../../core/ui/locale_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Every report, newest first.
///
/// Unresolved ones are what an admin acts on, but resolved history stays
/// visible — a recurring complaint is only recognisable against what came
/// before it.
final allFeedbackProvider = StreamProvider<List<FeedbackReport>>((ref) {
  return ref
      .watch(refsProvider)
      .feedback
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
});

class FeedbackInboxScreen extends ConsumerWidget {
  const FeedbackInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedbackAsync = ref.watch(allFeedbackProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l.fbTitle)),
      body: SafeArea(
        child: feedbackAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Text(describeError(e), textAlign: TextAlign.center),
            ),
          ),
          data: (reports) {
            if (reports.isEmpty) {
              return Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: AppEmptyState(
                  icon: Icons.forum_outlined,
                  title: context.l.fbNoneTitle,
                  body: context.l.fbNoneBody,
                ),
              );
            }

            final open = reports.where((r) => !r.resolved).toList();
            final closed = reports.where((r) => r.resolved).toList();

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Text(context.l.fbNeedsAttention('${open.length}'),
                    style: context.text.titleMedium),
                const Gap(AppSpacing.md),
                if (open.isEmpty)
                  AppEmptyState(
                    icon: Icons.check_circle_outline,
                    title: context.l.fbAllHandledTitle,
                    body: context.l.fbAllHandledBody,
                  ),
                for (final r in open) _ReportCard(report: r),
                if (closed.isNotEmpty) ...[
                  const Gap(AppSpacing.xxl),
                  Text(context.l.fbResolved('${closed.length}'),
                      style: context.text.titleMedium),
                  const Gap(AppSpacing.md),
                  for (final r in closed) _ReportCard(report: r),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report});
  final FeedbackReport report;

  static Map<String, String> _labels(L l) => {
        FeedbackCategory.issue: l.fbCatIssue,
        FeedbackCategory.suggestion: l.fbCatSuggestion,
        FeedbackCategory.question: l.fbCatQuestion,
        FeedbackCategory.other: l.fbCatOther,
      };

  Future<void> _setResolved(
      BuildContext context, WidgetRef ref, bool resolved) async {
    try {
      await ref
          .read(firestoreProvider)
          .collection(FsCollections.feedback)
          .doc(report.id)
          .update({
        'resolved': resolved,
        'resolvedBy': resolved
            ? ref.read(firebaseAuthProvider).currentUser?.email
            : null,
        'resolvedAt': resolved ? FieldValue.serverTimestamp() : null,
      });
      if (context.mounted) {
        showSnack(context,
            resolved ? context.l.fbMarkedResolved : context.l.fbReopened);
      }
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = context.semantic;
    final (accent, container) = switch (report.category) {
      FeedbackCategory.issue => (semantic.danger, semantic.dangerContainer),
      FeedbackCategory.suggestion => (
          context.scheme.secondary,
          context.scheme.secondaryContainer
        ),
      _ => (semantic.warning, semantic.warningContainer),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: container,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    _labels(context.l)[report.category] ??
                        report.category,
                    style: context.text.bodySmall
                        ?.copyWith(color: accent, fontWeight: FontWeight.w600),
                  ),
                ),
                const Gap(AppSpacing.sm),
                Text(context.l.fbFromRole(report.role),
                    style: context.text.bodySmall),
                const Spacer(),
                Text(_when(report.createdAt), style: context.text.bodySmall),
              ],
            ),
            const Gap(AppSpacing.md),
            Text(report.message, style: context.text.bodyMedium),
            if (report.contact != null) ...[
              const Gap(AppSpacing.sm),
              Row(
                children: [
                  Icon(Icons.alternate_email,
                      size: AppSpacing.iconSm,
                      color: context.scheme.onSurfaceVariant),
                  const Gap(AppSpacing.sm),
                  Expanded(
                      child: Text(report.contact!,
                          style: context.text.bodySmall)),
                ],
              ),
            ],
            const Gap(AppSpacing.md),
            const Divider(height: 1),
            const Gap(AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (report.resolved)
                  TextButton.icon(
                    onPressed: () => _setResolved(context, ref, false),
                    icon: const Icon(Icons.undo, size: AppSpacing.iconSm),
                    label: Text(context.l.fbReopen),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _setResolved(context, ref, true),
                    icon: const Icon(Icons.check, size: AppSpacing.iconSm),
                    label: Text(context.l.fbMarkResolved),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Coarse relative time. Precision beyond "3d ago" is noise in a queue an
  /// admin reads once a day.
  static String _when(Timestamp? at) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
