import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/ui/app_theme.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  bool _busy = false;

  Future<void> _continueAsCommuter() async {
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).continueAsCommuter();
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Scaffold(
      // SafeArea keeps the content clear of the status bar and the gesture
      // indicator — this screen has no app bar to do it for us.
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
                  Container(
                    height: 88,
                    width: 88,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: Icon(
                      Icons.electric_rickshaw,
                      size: 48,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const Gap(AppSpacing.xl),
                  Text(
                    'TrikeKoTo',
                    textAlign: TextAlign.center,
                    style: context.text.displaySmall,
                  ),
                  const Gap(AppSpacing.sm),
                  Text(
                    'On-demand tricycle rides for your barangay',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const Gap(AppSpacing.xxxl),

                  // The commuter path is the primary action, so it is the
                  // only element carrying the accent.
                  FilledButton.icon(
                    onPressed: _busy ? null : _continueAsCommuter,
                    icon: _busy
                        ? const SizedBox(
                            width: AppSpacing.iconSm,
                            height: AppSpacing.iconSm,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onAccent,
                            ),
                          )
                        : const Icon(Icons.person_outline),
                    label: Text(_busy ? 'Getting ready…' : 'Book a ride'),
                  ),
                  const Gap(AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => context.go('/login'),
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Driver / Admin sign in'),
                  ),
                  const Gap(AppSpacing.xxl),
                  Text(
                    'Booking a ride does not need an account.',
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
