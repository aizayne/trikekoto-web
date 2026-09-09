import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/theme_controller.dart';
import '../../../core/ui/locale_controller.dart';
import 'profile_photo_picker.dart';

/// The one screen between a verified number and a working account.
///
/// A single field. The number is already proven by the OTP, so the only thing
/// left that the service genuinely needs is what to call this person when a
/// driver arrives — and every extra field here is a reason to abandon an
/// account that was optional to begin with.
class RiderOnboardingScreen extends ConsumerStatefulWidget {
  const RiderOnboardingScreen({super.key});

  @override
  ConsumerState<RiderOnboardingScreen> createState() =>
      _RiderOnboardingScreenState();
}

class _RiderOnboardingScreenState
    extends ConsumerState<RiderOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  Uint8List? _photo;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .completeRiderOnboarding(name: _name.text, photoBytes: _photo);
      // The session resolves with the profile present and the router moves on.
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(sessionProvider).user?.phoneNumber ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l.onboardingTitle),
        actions: [
          const LanguageToggleButton(),
          const ThemeToggleButton(),
          IconButton(
            tooltip: context.l.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
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
                        onChanged: (bytes) => setState(() => _photo = bytes),
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Text(
                      context.l.onboardingPhotoOptional,
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                    const Gap(AppSpacing.xl),

                    Text(context.l.onboardingAskName,
                        textAlign: TextAlign.center,
                        style: context.text.headlineSmall),
                    const Gap(AppSpacing.sm),
                    Text(
                      context.l.onboardingNameWhy,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium
                          ?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                    const Gap(AppSpacing.xxl),

                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: context.l.nameLabel,
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? context.l.nameRequired
                          : (v!.trim().length > 60
                              ? context.l.nameTooLong
                              : null),
                      onFieldSubmitted: (_) => _busy ? null : _finish(),
                    ),
                    const Gap(AppSpacing.lg),

                    // Shown, not editable. Changing it means proving a new
                    // number, which means signing in again — so presenting it
                    // as a field would be a promise the rules refuse to keep.
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

                    FilledButton(
                      onPressed: _busy ? null : _finish,
                      child: _busy
                          ? const SizedBox(
                              width: AppSpacing.iconSm,
                              height: AppSpacing.iconSm,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.onAccent),
                            )
                          : Text(context.l.onboardingStart),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
