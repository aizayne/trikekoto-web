import '../../../core/firestore/collection_paths.dart';
import '../../rides/data/ride.dart';

/// Analytics over a window of rides.
///
/// Everything here is a pure function of a ride list. Firestore does not
/// aggregate beyond counting, so the alternative was denormalised counter
/// documents kept honest by a Cloud Function — which cannot be deployed on
/// the free plan, and which would have to be backfilled and then trusted.
/// Reading the window and computing in Dart is worse asymptotically and
/// better in every way that matters at this scale: no extra writes on the
/// ride path, no drift, and the numbers can be recomputed differently
/// tomorrow without a migration.
///
/// The cost is one document read per ride in the window. That is why the
/// window is a deliberate choice in the UI rather than "all time".

/// How far back to look. Ordered cheapest first — the UI defaults to [today]
/// because the panel is opened far more often than it is studied.
enum AnalyticsWindow {
  today('Today', 1),
  week('7 days', 7),
  month('30 days', 30);

  const AnalyticsWindow(this.label, this.days);

  final String label;
  final int days;

  /// Midnight local time, [days] - 1 days ago. Local rather than UTC because
  /// "today" means the operator's day; in PHT a UTC cutoff would start the
  /// day at 8am.
  DateTime since(DateTime now) {
    final midnight = DateTime(now.year, now.month, now.day);
    return midnight.subtract(Duration(days: days - 1));
  }
}

/// One day's bar in the time series.
class DailyPoint {
  const DailyPoint({
    required this.day,
    required this.completed,
    required this.cancelled,
  });

  final DateTime day;
  final int completed;
  final int cancelled;

  int get total => completed + cancelled;
}

/// One driver's contribution over the window.
class DriverPerformance {
  const DriverPerformance({
    required this.email,
    required this.completed,
    required this.cancelled,
    required this.ratingSum,
    required this.ratingCount,
  });

  final String email;
  final int completed;
  final int cancelled;
  final int ratingSum;
  final int ratingCount;

  double? get averageRating =>
      ratingCount == 0 ? null : ratingSum / ratingCount;

  /// Rides that reached a conclusion, so a driver mid-trip is not counted as
  /// having failed to finish.
  int get concluded => completed + cancelled;
}

class RideAnalytics {
  const RideAnalytics({
    required this.window,
    required this.since,
    required this.byStatus,
    required this.daily,
    required this.drivers,
    required this.ratingSum,
    required this.ratingCount,
    required this.truncated,
  });

  final AnalyticsWindow window;
  final DateTime since;

  final Map<RideStatus, int> byStatus;
  final List<DailyPoint> daily;

  /// Highest contribution first.
  final List<DriverPerformance> drivers;

  final int ratingSum;
  final int ratingCount;

  /// True when the query hit its read cap, so these numbers describe only part
  /// of the window. Surfaced in the UI — a silently partial total is worse
  /// than no total.
  final bool truncated;

  int count(RideStatus status) => byStatus[status] ?? 0;

  int get completed => count(RideStatus.completed);
  int get cancelled => count(RideStatus.cancelled);
  int get expired => count(RideStatus.expired);

  /// Rides still in flight are excluded from both sides. Counting them as
  /// failures makes every mid-afternoon reading look like a bad day.
  int get concluded => completed + cancelled + expired;

  double? get completionRate =>
      concluded == 0 ? null : completed / concluded;

  /// Offers no driver ever took. This is the dispatch algorithm failing to
  /// find anyone within range before the offer chain ran out — a supply
  /// problem, not a driver problem, and the one number worth watching daily
  /// during a pilot.
  double? get expiryRate => concluded == 0 ? null : expired / concluded;

  double? get averageRating =>
      ratingCount == 0 ? null : ratingSum / ratingCount;

  /// How many completed rides were never rated. A low rating count next to a
  /// high completion count means the rating prompt is being dismissed, which
  /// makes the driver averages unreliable rather than merely sparse.
  int get unrated => (completed - ratingCount).clamp(0, completed);

  int get busiestDayTotal =>
      daily.isEmpty ? 0 : daily.map((d) => d.total).reduce((a, b) => a > b ? a : b);

  static RideAnalytics from(
    List<Ride> rides, {
    required AnalyticsWindow window,
    required DateTime now,
    bool truncated = false,
  }) {
    final since = window.since(now);

    final byStatus = <RideStatus, int>{};
    final buckets = <DateTime, _DayAccumulator>{};
    final perDriver = <String, _DriverAccumulator>{};

    var ratingSum = 0;
    var ratingCount = 0;

    // Pre-seed every day in the window so a day with no rides still draws a
    // gap in the chart rather than being silently skipped, which would make
    // an outage look like a quiet day.
    for (var i = 0; i < window.days; i++) {
      final day = DateTime(since.year, since.month, since.day + i);
      buckets[day] = _DayAccumulator();
    }

    for (final ride in rides) {
      final createdAt = ride.createdAt?.toDate().toLocal();
      if (createdAt == null || createdAt.isBefore(since)) continue;

      byStatus[ride.status] = (byStatus[ride.status] ?? 0) + 1;

      final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
      final bucket = buckets.putIfAbsent(day, _DayAccumulator.new);

      final isCompleted = ride.status == RideStatus.completed;
      final isCancelled = ride.status == RideStatus.cancelled;

      if (isCompleted) {
        bucket.completed++;
      } else if (isCancelled) {
        bucket.cancelled++;
      }

      if (ride.rating != null) {
        ratingSum += ride.rating!;
        ratingCount++;
      }

      // Attribute to whoever actually drove it. An expired offer has no
      // assigned driver and belongs to nobody.
      final email = ride.assignedDriver;
      if (email != null && email.isNotEmpty) {
        final acc = perDriver.putIfAbsent(email, _DriverAccumulator.new);
        if (isCompleted) {
          acc.completed++;
        } else if (isCancelled) {
          acc.cancelled++;
        }
        if (ride.rating != null) {
          acc.ratingSum += ride.rating!;
          acc.ratingCount++;
        }
      }
    }

    final daily = buckets.entries
        .map((e) => DailyPoint(
              day: e.key,
              completed: e.value.completed,
              cancelled: e.value.cancelled,
            ))
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    final drivers = perDriver.entries
        .map((e) => DriverPerformance(
              email: e.key,
              completed: e.value.completed,
              cancelled: e.value.cancelled,
              ratingSum: e.value.ratingSum,
              ratingCount: e.value.ratingCount,
            ))
        .toList()
      // Completed rides first, then cancellations as the tie-break: between
      // two drivers who finished the same number, the one who called off
      // fewer is the one a dispatcher wants to see higher.
      ..sort((a, b) {
        final byCompleted = b.completed.compareTo(a.completed);
        return byCompleted != 0 ? byCompleted : a.cancelled.compareTo(b.cancelled);
      });

    return RideAnalytics(
      window: window,
      since: since,
      byStatus: byStatus,
      daily: daily,
      drivers: drivers,
      ratingSum: ratingSum,
      ratingCount: ratingCount,
      truncated: truncated,
    );
  }
}

class _DayAccumulator {
  int completed = 0;
  int cancelled = 0;
}

class _DriverAccumulator {
  int completed = 0;
  int cancelled = 0;
  int ratingSum = 0;
  int ratingCount = 0;
}
