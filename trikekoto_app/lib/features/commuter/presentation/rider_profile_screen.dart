import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/theme_controller.dart';
import '../application/commuter_location.dart';
import 'profile_photo_picker.dart';
import '../../../core/ui/locale_controller.dart';

/// The rider's own profile — the only place a photo can be changed after
/// sign-up.
///
/// Onboarding used to be the sole entry point for the picker, and it invites
/// people to skip the photo. That left anyone who skipped unable to ever add
/// one, and anyone who added one unable to replace it — while
/// `setRiderPhoto()` sat in the session controller with no caller. This screen
/// is what that method was written for.
///
/// Name and photo are saved independently, because they finish at different
/// moments: the name the instant Save is pressed, the photo only once an
/// upload returns. Bundling them would mean a failed upload discarding a
/// perfectly good rename.
class RiderProfileScreen extends ConsumerStatefulWidget {
  const RiderProfileScreen({super.key});

  @override
  ConsumerState<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends ConsumerState<RiderProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  /// Set once from the loaded profile, so a rebuild mid-edit does not wipe
  /// what the rider is typing.
  bool _nameSeeded = false;

  /// Null means "no change". Distinguishing that from an explicit removal is
  /// the whole reason this is not just a `Uint8List?`.
  bool _photoTouched = false;
  Uint8List? _photoBytes;

  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final session = ref.read(sessionProvider.notifier);
    var renamed = false;

    try {
      await session.updateRiderName(_name.text);
      renamed = true;

      if (_photoTouched) {
        await session.setRiderPhoto(_photoBytes);
      }

      if (!mounted) return;
      setState(() => _photoTouched = false);
      showSnack(context, context.l.profileSaved);
    } catch (e) {
      if (!mounted) return;
      // Says which half landed. "Save failed" after a successful rename would
      // send the rider back to retype a name that is already stored.
      showSnack(
        context,
        renamed
            ? context.l.profileNamedSavedNotPhoto(describeError(e))
            : describeError(e),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Deleting the account, behind a confirmation that says what actually
  /// happens — including the part that does not go away.
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(context.l.deleteAccountQuestion),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l.deleteAccountPermanent),
              Gap(AppSpacing.sm),
              Text(context.l.deleteAccountList),
              Gap(AppSpacing.lg),
              // Said plainly rather than buried. A deletion notice that omits
              // what is retained is the part people later discover and feel
              // lied to about.
              Text(context.l.deleteAccountRetained),
              Gap(AppSpacing.lg),
              Text(context.l.deleteAccountIrreversible),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(context.l.deleteAccountNo),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(context.l.deleteAccount),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).deleteAccount();
      // The router takes over the moment the session clears; no navigation
      // and no success message, because there is no longer a screen or an
      // account for either to belong to.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showSnack(
        context,
        e.code == 'requires-recent-login'
            // Firebase refusing a destructive act on a stale credential.
            // Worth saying precisely, because "try again" would not work.
            ? context.l.deleteAccountReauth
            : describeError(e),
        error: true,
      );
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, describeError(e), error: true);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myRiderProfileProvider);
    final phone = ref.watch(sessionProvider).user?.phoneNumber ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l.profileTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/commuter'),
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: context.l.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // A read failure here is not fatal — the rider is signed in either
        // way — but editing a profile you cannot see would write over fields
        // blind, so this offers a retry instead of a form.
        error: (_, _) => AppEmptyState(
          icon: Icons.cloud_off,
          title: context.l.profileLoadFailedTitle,
          body: context.l.profileLoadFailedBody,
          action: FilledButton(
            onPressed: () => ref.invalidate(myRiderProfileProvider),
            child: Text(context.l.profileRetry),
          ),
        ),
        data: (rider) {
          if (rider == null) {
            return AppEmptyState(
              icon: Icons.person_off_outlined,
              title: context.l.profileNoneTitle,
              body: context.l.profileNoneBody,
            );
          }

          if (!_nameSeeded) {
            _name.text = rider.name;
            _nameSeeded = true;
          }

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: ProfilePhotoPicker(
                            enabled: !_busy,
                            // Shows what is stored until a new one is chosen.
                            existingUrl: rider.profilePhotoUrl,
                            onChanged: (bytes) => setState(() {
                              _photoTouched = true;
                              _photoBytes = bytes;
                            }),
                          ),
                        ),
                        const Gap(AppSpacing.sm),
                        Text(
                          _photoTouched
                              ? context.l.profilePhotoWillSave
                              : context.l.profilePhotoTapToChange,
                          textAlign: TextAlign.center,
                          style: context.text.bodySmall?.copyWith(
                              color: context.scheme.onSurfaceVariant),
                        ),
                        const Gap(AppSpacing.xxl),

                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: context.l.nameLabel,
                            prefixIcon: const Icon(Icons.badge_outlined),
                            helperText: context.l.profileNameHelper,
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? context.l.nameRequired
                              : (v!.trim().length > 60
                                  ? context.l.nameTooLong
                                  : null),
                        ),
                        const Gap(AppSpacing.lg),

                        // Shown, never editable. Changing it means proving a
                        // new number, which means signing in again — the rules
                        // refuse a phone change on this document outright.
                        if (phone.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.verified_outlined,
                                  size: AppSpacing.iconSm,
                                  color: context.semantic.success),
                              const Gap(AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  context.l.phoneConfirmed(phone),
                                  style: context.text.bodySmall?.copyWith(
                                      color: context.scheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        const Gap(AppSpacing.xxl),

                        // Separate from Save. Submitting an ID is a
                        // different act with different consequences, and
                        // bundling it into "save your profile" would be a
                        // consent nobody noticed giving.
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => context.push('/commuter/id'),
                          icon: const Icon(Icons.badge_outlined),
                          label: Text(context.l.profileIdVerification),
                        ),
                        const Gap(AppSpacing.lg),

                        FilledButton(
                          onPressed: _busy ? null : _save,
                          child: _busy
                              ? const SizedBox(
                                  width: AppSpacing.iconSm,
                                  height: AppSpacing.iconSm,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.onAccent),
                                )
                              : Text(context.l.profileSave),
                        ),

                        // Set well apart from Save, at the end, in the error
                        // colour and without a filled background. Destructive
                        // and irreversible: it should never be the thing a
                        // thumb finds by accident.
                        const Gap(AppSpacing.xxxl),
                        const Divider(),
                        const Gap(AppSpacing.lg),
                        TextButton.icon(
                          onPressed: _busy ? null : _delete,
                          icon: Icon(Icons.delete_forever_outlined,
                              color: context.scheme.error),
                          label: Text(context.l.deleteAccount,
                              style: TextStyle(color: context.scheme.error)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
