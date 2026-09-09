import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/collection_paths.dart';
import '../../../core/providers.dart';
import '../../../core/ui/app_theme.dart';
import '../data/feedback_report.dart';
import '../../../core/ui/locale_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Lets a commuter or driver report something, from wherever they are.
///
/// A bottom sheet rather than a screen: reporting is an interruption of
/// whatever someone was doing, and it should return them to it.
Future<void> showFeedbackSheet(BuildContext context, {required String role}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _FeedbackSheet(role: role),
  );
}

class _FeedbackSheet extends ConsumerStatefulWidget {
  const _FeedbackSheet({required this.role});
  final String role;

  @override
  ConsumerState<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends ConsumerState<_FeedbackSheet> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _contact = TextEditingController();
  String _category = FeedbackCategory.issue;
  bool _busy = false;

  /// A function rather than a `static const` map, because these are shown to
  /// the person and therefore have to follow the chosen language. A const map
  /// cannot reach the localisations, which is why it used to be English on a
  /// Filipino screen.
  static Map<String, String> _labels(L l) => {
        FeedbackCategory.issue: l.fsCatProblem,
        FeedbackCategory.suggestion: l.fsCatSuggestion,
        FeedbackCategory.question: l.fsCatQuestion,
        FeedbackCategory.other: l.fsCatOther,
      };

  @override
  void dispose() {
    _message.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
      await ref
          .read(firestoreProvider)
          .collection(FsCollections.feedback)
          .add(FeedbackReport.submitPayload(
            uid: uid,
            category: _category,
            role: widget.role,
            message: _message.text,
            contact: _contact.text,
          ));

      if (mounted) {
        Navigator.of(context).pop();
        showSnack(context, context.l.fsSent);
      }
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet above the keyboard so the send button stays reachable.
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l.fsTitle, style: context.text.titleMedium),
            const Gap(AppSpacing.xs),
            Text(
              context.l.fsSubtitle,
              style: context.text.bodySmall,
            ),
            const Gap(AppSpacing.lg),

            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final entry in _labels(context.l).entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _category == entry.key,
                    onSelected: (_) => setState(() => _category = entry.key),
                  ),
              ],
            ),
            const Gap(AppSpacing.lg),

            TextFormField(
              controller: _message,
              maxLines: 4,
              // The rules cap this at 2000; stopping at the limit is kinder
              // than a rejected write after someone has typed a paragraph.
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.l.fsWhatHappened,
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.l.fsDescribe
                  : null,
            ),
            const Gap(AppSpacing.sm),
            TextFormField(
              controller: _contact,
              decoration: InputDecoration(
                labelText: context.l.fsContact,
                helperText: context.l.fsContactHelper,
              ),
            ),
            const Gap(AppSpacing.xl),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: AppSpacing.iconSm,
                      height: AppSpacing.iconSm,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onAccent,
                      ),
                    )
                  : Text(context.l.fsSend),
            ),
          ],
        ),
      ),
    );
  }
}
