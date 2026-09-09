import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/trike_icon.dart';

/// Both buttons only navigate, so this holds no state.
///
/// It was stateful for the anonymous sign-in, which happened here and needed a
/// spinner. That path is gone: every commuter now verifies a phone number, and
/// the waiting happens on the sign-in screen where the code arrives.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

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
                    child: TrikeIcon(
                      size: 52,
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

                  // Every commuter verifies a phone number. There is no
                  // anonymous path any more: a ride is a stranger getting
                  // into a stranger's vehicle, and both ends being
                  // identifiable is the point.
                  FilledButton.icon(
                    onPressed: () => context.go('/rider-signin'),
                    icon: const Icon(Icons.phone_iphone_outlined),
                    label: const Text('Book a ride'),
                  ),
                  const Gap(AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Driver / Admin sign in'),
                  ),
                  const Gap(AppSpacing.xxl),
                  Text(
                    'Kailangan ng number para makapag-book.',
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
