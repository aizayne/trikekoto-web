import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/firestore/collection_paths.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/locale_controller.dart';
import '../application/ride_history.dart';
import '../data/ride.dart';
import 'ride_service_badge.dart';

/// Past rides, for a commuter, a driver or an admin.
///
/// One screen for all three, because what differs is the slice of rides and
/// what each row says about the other party — not how a ride is read.
///
/// What each audience is shown about the other party is deliberate:
/// - a **commuter** sees the driver's first name and plate, as on the ride;
/// - a **driver** sees the commuter's name only. The phone number was there
///   so the driver could find them; once the ride is over it has no purpose
///   on the driver's screen;
/// - an **admin** sees both parties in full, as the TODA record requires.
class RideHistoryScreen extends ConsumerWidget {
  const RideHistoryScreen({super.key, required this.audience});

  final HistoryAudience audience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(rideHistoryProvider(audience));
    final limit = ref.watch(historyLimitProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l.historyTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                if (audience == HistoryAudience.admin) const _StatusFilter(),
                Expanded(
                  child: history.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: AppEmptyState(
                          icon: Icons.cloud_off,
                          title: context.l.historyFailed,
                          body: describeError(e),
                        ),
                      ),
                    ),
                    data: (rides) {
                      if (rides.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: AppEmptyState(
                              icon: Icons.history,
                              title: context.l.historyEmptyTitle,
                              body: audience == HistoryAudience.admin
                                  ? context.l.historyEmptyBodyAdmin
                                  : context.l.historyEmptyBody,
                            ),
                          ),
                        );
                      }
                      // A full page may mean there is more; a short one
                      // cannot. Offering "more" on a short page would promise
                      // rides that do not exist.
                      final more = rides.length >= limit;
                      return ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: rides.length + (more ? 1 : 0),
                        separatorBuilder: (_, _) => const Gap(AppSpacing.md),
                        itemBuilder: (context, i) => i < rides.length
                            ? _HistoryTile(ride: rides[i], audience: audience)
                            : Center(
                                child: OutlinedButton(
                                  onPressed: () => ref
                                      .read(historyLimitProvider.notifier)
                                      .more(),
                                  child: Text(context.l.historyShowMore),
                                ),
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The admin's status filter: every ride, or one outcome.
class _StatusFilter extends ConsumerWidget {
  const _StatusFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(adminHistoryFilterProvider);
    final options = <(RideStatus?, String)>[
      (null, context.l.historyFilterAll),
      (RideStatus.completed, context.l.historyCompleted),
      (RideStatus.cancelled, context.l.historyCancelled),
      (RideStatus.expired, context.l.historyNoDriver),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
      child: Row(
        children: [
          for (final (status, label) in options) ...[
            ChoiceChip(
              label: Text(label),
              selected: selected == status,
              onSelected: (_) {
                ref.read(adminHistoryFilterProvider.notifier).set(status);
                // A new filter starts from the first page again.
                ref.invalidate(historyLimitProvider);
              },
            ),
            const Gap(AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.ride, required this.audience});

  final Ride ride;
  final HistoryAudience audience;

  @override
  Widget build(BuildContext context) {
    final lines = _partyLines(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _when(context),
                    style: context.text.bodySmall
                        ?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                ),
                _StatusLabel(ride: ride),
              ],
            ),
            const Gap(AppSpacing.sm),
            Text(
              context.l.driverRoute(ride.pickup.label, ride.dropoff.label),
              style: context.text.titleSmall,
            ),
            const Gap(AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RideServiceBadge(service: ride.service),
                if (ride.rating != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star,
                          size: AppSpacing.iconSm,
                          color: context.scheme.primary),
                      const Gap(AppSpacing.xs),
                      Text('${ride.rating}', style: context.text.labelMedium),
                    ],
                  ),
              ],
            ),
            for (final line in lines) ...[
              const Gap(AppSpacing.xs),
              Text(line, style: context.text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  /// Date and time in the app's language. A ride without a timestamp — one
  /// still being written — shows a dash rather than a wrong date.
  String _when(BuildContext context) {
    final at = ride.createdAt?.toDate();
    if (at == null) return '—';
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).add_jm().format(at);
  }

  List<String> _partyLines(BuildContext context) {
    final driver = ride.driverSnapshot;
    switch (audience) {
      case HistoryAudience.commuter:
        return [
          if (driver != null)
            context.l.historyDriverLine(driver.firstName, driver.plateNumber),
        ];
      case HistoryAudience.driver:
        return [context.l.historyCommuterLine(ride.commuterName)];
      case HistoryAudience.admin:
        return [
          context.l.historyCommuterContact(ride.commuterName, ride.commuterPhone),
          if (driver != null)
            context.l.historyDriverLine(driver.firstName, driver.plateNumber)
          else if (ride.assignedDriver != null)
            context.l.historyDriverEmailLine(ride.assignedDriver!),
        ];
    }
  }
}

/// How the ride ended, in words and colour — never colour alone.
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (ride.status) {
      RideStatus.completed => (
          context.l.historyCompleted,
          context.semantic.success
        ),
      RideStatus.cancelled => (
          switch (ride.cancelledBy) {
            CancelledBy.commuter => context.l.historyCancelledByCommuter,
            CancelledBy.driver => context.l.historyCancelledByDriver,
            _ => context.l.historyCancelled,
          },
          context.scheme.error
        ),
      RideStatus.expired => (
          context.l.historyNoDriver,
          context.scheme.onSurfaceVariant
        ),
      _ => (context.l.historyInProgress, context.scheme.primary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        label,
        style: context.text.labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
