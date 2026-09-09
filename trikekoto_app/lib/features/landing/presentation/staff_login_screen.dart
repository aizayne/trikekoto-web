import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/theme_controller.dart';
import '../../../core/ui/locale_controller.dart';

/// One form for both drivers and admins. Which panel you land in is decided by
/// [SessionController] from Firestore, not by anything chosen here — picking
/// your own role on a login screen would be meaningless, since the rules
/// decide what you can actually do.
class StaffLoginScreen extends ConsumerStatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  ConsumerState<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends ConsumerState<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .signInWithEmail(_email.text, _password.text);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l.loginTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: const [LanguageToggleButton(), ThemeToggleButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.l.loginWelcome,
                          style: context.text.headlineSmall),
                      const Gap(AppSpacing.xs),
                      Text(
                        context.l.loginBody,
                        style: context.text.bodySmall,
                      ),
                      const Gap(AppSpacing.xxl),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: context.l.regEmail,
                          prefixIcon: const Icon(Icons.mail_outline),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? context.l.loginEmailInvalid
                            : null,
                      ),
                      const Gap(AppSpacing.md),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: context.l.regPassword,
                          prefixIcon: const Icon(Icons.lock_outline),
                          // Typing a password blind on a phone keyboard in
                          // sunlight is the usual cause of a failed sign-in.
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? context.l.regShowPassword
                                : context.l.regHidePassword,
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? context.l.loginPasswordTooShort
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const Gap(AppSpacing.xxl),
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
                            : Text(context.l.loginTitle),
                      ),
                      const Gap(AppSpacing.sm),
                      TextButton(
                        onPressed: _busy ? null : () => context.go('/register'),
                        child: Text(context.l.loginRegisterAsDriver),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
