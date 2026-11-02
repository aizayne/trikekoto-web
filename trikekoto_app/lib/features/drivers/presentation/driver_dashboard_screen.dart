import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/geo/geo_utils.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/confirm_sign_out.dart';
import '../../../core/ui/theme_controller.dart';
import '../../rides/data/ride.dart';
import '../../feedback/presentation/feedback_sheet.dart';
import '../../notifications/application/notifications.dart';
import '../application/driver_controllers.dart';
import '../data/driver.dart';
import 'driver_ride_map.dart';
import '../../rides/presentation/ride_service_badge.dart';
import '../../../core/ui/locale_controller.dart';
import '../../../core/ui/build_stamp.dart';
import '../../identity/application/id_verification_service.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myDriverProfileProvider);
    final idVerified = ref.watch(myIdVerifiedProvider).value == true;
    final unread = ref.watch(unreadNoticeCountProvider);
    // Starts push registration for this driver. Watched rather than read so
    // it runs once while the dashboard is open, whatever their status —
    // approval is the message that has to reach a driver who is not online.
    ref.watch(driverPushRegistrationProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l.driverTitle),
        actions: [
          // First of the actions: a driver waiting on approval is told here,
          // and the count is the only thing on this screen that asks to be
          // looked at.
          IconButton(
            tooltip: context.l.noticesTitle,
            icon: unread == 0
                ? const Icon(Icons.notifications_none_outlined)
                : Badge.count(
                    count: unread,
                    child: const Icon(Icons.notifications),
                  ),
            onPressed: () => context.push('/driver/notifications'),
          ),
          IconButton(
            tooltip: context.l.historyTitle,
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/driver/history'),
          ),
          IconButton(
            tooltip: context.l.driverReportProblem,
            icon: const Icon(Icons.flag_outlined),
            onPressed: () =>
                showFeedbackSheet(context, role: FeedbackRole.driver),
          ),
          const LanguageToggleButton(),
          const ThemeToggleButton(),
          IconButton(
            tooltip: context.l.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (!await confirmSignOut(context)) return;
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
            // Registration stopped after the sign-in was created. Without a
            // way forward this screen is a dead end, because the email address
            // cannot be registered a second time.
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l.driverNoProfile,
                        textAlign: TextAlign.center,
                        style: context.text.titleMedium),
                    const Gap(AppSpacing.sm),
                    Text(context.l.driverFinishBody,
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium),
                    const Gap(AppSpacing.xl),
                    FilledButton(
                      onPressed: () =>
                          context.go('/driver/finish-registration'),
                      child: Text(context.l.driverFinishButton),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              _StatusBanner(driver: driver),
              const Gap(AppSpacing.md),
              // Available at every status, including pending — a driver
              // waiting on approval is exactly who should be able to send
              // the document that unblocks it.
              // Once verified it stays verified, so the card stops asking.
              // Still tappable: the driver may want to withdraw the photo,
              // which deletes the ID but not the verification.
              Card(
                child: ListTile(
                  leading: idVerified
                      ? Icon(Icons.verified_user_outlined,
                          color: context.semantic.success)
                      : const Icon(Icons.badge_outlined),
                  title: Text(context.l.driverIdVerification),
                  subtitle: Text(idVerified
                      ? context.l.idVerifiedBadge
                      : context.l.driverIdSubtitle),
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
              const Gap(AppSpacing.xl),
              const BuildStamp(),
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
          context.l.driverVerified,
        ),
      DriverStatus.suspended => (
          semantic.danger,
          semantic.dangerContainer,
          Icons.block_outlined,
          context.l.driverSuspended,
        ),
      DriverStatus.rejected => (
          semantic.danger,
          semantic.dangerContainer,
          Icons.cancel_outlined,
          context.l.driverRejected,
        ),
      _ => (
          semantic.warning,
          semantic.warningContainer,
          Icons.hourglass_top_outlined,
          context.l.driverPending,
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
                  Text(
                      context.l.driverNamePlate(
                          driver.fullName, driver.plateNumber),
                      style: Theme.of(context).textTheme.titleSmall),
                  const Gap(AppSpacing.xs / 2),
                  Text(text, style: Theme.of(context).textTheme.bodySmall),
                  if (driver.ratingCount > 0) ...[
                    const Gap(AppSpacing.xs),
                    Text(
                      context.l.driverRating(
                          driver.ratingAverage!.toStringAsFixed(1),
                          '${driver.ratingCount}'),
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
    final status = ref.watch(presenceStatusProvider);
    final issue = status.issue;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            value: online,
            // A spinner where the driver is looking. Going online takes a few
            // seconds, and with nothing on screen for that long drivers tapped
            // again — which started a second attempt or undid the first.
            secondary: status.connecting
                ? const SizedBox(
                    width: AppSpacing.iconSm,
                    height: AppSpacing.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            title: Text(status.connecting
                ? context.l.presenceConnecting
                : online
                    ? context.l.driverOnline
                    : context.l.driverOffline),
            subtitle: Text(online
                ? context.l.driverOnlineSubtitle
                : context.l.driverOfflineSubtitle),
            onChanged: status.connecting
                ? null
                : (want) async {
                    final controller = ref.read(presenceProvider.notifier);
                    try {
                      if (want) {
                        await controller.goOnline();
                      } else {
                        await controller.goOffline();
                      }
                    } on PresenceException catch (e) {
                      if (context.mounted) {
                        showSnack(context, _describe(context, e.failure),
                            error: true);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showSnack(context, describeError(e), error: true);
                      }
                    }
                  },
          ),
          // Stays until the next attempt. A snack is gone in four seconds, and
          // "it went back off" with nothing else was all a driver could report
          // the first time this failed.
          if (issue != null && !online)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: Text(
                context.l.presenceIssue(issue.write, issue.code),
                style: context.text.bodySmall
                    ?.copyWith(color: context.scheme.error),
              ),
            ),
        ],
      ),
    );
  }

  static String _describe(BuildContext context, PresenceFailure f) =>
      switch (f) {
        PresenceFailure.locationOff => context.l.presenceLocationOff,
        PresenceFailure.permissionDenied => context.l.presenceLocationDenied,
        PresenceFailure.permissionBlocked => context.l.presenceLocationBlocked,
        PresenceFailure.noFix => context.l.presenceNoFix,
        PresenceFailure.refused => context.l.presenceRefused,
        PresenceFailure.writeFailed => context.l.presenceWriteFailed,
      };
}

class _ActiveRideSection extends ConsumerWidget {
  const _ActiveRideSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(myActiveRidesProvider);

    return ridesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text(describeError(e)),
      data: (rides) {
        if (rides.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Said once, above the cards, rather than on each: a driver
            // carrying two passengers needs to know it at a glance, and the
            // drop-off order is the order they are listed in.
            if (rides.length > 1) ...[
              Row(
                children: [
                  Icon(Icons.groups_outlined,
                      size: AppSpacing.iconSm, color: context.scheme.primary),
                  const Gap(AppSpacing.sm),
                  Text(context.l.driverSharedRides('${rides.length}'),
                      style: context.text.titleSmall),
                ],
              ),
              const Gap(AppSpacing.md),
            ],
            for (final ride in rides) ...[
              _ActiveRideCard(ride: ride),
              if (ride != rides.last) const Gap(AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

/// One ride a driver is carrying, with the controls for that ride alone.
class _ActiveRideCard extends ConsumerWidget {
  const _ActiveRideCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(rideActionsProvider);

    return Builder(
      builder: (context) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l.driverCurrentRide,
                    style: Theme.of(context).textTheme.titleMedium),
                const Gap(AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: RideServiceBadge(service: ride.service),
                ),
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
                      tooltip: context.l.driverCallCommuter(ride.commuterName),
                      icon: const Icon(Icons.phone),
                      onPressed: () => _call(context, ride.commuterPhone),
                    ),
                  ],
                ),
                const Gap(AppSpacing.lg),
                if (ride.status == RideStatus.accepted)
                  FilledButton(
                    onPressed: () => _run(context, () => actions.start(ride)),
                    child: Text(context.l.driverStartTrip),
                  )
                else
                  FilledButton(
                    onPressed: () => _run(context, () => actions.complete(ride)),
                    child: Text(context.l.driverCompleteRide),
                  ),
                const Gap(AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => _run(context, () => actions.cancel(ride)),
                  child: Text(context.l.driverCancel),
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
      showSnack(context, context.l.dialerFailed(phone),
          error: true);
    }
  }
}

class _OffersSection extends ConsumerWidget {
  const _OffersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(myOffersProvider);
    final carrying = ref.watch(myActiveRidesProvider).value ?? const <Ride>[];

    return offersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(describeError(e)),
      data: (offers) {
        if (offers.isEmpty) {
          // Nothing to say while a ride is under way: the ride cards above
          // already fill the screen, and "waiting for a ride" under them
          // would read as though the current one had ended.
          if (carrying.isNotEmpty) return const SizedBox.shrink();
          final online = ref.watch(presenceProvider);
          return AppEmptyState(
            icon: online
                ? Icons.notifications_none_outlined
                : Icons.wifi_off_outlined,
            title: online
                ? context.l.driverWaiting
                : context.l.driverYouAreOffline,
            // The empty state names the reason, so a driver who forgot to go
            // online is not left wondering why nothing arrives.
            body: online
                ? context.l.driverWaitingBody
                : context.l.driverOfflineBody,
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
                      Text(
                          carrying.isEmpty
                              ? context.l.driverNewOffer
                              : context.l.driverSharedOffer,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (carrying.isNotEmpty) ...[
                        const Gap(AppSpacing.xs),
                        // Why this arrived mid-ride, in the driver's terms:
                        // the server only offers a share that stays on the
                        // way, and the driver decides whether it really does.
                        Text(context.l.driverSharedOfferBody,
                            style: context.text.bodySmall),
                      ],
                      const Gap(AppSpacing.sm),
                      // Before the route: whether the driver may pick anyone
                      // else up decides the accept, not only the drive.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RideServiceBadge(service: ride.service),
                      ),
                      const Gap(AppSpacing.md),
                      Text(context.l.driverRoute(
                          ride.pickup.label, ride.dropoff.label)),
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
                      _PickupDistance(ride: ride),
                      const Gap(AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _run(
                                  context, () => actions.decline(ride)),
                              child: Text(context.l.driverDecline),
                            ),
                          ),
                          const Gap(AppSpacing.md),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  _run(context, () => actions.accept(ride)),
                              child: Text(context.l.driverAccept),
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


/// How far the pickup is from where the driver is standing.
///
/// The offer names a place, and "Plaza" is either around the corner or across
/// town depending on where the shift started — so a driver weighing fifteen
/// seconds of offer had to guess at the one number that decides it. Straight
/// line, like the search that picked them: a sense of scale, not a route.
class _PickupDistance extends ConsumerWidget {
  const _PickupDistance({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(driverPositionProvider);
    final pickup = ride.pickup.geopoint;
    // No fix yet, or a ride booked by the old web build, which wrote labels
    // without coordinates. The rest of the offer still reads fine.
    if (me == null || pickup == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.near_me_outlined,
              size: AppSpacing.iconSm, color: context.scheme.onSurfaceVariant),
          const Gap(AppSpacing.sm),
          Text(
            context.l.driverPickupAway(
                distanceKmBetween(me, pickup).toStringAsFixed(1)),
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
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
