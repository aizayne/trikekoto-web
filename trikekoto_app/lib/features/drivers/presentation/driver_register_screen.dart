import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/providers.dart';
import '../../../core/ui/app_theme.dart';
import '../data/driver.dart';
import '../../../core/ui/locale_controller.dart';

class DriverRegisterScreen extends ConsumerStatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  ConsumerState<DriverRegisterScreen> createState() =>
      _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends ConsumerState<DriverRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _plate = TextEditingController();
  final _toda = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    for (final c in [
      _email,
      _password,
      _firstName,
      _lastName,
      _phone,
      _plate,
      _toda,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      final session = ref.read(sessionProvider.notifier);
      final credential = await session.registerDriverAccount(
        _email.text,
        _password.text,
      );

      // The profile write must follow account creation: the rule requires
      // `uid == request.auth.uid`, so there is nothing valid to write until
      // the account exists.
      await ref
          .read(firestoreProvider)
          .collection(FsCollections.drivers)
          .doc(normalizeEmail(_email.text))
          .set(Driver.registrationPayload(
            email: _email.text,
            uid: credential.user!.uid,
            firstName: _firstName.text,
            lastName: _lastName.text,
            phone: _phone.text,
            plateNumber: _plate.text,
            todaChapter: _toda.text,
          ));

      await session.refresh();
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
        title: Text(context.l.regTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Says up front what happens after submitting, so the
                    // pending screen is not a surprise.
                    _Notice(
                      icon: Icons.hourglass_top_outlined,
                      text: context.l.regPendingNote,
                    ),
                    const Gap(AppSpacing.xl),

                    _SectionLabel(context.l.regYourDetails),
                    const Gap(AppSpacing.md),
                    _field(_firstName, context.l.regFirstName,
                        icon: Icons.person_outline,
                        capitalization: TextCapitalization.words),
                    const Gap(AppSpacing.md),
                    _field(_lastName, context.l.regLastName,
                        capitalization: TextCapitalization.words),
                    const Gap(AppSpacing.md),
                    _field(
                      _phone,
                      context.l.regMobile,
                      min: 7,
                      icon: Icons.phone_outlined,
                      keyboard: TextInputType.phone,
                      helper: context.l.regMobileHelper,
                    ),

                    const Gap(AppSpacing.xxl),
                    _SectionLabel(context.l.regYourTricycle),
                    const Gap(AppSpacing.md),
                    _field(
                      _plate,
                      context.l.regPlate,
                      min: 3,
                      icon: Icons.confirmation_number_outlined,
                      capitalization: TextCapitalization.characters,
                      helper: context.l.regPlateHelper,
                    ),
                    const Gap(AppSpacing.md),
                    _field(_toda, context.l.regTodaChapter,
                        icon: Icons.groups_outlined,
                        capitalization: TextCapitalization.words),

                    const Gap(AppSpacing.xxl),
                    _SectionLabel(context.l.regSignInSection),
                    const Gap(AppSpacing.md),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: context.l.regEmail,
                        prefixIcon: const Icon(Icons.mail_outline),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? context.l.regEmailInvalid
                          : null,
                    ),
                    const Gap(AppSpacing.md),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: context.l.regPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        helperText: context.l.regPasswordHelper,
                        suffixIcon: IconButton(
                          tooltip:
                              _obscure
                                  ? context.l.regShowPassword
                                  : context.l.regHidePassword,
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? context.l.regPasswordTooShort
                          : null,
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
                          : Text(context.l.regCreateAccount),
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

  Widget _field(
    TextEditingController c,
    String label, {
    int min = 1,
    IconData? icon,
    String? helper,
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: icon == null ? null : Icon(icon),
      ),
      // Errors name the field rather than saying "Required", so an error
      // summary read aloud still identifies what to fix.
      validator: (v) => (v == null || v.trim().length < min)
          ? context.l.regFieldRequired(label.toLowerCase())
          : null,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: context.text.bodySmall?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: context.scheme.onSurfaceVariant,
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.semantic.warningContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSpacing.iconSm, color: context.semantic.warning),
          const Gap(AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall
                  ?.copyWith(color: context.scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
