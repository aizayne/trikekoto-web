import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/theme_controller.dart';
import '../../rides/data/ride.dart';
import '../../feedback/presentation/feedback_sheet.dart';
import '../application/driver_controllers.dart';
import '../data/driver.dart';
import 'driver_ride_map.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myDriverProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver'),
        actions: [
          IconButton(
            tooltip: 'Report a problem',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () =>
                showFeedbackSheet(context, role: FeedbackRole.driver),
          ),
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(presenceProvider.notifier).goOffline();
              await ref.read(sessionProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(describeError(e))),
        data: (driver) {
          if (driver == null) {
            return const Center(child: Text('No driver profile found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _StatusBanner(driver: driver),
              const Gap(AppSpacing.md),
              // Available at every status, including pending — a driver
              // waiting on approval is exactly who should be able to send
              // the document that unblocks it.
              Card(
                child: ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('ID verification'),
                  subtitle: const Text(
                      'Ipadala ang lisensya o ID para sa chapter'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/driver/id'),
                ),
              ),
              const Gap(AppSpacing.lg),
              if (driver.isApproved) ...[
                const _OnlineToggle(),
                const Gap(AppSpacing.lg),
                const _ActiveRideSection(),
                const Gap(AppSpacing.lg),
                const _OffersSection(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.driver});
  final Driver driver;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    // Status colour comes from the semantic palette, never a literal — the
    // previous hardcoded orange stayed identical in dark mode and lost its
    // contrast against the dark card.
    final (color, container, icon, text) = switch (driver.status) {
      DriverStatus.approved => (
          semantic.success,
          semantic.successContainer,
          Icons.verified_outlined,
          'Verified TODA driver',
        ),
      DriverStatus.suspended => (
          semantic.danger,
          semantic.dangerContainer,
          Icons.block_outlined,
          'Your account is suspended. You cannot accept rides.',
        ),
      DriverStatus.rejected => (
          semantic.danger,
          semantic.dangerContainer,
          Icons.cancel_outlined,
          'Your registration was rejected.',
        ),
      _ => (
          semantic.warning,
          semantic.warningContainer,
          Icons.hourglass_top_outlined,
          'Pending verification. An admin must approve you before you can '
              'accept rides.',
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            // The icon sits on its own tinted container so status reads at a
            // glance, without relying on colour alone to carry the meaning —
            // the wording beside it says the same thing.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: container,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: color, size: AppSpacing.iconMd),
            ),
            const Gap(AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${driver.fullName} • ${driver.plateNumber}',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Gap(AppSpacing.xs / 2),
                  Text(text, style: Theme.of(context).textTheme.bodySmall),
                  if (driver.ratingCount > 0) ...[
                    const Gap(AppSpacing.xs),
                    Text(
                      '★ ${driver.ratingAverage!.toStringAsFixed(1)} '
                      '(${driver.ratingCount})',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineToggle extends ConsumerWidget {
  const _OnlineToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(presenceProvider);

    return Card(
      child: SwitchListTile(
        value: online,
        title: Text(online ? 'Online' : 'Offline'),
        subtitle: Text(
          online
              ? 'Your location is visible to nearby commuters'
              : 'Go online to receive ride offers',
        ),
        onChanged: (want) async {
          final controller = ref.read(presenceProvider.notifier);
          try {
            if (want) {
              await controller.goOnline();
            } else {
              await controller.goOffline();
            }
          } catch (e) {
            if (context.mounted) {
              showSnack(context, describeError(e), error: true);
            }
          }
        },
      ),
    );
  }
}

class _ActiveRideSection extends ConsumerWidget {
  const _ActiveRideSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rideAsync = ref.watch(myActiveRideProvider);

    return rideAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text(describeError(e)),
      data: (ride) {
        if (ride == null) return const SizedBox.shrink();
        final actions = ref.read(rideActionsProvider);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Current ride',
                    style: Theme.of(context).textTheme.titleMedium),
                const Gap(AppSpacing.md),

                // Where to go leads; who to call follows. A driver who has
                // just accepted needs the destination before the name.
                DriverRideMap(ride: ride),
                const Gap(AppSpacing.lg),
                const Divider(height: 1),
                const Gap(AppSpacing.md),

                Row(
                  children: [
                    _CommuterAvatar(ride: ride, radius: 22),
                    const Gap(AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ride.commuterName,
                              style: context.text.titleSmall),
                          Text(ride.commuterPhone,
                              style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Call ${ride.commuterName}',
                      icon: const Icon(Icons.phone),
                      onPressed: () => _call(context, ride.commuterPhone),
                    ),
                  ],
                ),
                const Gap(AppSpacing.lg),
                if (ride.status == RideStatus.accepted)
                  FilledButton(
                    onPressed: () => _run(context, () => actions.start(ride)),
                    child: const Text('Start trip'),
                  )
                else
                  FilledButton(
                    onPressed: () => _run(context, () => actions.complete(ride)),
                    child: const Text('Complete ride'),
                  ),
                const Gap(AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => _run(context, () => actions.cancel(ride)),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Opens the dialler. A driver who cannot find the pickup calls the
  /// passenger — so this must never be a line of text to copy by hand.
  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      // Fall through to the message below.
    }
    if (context.mounted) {
      showSnack(context, 'Could not open the dialler. Number: $phone',
          error: true);
    }
  }
}

class _OffersSection extends ConsumerWidget {
  const _OffersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(myOffersProvider);
    final activeRide = ref.watch(myActiveRideProvider).value;

    // A driver already carrying someone should not be shown new offers.
    if (activeRide != null) return const SizedBox.shrink();

    return offersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(describeError(e)),
      data: (offers) {
        if (offers.isEmpty) {
          final online = ref.watch(presenceProvider);
          return AppEmptyState(
            icon: online
                ? Icons.notifications_none_outlined
                : Icons.wifi_off_outlined,
            title: online ? 'Waiting for a ride' : 'You are offline',
            // The empty state names the reason, so a driver who forgot to go
            // online is not left wondering why nothing arrives.
            body: online
                ? 'You will be offered the nearest booking as soon as one '
                    'comes in. Keep this screen open.'
                : 'Go online above to start receiving ride offers.',
          );
        }

        final actions = ref.read(rideActionsProvider);
        return Column(
          children: [
            for (final ride in offers)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('New ride offer',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Gap(AppSpacing.md),
                      Text('${ride.pickup.label}  →  ${ride.dropoff.label}'),
                      const Gap(AppSpacing.xs),
                      Row(
                        children: [
                          _CommuterAvatar(ride: ride, radius: 14),
                          const Gap(AppSpacing.sm),
                          Text(
                            ride.commuterName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _run(
                                  context, () => actions.decline(ride)),
                              child: const Text('Decline'),
                            ),
                          ),
                          const Gap(AppSpacing.md),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  _run(context, () => actions.accept(ride)),
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

Future<void> _run(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } on StateError catch (e) {
    if (context.mounted) showSnack(context, e.message, error: true);
  } catch (e) {
    if (context.mounted) showSnack(context, describeError(e), error: true);
  }
}


/// The commuter's face, where the driver already sees their name.
///
/// Most commuters book anonymously and have no photo, so this falls back to an
/// initial rather than leaving a hole in the layout — and the fallback is the
/// common case, not the exception.
class _CommuterAvatar extends StatelessWidget {
  const _CommuterAvatar({required this.ride, required this.radius});

  final Ride ride;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = ride.commuterPhotoUrl;
    final initial = ride.commuterName.trim().isEmpty
        ? '?'
        : ride.commuterName.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: context.scheme.secondaryContainer,
      // A failed fetch shows the initial rather than a broken-image glyph:
      // the photo is a convenience, and a driver on a weak signal should not
      // be looking at an error where a face should be.
      foregroundImage: (url != null && url.isNotEmpty)
          ? NetworkImage(url)
          : null,
      onForegroundImageError: (url != null && url.isNotEmpty)
          ? (_, _) {}
          : null,
      child: Text(
        initial,
        style: context.text.titleSmall
            ?.copyWith(color: context.scheme.onSecondaryContainer),
      ),
    );
  }
}
