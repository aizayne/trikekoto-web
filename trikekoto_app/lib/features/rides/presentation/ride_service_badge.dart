import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/locale_controller.dart';
import '../data/ride.dart';

/// Regular or special, as a label readable at a glance.
///
/// Special is the one that changes what happens — the tricycle is the
/// commuter's alone and paid as a full load — so it is drawn to stand out;
/// regular stays quiet.
class RideServiceBadge extends StatelessWidget {
  const RideServiceBadge({super.key, required this.service});

  final RideService service;

  @override
  Widget build(BuildContext context) {
    final special = service == RideService.special;
    final background = special
        ? context.scheme.secondaryContainer
        : context.scheme.surfaceContainerHigh;
    final foreground = special
        ? context.scheme.onSecondaryContainer
        : context.scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            special ? Icons.groups_outlined : Icons.person_outline,
            size: AppSpacing.iconSm,
            color: foreground,
          ),
          const Gap(AppSpacing.xs),
          Flexible(
            child: Text(
              special ? context.l.rideServiceSpecial : context.l.rideServiceRegular,
              style: context.text.labelMedium?.copyWith(
                color: foreground,
                fontWeight: special ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
