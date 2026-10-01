import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/ui/app_theme.dart';
import '../application/id_verification_service.dart';
import '../data/id_submission.dart';
import '../../../core/ui/locale_controller.dart';

/// The admin review queue for government IDs.
///
/// The card image is fetched as **bytes**, per submission, only when a
/// reviewer opens it — never as a download URL. A URL would keep working for
/// anyone who obtained it, from anywhere, after the submission was deleted.
/// Bytes are checked against the Storage rules on every fetch and leave
/// nothing behind.
///
/// They are also never cached to disk here. The image lives in memory for as
/// long as the sheet is open and goes when it closes, so a reviewer's device
/// does not slowly accumulate a folder of other people's identity documents.
class IdReviewScreen extends ConsumerWidget {
  const IdReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(pendingIdSubmissionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l.reviewTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: SafeArea(
        child: queue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: AppEmptyState(
                icon: Icons.cloud_off,
                title: context.l.reviewQueueFailed,
                body: describeError(e),
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: AppEmptyState(
                    icon: Icons.verified_outlined,
                    title: context.l.reviewNothingTitle,
                    body: context.l.reviewNothingBody,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Gap(AppSpacing.md),
              itemBuilder: (_, i) => _SubmissionCard(items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SubmissionCard extends ConsumerStatefulWidget {
  const _SubmissionCard(this.sub);
  final IdSubmission sub;

  @override
  ConsumerState<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends ConsumerState<_SubmissionCard> {
  Uint8List? _image;
  bool _loading = false;
  bool _busy = false;
  String? _imageError;

  /// Fetched on demand, not on build. A queue of twenty submissions must not
  /// pull twenty identity documents onto the device because somebody opened
  /// the screen.
  Future<void> _loadImage() async {
    if (_image != null || _loading) return;
    setState(() => _loading = true);
    try {
      final bytes = await ref
          .read(idVerificationServiceProvider)
          .reviewerImage(widget.sub.subjectUid);
      if (mounted) setState(() => _image = bytes);
    } catch (e) {
      if (mounted) setState(() => _imageError = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide({required bool approve}) async {
    final email = ref.read(sessionProvider).user?.email;
    if (email == null) return;

    String? reason;
    if (!approve) {
      reason = await _askReason();
      if (reason == null) return;
    }

    setState(() => _busy = true);
    try {
      final svc = ref.read(idVerificationServiceProvider);
      if (approve) {
        await svc.approve(uid: widget.sub.subjectUid, reviewerEmail: email);
      } else {
        await svc.reject(
          uid: widget.sub.subjectUid,
          reviewerEmail: email,
          reason: reason!,
        );
      }
      if (mounted) {
        // The image goes as soon as the decision is made. Keeping it around
        // in a reviewed card would mean an identity document sitting in
        // memory long after there was any reason to look at it.
        setState(() => _image = null);
        showSnack(context,
            approve ? context.l.reviewApproved : context.l.reviewRejected);
      }
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    // Approval is the moment the ID has served its purpose: the person is
    // verified for good, and the marker that says so holds no ID data. Asked
    // rather than done, because a chapter may want the card on file until the
    // officer has written the member up in their own records — but asked
    // every time, so holding it is a decision rather than the default.
    if (approve && mounted) await _deleteNow(justApproved: true);
  }

  /// Deletes the ID photo and its details, keeping the verification.
  ///
  /// Retention already removes every submission 90 days after it arrives.
  /// This is the same deletion, by hand, for a reviewer who would rather not
  /// hold a government ID for three months once they have finished looking at
  /// it — which is the whole purpose the data was collected for.
  Future<void> _deleteNow({required bool justApproved}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(justApproved
            ? dialogContext.l.reviewDeleteAfterApproval
            : dialogContext.l.reviewDeleteQuestion),
        content: Text(dialogContext.l.reviewDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l.reviewKeepId),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: dialogContext.scheme.error),
            child: Text(dialogContext.l.reviewDeleteId),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(idVerificationServiceProvider)
          .withdraw(widget.sub.subjectUid);
      if (mounted) showSnack(context, context.l.reviewDeleted);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// A rejection must carry a reason — the rules refuse one without, and a
  /// rejection the subject cannot act on is a dead end for them.
  Future<String?> _askReason() async {
    final c = TextEditingController();
    final out = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(context.l.reviewWhyRejected),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: context.l.reviewReasonHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(context.l.reviewCancel),
          ),
          FilledButton(
            onPressed: () {
              final t = c.text.trim();
              if (t.length < 3) return;
              Navigator.pop(d, t);
            },
            child: Text(context.l.reviewSend),
          ),
        ],
      ),
    );
    c.dispose();
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sub;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: s.role == IdRole.driver
                        ? context.scheme.secondaryContainer
                        : context.scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    s.role == IdRole.driver
                        ? context.l.reviewRoleDriver
                        : context.l.reviewRoleCommuter,
                    style: context.text.bodySmall,
                  ),
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: Text(IdTypes.label(s.idType),
                      style: context.text.titleSmall),
                ),
              ],
            ),
            const Gap(AppSpacing.sm),
            SelectableText(s.idNumber, style: context.text.bodyMedium),
            const Gap(AppSpacing.md),

            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Image.memory(_image!, fit: BoxFit.contain),
              )
            else if (_imageError != null)
              Text(_imageError!,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.scheme.error))
            else
              OutlinedButton.icon(
                onPressed: _loading ? null : _loadImage,
                icon: _loading
                    ? const SizedBox(
                        width: AppSpacing.iconSm,
                        height: AppSpacing.iconSm,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.image_outlined),
                label: Text(_loading
                    ? context.l.reviewOpening
                    : context.l.reviewViewId),
              ),

            const Gap(AppSpacing.lg),
            // Approval is the whole of the scam and troll protection, and it
            // means "a person looked at this card". Until the photo is on
            // screen that has not happened, so the button says why it is off
            // rather than looking broken. Rejecting stays available: refusing
            // an ID unseen cannot let anyone in.
            if (_image == null) ...[
              Text(
                context.l.reviewViewFirst,
                textAlign: TextAlign.center,
                style: context.text.bodySmall
                    ?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
              const Gap(AppSpacing.sm),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _decide(approve: false),
                    child: Text(context.l.reviewReject,
                        style: TextStyle(color: context.scheme.error)),
                  ),
                ),
                const Gap(AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    // Also off when the photo failed to load: an ID the
                    // reviewer could not see is not one they can vouch for.
                    onPressed: _busy || _image == null
                        ? null
                        : () => _decide(approve: true),
                    child: Text(context.l.reviewApprove),
                  ),
                ),
              ],
            ),
            // Deleting without deciding: for a submission that is somebody's
            // shopping receipt, or a second copy of a card already approved.
            // The queue is not a place to park personal data while thinking.
            const Gap(AppSpacing.sm),
            Center(
              child: TextButton.icon(
                onPressed: _busy ? null : () => _deleteNow(justApproved: false),
                icon: const Icon(Icons.delete_outline,
                    size: AppSpacing.iconSm),
                label: Text(context.l.reviewDeleteId),
                style: TextButton.styleFrom(
                    foregroundColor: context.scheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
