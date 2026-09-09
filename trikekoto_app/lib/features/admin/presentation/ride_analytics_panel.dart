import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/ui/app_theme.dart';
import '../data/ride_analytics.dart';
import '../../../core/ui/locale_controller.dart';

/// The selected window. A Notifier rather than a plain value so changing it
/// re-runs the query through the normal provider graph.
class AnalyticsWindowController extends Notifier<AnalyticsWindow> {
  @override
  AnalyticsWindow build() => AnalyticsWindow.today;

  void select(AnalyticsWindow window) => state = window;
}

final analyticsWindowProvider =
    NotifierProvider<AnalyticsWindowController, AnalyticsWindow>(
        AnalyticsWindowController.new);

/// Clock seam, so tests can pin "now" instead of depending on the day they run.
final analyticsClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

const _readCap = 2000;

final rideAnalyticsProvider = FutureProvider<RideAnalytics>((ref) async {
  final window = ref.watch(analyticsWindowProvider);
  final now = ref.watch(analyticsClockProvider)();
  final since = window.since(now);

  final snap = await ref
      .watch(refsProvider)
      .ridesSince(since, limit: _readCap)
      .get();

  return RideAnalytics.from(
    snap.docs.map((d) => d.data()).toList(),
    window: window,
    now: now,
    truncated: snap.docs.length >= _readCap,
  );
});

/// Operational analytics for the window the admin picks.
///
/// Deliberately not a live stream. A snapshot listener over the same window
/// would bill a read for every ride update — including the GPS mirror during
/// a trip — turning an idle open tab into the most expensive thing in the
/// system. It refreshes when asked.
class RideAnalyticsPanel extends ConsumerWidget {
  const RideAnalyticsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(analyticsWindowProvider);
    final analytics = ref.watch(rideAnalyticsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child:
                      Text(context.l.anRides, style: context.text.titleMedium),
                ),
                IconButton(
                  tooltip: context.l.anRefresh,
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.invalidate(rideAnalyticsProvider),
                ),
              ],
            ),
            const Gap(AppSpacing.sm),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<AnalyticsWindow>(
                segments: [
                  for (final w in AnalyticsWindow.values)
                    ButtonSegment(value: w, label: Text(w.label)),
                ],
                selected: {window},
                showSelectedIcon: false,
                onSelectionChanged: (s) => ref
                    .read(analyticsWindowProvider.notifier)
                    .select(s.first),
              ),
            ),
            const Gap(AppSpacing.lg),

            analytics.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => Text(describeError(e)),
              data: (a) => _Body(analytics: a),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.analytics});

  final RideAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final a = analytics;

    if (a.byStatus.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Text(
          context.l.anNoRides,
          style: context.text.bodyMedium
              ?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (a.truncated) ...[
          _Notice(
            icon: Icons.filter_alt_outlined,
            text: context.l.anTruncated('$_readCap'),
          ),
          const Gap(AppSpacing.lg),
        ],

        Wrap(
          spacing: AppSpacing.xxl,
          runSpacing: AppSpacing.lg,
          children: [
            _Stat(
              value: '${a.completed}',
              label: context.l.anCompleted,
              tone: context.semantic.success,
            ),
            _Stat(
              value: a.completionRate == null
                  ? '—'
                  : '${(a.completionRate! * 100).round()}%',
              label: context.l.anCompletionRate,
            ),
            _Stat(
              value: '${a.cancelled}',
              label: context.l.anCancelled,
            ),
            _Stat(
              value: '${a.expired}',
              label: context.l.anNoDriverFound,
              // The one failure mode the operator can actually act on, by
              // recruiting drivers or widening the search radius.
              tone: a.expired > 0 ? context.scheme.error : null,
            ),
            _Stat(
              value: a.averageRating == null
                  ? '—'
                  : a.averageRating!.toStringAsFixed(2),
              label: context.l.anAvgRating,
            ),
          ],
        ),
        const Gap(AppSpacing.xl),

        if (a.unrated > 0) ...[
          const Gap(AppSpacing.md),
          Text(
            context.l.anUnrated('${a.unrated}', '${a.completed}'),
            style: context.text.bodySmall
                ?.copyWith(color: context.scheme.onSurfaceVariant),
          ),
        ],

        // A single bar carries no information, so the chart only appears once
        // there is a shape to see.
        if (a.window.days > 1) ...[
          const Gap(AppSpacing.xl),
          Text(context.l.anDaily, style: context.text.titleSmall),
          const Gap(AppSpacing.md),
          _DailyChart(points: a.daily, peak: a.busiestDayTotal),
        ],

        if (a.drivers.isNotEmpty) ...[
          const Gap(AppSpacing.xl),
          Text(context.l.anByDriver, style: context.text.titleSmall),
          const Gap(AppSpacing.sm),
          _DriverTable(rows: a.drivers),
        ],
      ],
    );
  }
}

/// Stacked daily bars: completed below, cancelled above.
class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.points, required this.peak});

  final List<DailyPoint> points;
  final int peak;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final success = context.semantic.success;
    final muted = context.scheme.outlineVariant;

    return Semantics(
      // The bars are decorative to a screen reader; the figure it needs is
      // the one a sighted reader takes from their shape.
      label: context.l.anChartLabel('$peak', '${points.length}'),
      excludeSemantics: true,
      child: SizedBox(
        height: 108,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final p in points)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (p.total > 0)
                        Text(
                          '${p.total}',
                          style: context.text.labelSmall,
                          maxLines: 1,
                        ),
                      const Gap(2),
                      // A zero day still draws a hairline, so the axis reads
                      // as a continuous run of days rather than a gap.
                      _Bar(
                        // Guard against a zero peak: an all-empty window
                        // would divide by nothing.
                        fraction: peak == 0 ? 0 : p.total / peak,
                        completedFraction:
                            p.total == 0 ? 0 : p.completed / p.total,
                        fill: success,
                        rest: muted,
                      ),
                      const Gap(4),
                      Text(
                        '${p.day.day}',
                        style: context.text.labelSmall
                            ?.copyWith(color: context.scheme.onSurfaceVariant),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.completedFraction,
    required this.fill,
    required this.rest,
  });

  final double fraction;
  final double completedFraction;
  final Color fill;
  final Color rest;

  @override
  Widget build(BuildContext context) {
    const maxHeight = 64.0;
    final height = (fraction * maxHeight).clamp(1.0, maxHeight);

    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Column(
          children: [
            Expanded(
              flex: (((1 - completedFraction) * 100).round()).clamp(0, 100),
              child: ColoredBox(color: rest, child: const SizedBox.expand()),
            ),
            Expanded(
              flex: ((completedFraction * 100).round()).clamp(0, 100),
              child: ColoredBox(color: fill, child: const SizedBox.expand()),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverTable extends StatelessWidget {
  const _DriverTable({required this.rows});

  final List<DriverPerformance> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: AppSpacing.xl,
        headingRowHeight: 36,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 48,
        columns: [
          DataColumn(label: Text(context.l.anColDriver)),
          DataColumn(label: Text(context.l.anColDone), numeric: true),
          DataColumn(label: Text(context.l.anColCancelled), numeric: true),
          DataColumn(label: Text(context.l.anColRating), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(r.email, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(_Num('${r.completed}')),
              DataCell(_Num(
                '${r.cancelled}',
                tone: r.cancelled > 0 ? context.scheme.error : null,
              )),
              DataCell(_Num(
                r.averageRating == null
                    ? '—'
                    : r.averageRating!.toStringAsFixed(2),
              )),
            ]),
        ],
      ),
    );
  }
}

class _Num extends StatelessWidget {
  const _Num(this.text, {this.tone});
  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: context.text.bodyMedium?.copyWith(
          color: tone,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.tone});

  final String value;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: context.text.headlineSmall?.copyWith(
            color: tone,
            // Digits line up across the row.
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: context.text.bodySmall
              ?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.semantic.warningContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSpacing.iconSm, color: context.semantic.warning),
          const Gap(AppSpacing.sm),
          Expanded(child: Text(text, style: context.text.bodySmall)),
        ],
      ),
    );
  }
}
