import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/ui/app_theme.dart';
import '../application/id_verification_service.dart';
import '../data/id_submission.dart';

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
        title: const Text('ID review'),
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
                title: 'Hindi mabuksan ang queue',
                body: describeError(e),
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: AppEmptyState(
                    icon: Icons.verified_outlined,
                    title: 'Walang naghihintay',
                    body: 'Lilitaw dito ang mga bagong ID na ipinadala.',
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
        showSnack(context, approve ? 'Naaprubahan.' : 'Hindi tinanggap.');
      }
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
        title: const Text('Bakit hindi tinanggap?'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Hal. Malabo ang litrato, hindi mabasa ang numero.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Kanselahin'),
          ),
          FilledButton(
            onPressed: () {
              final t = c.text.trim();
              if (t.length < 3) return;
              Navigator.pop(d, t);
            },
            child: const Text('Ipadala'),
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
                    s.role == IdRole.driver ? 'Driver' : 'Commuter',
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
                label: Text(_loading ? 'Binubuksan…' : 'Tingnan ang ID'),
              ),

            const Gap(AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _decide(approve: false),
                    child: Text('Hindi tanggap',
                        style: TextStyle(color: context.scheme.error)),
                  ),
                ),
                const Gap(AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _decide(approve: true),
                    child: const Text('Aprubahan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
