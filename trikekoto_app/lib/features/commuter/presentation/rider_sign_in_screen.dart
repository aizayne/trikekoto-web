import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/locale_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/ui/theme_controller.dart';
import '../data/phone_number.dart';

/// Phone + OTP sign-in. Every commuter passes through here.
///
/// Not optional, despite what an earlier version of this comment said:
/// `hasVerifiedPhone()` in the security rules refuses a ride creation without
/// a verified number, so there is no path to booking that skips this screen.
/// The gate that matters is that rule rather than this UI — a client screen
/// can be bypassed and a token claim cannot.
///
/// Two panes rather than two routes: the code arrives seconds after the
/// number is submitted, and a route change there loses the keyboard and the
/// number they just typed if anything goes wrong.
class RiderSignInScreen extends ConsumerStatefulWidget {
  const RiderSignInScreen({super.key});

  @override
  ConsumerState<RiderSignInScreen> createState() => _RiderSignInScreenState();
}

class _RiderSignInScreenState extends ConsumerState<RiderSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();

  String? _verificationId;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    final e164 = toE164Ph(_phone.text)!;

    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).startPhoneSignIn(
            phoneE164: e164,
            codeSent: (id) {
              if (!mounted) return;
              setState(() {
                _verificationId = id;
                _busy = false;
              });
              showSnack(context, context.l.signInCodeSentSnack(e164));
            },
            // Play Integrity can verify the device without an SMS. When that
            // happens the session is already signed in, and sitting on a code
            // screen waiting for a message that will never arrive is the worst
            // possible outcome.
            autoVerified: () {
              if (mounted) setState(() => _busy = false);
            },
            failed: (e) {
              if (!mounted) return;
              setState(() => _busy = false);
              showSnack(context, _explain(context.l, e), error: true);
            },
          );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, _explain(context.l, e), error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, _explainUnknown(context.l, e), error: true);
      }
    }
  }

  Future<void> _confirm() async {
    if (_code.text.trim().length < 6) {
      showSnack(context, context.l.signInEnterSixDigits, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).confirmSmsCode(
            verificationId: _verificationId!,
            smsCode: _code.text.trim(),
          );
      // The router takes over: onboarding if this is a new account, the
      // booking screen if the profile already exists.
    } on FirebaseAuthException catch (e) {
      if (mounted) showSnack(context, _explain(context.l, e), error: true);
    } catch (e) {
      if (mounted) showSnack(context, _explainUnknown(context.l, e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Firebase's codes say what went wrong to a developer. These say it to a
  /// commuter standing at a terminal.
  static String _explain(L l, FirebaseAuthException e) => switch (e.code) {
        'invalid-phone-number' => l.authInvalidPhone,
        'invalid-verification-code' => l.authWrongCode,
        'session-expired' => l.authCodeExpired,
        'too-many-requests' => l.authTooManyTries,
        // This used to end "...or book without an account", which stopped
        // being true the day accounts became mandatory. Nobody noticed,
        // because the string only appears once Firebase's SMS quota is spent.
        'quota-exceeded' => l.authQuotaExceeded,
        'network-request-failed' => l.authNoConnection,
        'operation-not-allowed' => l.authPhoneSignInOff,
        'captcha-check-failed' => l.authCaptchaFailed,
        'invalid-app-credential' => l.authAppNotRegistered,
        'app-not-authorized' => l.authSiteNotAllowed,
        // Unknown codes keep the code visible. A bare "error" tells the
        // person nothing and tells whoever they report it to even less.
        _ => l.authUnknown(e.message ?? l.authCouldNotVerify, e.code),
      };

  /// Anything that is not a [FirebaseAuthException].
  ///
  /// The web SDK can surface failures that never become a typed auth error —
  /// a blocked reCAPTCHA, an interop failure. The generic handler stripped
  /// those to the single word "error", which is unreportable.
  static String _explainUnknown(L l, Object e) {
    final text = e.toString().replaceAll(RegExp(r'\[.*?\]\s*'), '').trim();
    return text.isEmpty || text.toLowerCase() == 'error'
        ? l.authCouldNotSend('${e.runtimeType}')
        : '$text (${e.runtimeType})';
  }

  @override
  Widget build(BuildContext context) {
    final onCode = _verificationId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            onCode ? context.l.signInCodeTitle : context.l.signInTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => onCode
              ? setState(() => _verificationId = null)
              : context.go('/'),
        ),
        actions: const [ThemeToggleButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: onCode ? _codePane() : _phonePane(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phonePane() => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l.signInAskNumber,
                style: context.text.headlineSmall),
            const Gap(AppSpacing.sm),
            Text(
              context.l.signInWhyNumber,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
            const Gap(AppSpacing.xxl),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ -]')),
              ],
              decoration: InputDecoration(
                labelText: context.l.signInNumberLabel,
                prefixIcon: const Icon(Icons.phone_outlined),
                helperText: context.l.signInNumberHelper,
              ),
              validator: (v) => toE164Ph(v ?? '') == null
                  ? context.l.signInNumberInvalid
                  : null,
            ),
            const Gap(AppSpacing.xxl),
            FilledButton.icon(
              onPressed: _busy ? null : _sendCode,
              icon: _busy
                  ? const SizedBox(
                      width: AppSpacing.iconSm,
                      height: AppSpacing.iconSm,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.onAccent),
                    )
                  : const Icon(Icons.sms_outlined),
              label: Text(
                  _busy ? context.l.signInSending : context.l.signInSendCode),
            ),
            // There is deliberately no "book without an account" escape here.
            // It existed while accounts were optional; once booking required a
            // verified phone it became a label promising something the rules
            // refuse, and it led to `/`, where "Book a ride" returns straight
            // back to this screen. A button that loops under a false promise is
            // worse than no button. The back arrow still leaves.
          ],
        ),
      );

  Widget _codePane() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l.signInCodeTitle,
              style: context.text.headlineSmall),
          const Gap(AppSpacing.sm),
          Text(
            context.l.signInCodeSentTo(_phone.text.trim()),
            style: context.text.bodyMedium
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
          const Gap(AppSpacing.xxl),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            maxLength: 6,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall?.copyWith(letterSpacing: 8),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(counterText: ''),
          ),
          const Gap(AppSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            child: _busy
                ? const SizedBox(
                    width: AppSpacing.iconSm,
                    height: AppSpacing.iconSm,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.onAccent),
                  )
                : Text(context.l.signInConfirm),
          ),
          const Gap(AppSpacing.md),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _verificationId = null),
            child: Text(context.l.signInOtherNumber),
          ),
        ],
      );
}
