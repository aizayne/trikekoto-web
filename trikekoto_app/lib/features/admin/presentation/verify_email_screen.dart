import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/theme_controller.dart';
import '../../../core/ui/locale_controller.dart';

/// Shown instead of the admin panel when the signed-in address is unconfirmed.
///
/// The rules require `email_verified` for admin access, but the client's role
/// check only looks for the `admins/{email}` document — so before this screen
/// existed, an unverified admin was routed into the panel and then watched
/// every query fail with a permission error that named nothing.
///
/// It also removes a real bootstrap problem: the Firebase console has no
/// button to send a verification email or to mark an address verified. Without
/// this screen, confirming the very first admin needs a service-account key.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _sending = false;
  bool _checking = false;
  bool _sentOnce = false;

  /// Firebase rate-limits verification mail, and a second tap inside a few
  /// seconds gets rejected rather than sending twice. Counting down is
  /// friendlier than surfacing that error.
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref.read(sessionProvider.notifier).sendVerificationEmail();
      if (mounted) {
        setState(() => _sentOnce = true);
        _startCooldown();
        showSnack(context, 'Verification email sent.');
      }
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final verified =
          await ref.read(sessionProvider.notifier).refreshVerification();
      if (!mounted) return;
      if (!verified) {
        showSnack(
          context,
          'Still not confirmed. Open the link in the email, then check again.',
          error: true,
        );
      }
      // When it succeeds the session updates and this screen is replaced —
      // no success message needed, the panel appearing is the message.
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(sessionProvider).user?.email ?? 'your address';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm your email'),
        actions: [
          const LanguageToggleButton(),
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Sign out',
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: AppSpacing.iconLg,
                    color: context.semantic.warning,
                  ),
                  const Gap(AppSpacing.xl),

                  Text(
                    'Confirm your email to open the admin panel',
                    textAlign: TextAlign.center,
                    style: context.text.titleLarge,
                  ),
                  const Gap(AppSpacing.md),

                  Text(
                    'Signing up does not prove you own an address, so the '
                    'server will not grant admin access until $email is '
                    'confirmed.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium
                        ?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                  const Gap(AppSpacing.xxl),

                  FilledButton.icon(
                    onPressed:
                        _sending || _cooldown > 0 ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: AppSpacing.iconSm,
                            height: AppSpacing.iconSm,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onAccent,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _cooldown > 0
                          ? 'Send again in ${_cooldown}s'
                          : _sentOnce
                              ? 'Send again'
                              : 'Send verification email',
                    ),
                  ),
                  const Gap(AppSpacing.md),

                  OutlinedButton.icon(
                    onPressed: _checking ? null : _check,
                    icon: _checking
                        ? const SizedBox(
                            width: AppSpacing.iconSm,
                            height: AppSpacing.iconSm,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('I have confirmed it'),
                  ),

                  if (_sentOnce) ...[
                    const Gap(AppSpacing.xl),
                    Text(
                      'Check spam if it has not arrived. Open the link, come '
                      'back here, then tap "I have confirmed it".',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
