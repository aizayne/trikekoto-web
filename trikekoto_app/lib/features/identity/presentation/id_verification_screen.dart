import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/ui/app_theme.dart';
import '../application/id_verification_service.dart';
import '../data/id_submission.dart';

/// Submitting a government ID, for either role.
///
/// One screen for drivers and commuters. The obligations under RA 10173 do
/// not vary by role, and two screens would have meant two consent notices
/// drifting apart.
///
/// Consent is a gate, not a footnote. The submit button stays disabled until
/// the box is ticked, and what is being agreed to is on screen rather than
/// behind a link — a consent nobody read is not consent, and the timestamp
/// the rules require would be evidence of something that did not happen.
class IdVerificationScreen extends ConsumerStatefulWidget {
  const IdVerificationScreen({super.key, required this.role});

  final String role;

  @override
  ConsumerState<IdVerificationScreen> createState() =>
      _IdVerificationScreenState();
}

class _IdVerificationScreenState extends ConsumerState<IdVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();

  String _idType = 'national_id';
  Uint8List? _photo;
  bool _consented = false;
  bool _busy = false;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final bytes =
          await ref.read(idVerificationServiceProvider).pick(source: source);
      if (bytes == null || !mounted) return;
      setState(() => _photo = bytes);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    }
  }

  Future<void> _choosePhoto() async {
    if (_busy) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kunan ng litrato ang ID'),
              onTap: () {
                Navigator.pop(sheet);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pumili sa gallery'),
              onTap: () {
                Navigator.pop(sheet);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photo == null) {
      showSnack(context, 'Kailangan ng litrato ng ID.', error: true);
      return;
    }
    if (!_consented) {
      showSnack(context, 'Kailangan mong pumayag muna.', error: true);
      return;
    }

    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(idVerificationServiceProvider).submit(
            uid: uid,
            role: widget.role,
            idType: _idType,
            idNumber: _number.text,
            photoBytes: _photo!,
          );
      if (mounted) {
        showSnack(context, 'Naipadala na. Hihintayin ang review.');
      }
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw() async {
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return;

    final sure = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Bawiin ang ID?'),
        content: const Text(
          'Buburahin ang litrato at ang detalye ng ID mo. Puwede kang '
          'magpadala ulit anumang oras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Hindi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Burahin'),
          ),
        ],
      ),
    );
    if (sure != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(idVerificationServiceProvider).withdraw(uid);
      if (mounted) {
        setState(() {
          _photo = null;
          _consented = false;
          _number.clear();
        });
        showSnack(context, 'Nabura na ang ID mo.');
      }
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myIdSubmissionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ID verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: mine.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => _form(context),
                data: (sub) =>
                    sub == null ? _form(context) : _status(context, sub),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Already submitted ───────────────────────────────────────
  Widget _status(BuildContext context, IdSubmission sub) {
    final (icon, colour, title, body) = switch (sub.status) {
      IdStatus.approved => (
          Icons.verified_user_outlined,
          context.semantic.success,
          'Beripikado na',
          'Nakumpirma ng chapter ang ID mo.',
        ),
      IdStatus.rejected => (
          Icons.report_outlined,
          context.scheme.error,
          'Hindi tinanggap',
          sub.rejectionReason ?? 'Walang ibinigay na dahilan.',
        ),
      _ => (
          Icons.hourglass_empty,
          context.scheme.secondary,
          'Hinihintay ang review',
          'Ipinadala na ang ID mo. Aabisuhan ka dito pagkatapos.',
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 56, color: colour),
        const Gap(AppSpacing.lg),
        Text(title,
            textAlign: TextAlign.center, style: context.text.headlineSmall),
        const Gap(AppSpacing.sm),
        Text(body,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium
                ?.copyWith(color: context.scheme.onSurfaceVariant)),
        const Gap(AppSpacing.xxl),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _row(context, 'Uri ng ID', IdTypes.label(sub.idType)),
                const Gap(AppSpacing.sm),
                // Masked. A reviewer needs the number; the person who
                // submitted it only needs to recognise which card this was.
                _row(context, 'Numero', _mask(sub.idNumber)),
              ],
            ),
          ),
        ),
        const Gap(AppSpacing.xxl),

        OutlinedButton.icon(
          onPressed: _busy ? null : _withdraw,
          icon: Icon(Icons.delete_outline, color: context.scheme.error),
          label: Text('Bawiin at burahin ang ID',
              style: TextStyle(color: context.scheme.error)),
        ),
        const Gap(AppSpacing.sm),
        Text(
          'Buburahin nito ang litrato at ang detalye, kahit na-aprubahan na.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall,
        ),
      ],
    );
  }

  static Widget _row(BuildContext context, String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: context.text.bodySmall),
          Flexible(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: context.text.bodyMedium)),
        ],
      );

  static String _mask(String n) =>
      n.length <= 4 ? n : '${'•' * (n.length - 4)}${n.substring(n.length - 4)}';

  // ── Not yet submitted ───────────────────────────────────────
  Widget _form(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kumpirmahin ang pagkakakilanlan',
              style: context.text.headlineSmall),
          const Gap(AppSpacing.sm),
          Text(
            widget.role == IdRole.driver
                ? 'Kailangan ito ng TODA chapter bago ka makatanggap ng biyahe.'
                : 'Nakakatulong ito para ligtas ang lahat sa biyahe.',
            style: context.text.bodyMedium
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
          const Gap(AppSpacing.xxl),

          DropdownButtonFormField<String>(
            initialValue: _idType,
            decoration: const InputDecoration(
              labelText: 'Uri ng ID',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: [
              for (final e in IdTypes.options.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _idType = v!),
          ),
          const Gap(AppSpacing.lg),

          TextFormField(
            controller: _number,
            decoration: const InputDecoration(
              labelText: 'Numero ng ID',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.length < 4) return 'Masyadong maikli';
              if (t.length > 40) return 'Masyadong mahaba';
              return null;
            },
          ),
          const Gap(AppSpacing.xl),

          _photoBox(context),
          const Gap(AppSpacing.xl),

          _consentBox(context),
          const Gap(AppSpacing.xl),

          FilledButton(
            // Disabled until consent is given. The rules require a consent
            // timestamp; a button that submits without one would be
            // recording something untrue.
            onPressed: (_busy || !_consented) ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: AppSpacing.iconSm,
                    height: AppSpacing.iconSm,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.onAccent),
                  )
                : const Text('Ipadala para sa review'),
          ),
        ],
      ),
    );
  }

  Widget _photoBox(BuildContext context) => InkWell(
        onTap: _busy ? null : _choosePhoto,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          height: 190,
          decoration: BoxDecoration(
            color: context.scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: _photo == null
                  ? context.scheme.outlineVariant
                  : context.semantic.success,
              width: _photo == null ? 1 : 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _photo != null
              ? Image.memory(_photo!, fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        size: AppSpacing.iconLg,
                        color: context.scheme.onSurfaceVariant),
                    const Gap(AppSpacing.sm),
                    Text('Litrato ng ID',
                        style: context.text.titleSmall),
                    const Gap(AppSpacing.xs),
                    Text('Siguraduhing mabasa ang pangalan at numero',
                        style: context.text.bodySmall),
                  ],
                ),
        ),
      );

  /// What is being agreed to, in full, on screen.
  ///
  /// Not a link, and not a sentence saying "by continuing you agree". Under
  /// RA 10173 consent has to be freely given, specific and informed, and the
  /// rules store a timestamp asserting it happened — so what it refers to had
  /// better be visible at the moment it is given.
  Widget _consentBox(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: context.scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paano gagamitin ang ID mo',
                style: context.text.titleSmall),
            const Gap(AppSpacing.sm),
            Text(
              '• Titingnan lang ito ng opisyal ng TODA chapter para kumpirmahin '
              'kung sino ka.\n'
              '• Hindi ito makikita ng ibang pasahero o ng driver mo.\n'
              '• Buburahin ito 90 araw matapos ang review, o kaagad kapag '
              'binawi mo.\n'
              '• Puwede mong burahin anumang oras dito sa screen na ito.',
              style: context.text.bodySmall,
            ),
            const Gap(AppSpacing.md),
            CheckboxListTile(
              value: _consented,
              onChanged: _busy ? null : (v) => setState(() => _consented = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Pumapayag ako na iproseso ang ID ko para sa pagkumpirma.',
                style: context.text.bodyMedium,
              ),
            ),
          ],
        ),
      );
}
