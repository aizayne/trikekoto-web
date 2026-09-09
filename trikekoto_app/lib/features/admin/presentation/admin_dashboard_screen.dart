import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../identity/application/id_verification_service.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/firestore/collection_paths.dart';
import '../../../core/providers.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/theme_controller.dart';
import '../../drivers/data/driver.dart';
import 'ride_analytics_panel.dart';
import 'verify_email_screen.dart';
import '../../../core/ui/locale_controller.dart';

/// All drivers, so the panel can show the verification queue and the roster in
/// one stream. `list` on `drivers` is admin-only, so this query simply fails
/// for anyone else.
final allDriversProvider = StreamProvider<List<Driver>>((ref) {
  return ref
      .watch(refsProvider)
      .drivers
      .snapshots()
      .map((s) => s.docs.map((d) => d.data()).toList());
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Gate before any query runs. The router sends an admin here on the
    // strength of the `admins/{email}` document alone, but the rules also
    // require a confirmed address — so without this the panel would load and
    // every read below would fail with a permission error explaining nothing.
    if (ref.watch(sessionProvider).isUnverifiedAdmin) {
      return const VerifyEmailScreen();
    }

    final driversAsync = ref.watch(allDriversProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l.adminTitle),
        actions: [
          const LanguageToggleButton(),
          const ThemeToggleButton(),
          IconButton(
            tooltip: context.l.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
        ],
      ),
      body: driversAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(describeError(e))),
        data: (drivers) {
          final pending =
              drivers.where((d) => d.status == DriverStatus.pending).toList();
          final rest =
              drivers.where((d) => d.status != DriverStatus.pending).toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              const RideAnalyticsPanel(),
              const Gap(AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _AdminLink(
                      icon: Icons.forum_outlined,
                      label: context.l.adminFeedback,
                      badge: ref.watch(openFeedbackCountProvider).value,
                      onTap: () => context.go('/admin/feedback'),
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: _AdminLink(
                      icon: Icons.tune,
                      label: context.l.adminDispatch,
                      onTap: () => context.go('/admin/config'),
                    ),
                  ),
                ],
              ),
              const Gap(AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _AdminLink(
                      icon: Icons.badge_outlined,
                      label: context.l.adminIdReview,
                      badge: ref.watch(pendingIdCountProvider),
                      onTap: () => context.go('/admin/ids'),
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  const Expanded(child: SizedBox()),
                ],
              ),
              const Gap(AppSpacing.xxl),

              // The verification queue is the admin's actual job, so it
              // leads — and carries a count badge when it needs attention.
              Row(
                children: [
                  Text(context.l.adminPendingVerification,
                      style: context.text.titleMedium),
                  const Gap(AppSpacing.sm),
                  if (pending.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.semantic.warningContainer,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Text(
                        '${pending.length}',
                        style: context.text.bodySmall?.copyWith(
                          color: context.semantic.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const Gap(AppSpacing.md),
              if (pending.isEmpty)
                AppEmptyState(
                  icon: Icons.inbox_outlined,
                  title: context.l.adminNothingWaitingTitle,
                  body: context.l.adminNothingWaitingBody,
                ),
              for (final d in pending) _DriverTile(driver: d),

              const Gap(AppSpacing.xxl),
              Text(context.l.adminAllDrivers('${rest.length}'),
                  style: context.text.titleMedium),
              const Gap(AppSpacing.md),
              if (rest.isEmpty)
                AppEmptyState(
                  icon: Icons.groups_outlined,
                  title: context.l.adminNoDriversTitle,
                  body: context.l.adminNoDriversBody,
                ),
              for (final d in rest) _DriverTile(driver: d),
            ],
          );
        },
      ),
    );
  }
}

/// How many reports are waiting, for the badge on the dashboard.
/// How many IDs are waiting. Shown as a badge, absent at zero — a badge
/// reading "0" trains people to ignore badges.
final pendingIdCountProvider = Provider<int?>((ref) {
  // Derived from the queue that is already streaming, rather than a second
  // listener on the same collection — one subscription, one read cost.
  return ref.watch(pendingIdSubmissionsProvider).value?.length;
});

final openFeedbackCountProvider = StreamProvider<int>((ref) {
  return ref
      .watch(refsProvider)
      .openFeedback
      .snapshots()
      .map((s) => s.docs.length);
});

/// A tile linking to an admin sub-screen, with an optional count badge.
class _AdminLink extends StatelessWidget {
  const _AdminLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final count = badge ?? 0;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(icon, size: AppSpacing.iconMd,
                  color: context.scheme.onSurfaceVariant),
              const Gap(AppSpacing.md),
              Expanded(
                child: Text(label,
                    style: context.text.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.semantic.warningContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    '$count',
                    style: context.text.bodySmall?.copyWith(
                      color: context.semantic.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverTile extends ConsumerWidget {
  const _DriverTile({required this.driver});
  final Driver driver;

  Future<void> _setStatus(
      BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref
          .read(firestoreProvider)
          .collection(FsCollections.drivers)
          .doc(driver.email)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        showSnack(context, context.l.adminDriverMarked(status));
      }
    } catch (e) {
      if (context.mounted) showSnack(context, describeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = context.semantic;
    final (statusColor, statusBg) = switch (driver.status) {
      DriverStatus.approved => (semantic.success, semantic.successContainer),
      DriverStatus.suspended => (semantic.danger, semantic.dangerContainer),
      DriverStatus.rejected => (semantic.danger, semantic.dangerContainer),
      _ => (semantic.warning, semantic.warningContainer),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.fullName, style: context.text.titleSmall),
                      const Gap(AppSpacing.xs),
                      Text(
                        context.l.adminPlatePhone(
                            driver.plateNumber, driver.phone),
                        style: context.text.bodySmall,
                      ),
                      Text(
                        context.l.adminEmailChapter(
                            driver.email, driver.todaChapter),
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Gap(AppSpacing.md),
                // Status is a labelled pill, not colour alone.
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    driver.status,
                    style: context.text.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (driver.ratingCount > 0) ...[
              const Gap(AppSpacing.sm),
              Text(
                context.l.adminRatingFrom(
                    driver.ratingAverage!.toStringAsFixed(1),
                    '${driver.ratingCount}'),
                style: context.text.bodySmall,
              ),
            ],
            const Gap(AppSpacing.md),
            const Divider(height: 1),
            const Gap(AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (driver.status != DriverStatus.approved)
                  TextButton.icon(
                    onPressed: () =>
                        _setStatus(context, ref, DriverStatus.approved),
                    icon: const Icon(Icons.check, size: AppSpacing.iconSm),
                    label: Text(context.l.adminApprove),
                  ),
                if (driver.status == DriverStatus.approved)
                  TextButton.icon(
                    onPressed: () =>
                        _setStatus(context, ref, DriverStatus.suspended),
                    icon: const Icon(Icons.block, size: AppSpacing.iconSm),
                    label: Text(context.l.adminSuspend),
                    style: TextButton.styleFrom(
                        foregroundColor: semantic.danger),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
