import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/firestore/collection_paths.dart';
import 'package:trikekoto_app/features/admin/data/ride_analytics.dart';
import 'package:trikekoto_app/features/rides/data/ride.dart';

/// Tests for the admin analytics computation.
///
/// The numbers here end up in front of someone deciding whether to recruit
/// more drivers, so the ways they can be quietly wrong matter more than the
/// happy path: a completion rate dragged down by trips still in progress, or
/// a driver credited for a ride they never got.

// A fixed "now" so these tests do not depend on the day they run — or the
// hour, which is what breaks a naive version of this suite at midnight.
final _now = DateTime(2026, 8, 26, 14, 30);

Ride _ride({
  required RideStatus status,
  DateTime? createdAt,
  String? driver,
  int? rating,
}) =>
    Ride(
      id: 'r${identityHashCode(status)}${createdAt?.millisecondsSinceEpoch}',
      commuterUid: 'commuter-uid',
      commuterName: 'Test Commuter',
      commuterPhone: '09171234567',
      dispatch: const RideDispatch(),
      status: status,
      pickup: const RidePlace(label: 'A'),
      dropoff: const RidePlace(label: 'B'),
      assignedDriver: driver,
      rating: rating,
      createdAt: Timestamp.fromDate(createdAt ?? _now),
    );

RideAnalytics _analyse(
  List<Ride> rides, {
  AnalyticsWindow window = AnalyticsWindow.week,
  bool truncated = false,
}) =>
    RideAnalytics.from(rides,
        window: window, now: _now, truncated: truncated);

void main() {
  group('window boundaries', () {
    test('today starts at local midnight, not 24 hours ago', () {
      final since = AnalyticsWindow.today.since(_now);
      expect(since, DateTime(2026, 8, 26));
    });

    test('7 days includes today, so it spans six days back', () {
      expect(AnalyticsWindow.week.since(_now), DateTime(2026, 8, 20));
    });

    test('a ride from before the window is excluded', () {
      final a = _analyse([
        _ride(status: RideStatus.completed, createdAt: DateTime(2026, 8, 19)),
        _ride(status: RideStatus.completed, createdAt: DateTime(2026, 8, 21)),
      ]);
      expect(a.completed, 1);
    });
  });


  group('rates', () {
    test('rides still in flight are excluded from the completion rate', () {
      final a = _analyse([
        _ride(status: RideStatus.completed),
        _ride(status: RideStatus.completed),
        _ride(status: RideStatus.cancelled),
        // Neither of these has concluded. Counting them as failures makes
        // every mid-afternoon reading look like a bad day.
        _ride(status: RideStatus.searching),
        _ride(status: RideStatus.accepted),
        _ride(status: RideStatus.inTransit),
      ]);

      expect(a.concluded, 3);
      expect(a.completionRate, closeTo(2 / 3, 1e-9));
    });

    test('expiries count against completion and surface separately', () {
      final a = _analyse([
        _ride(status: RideStatus.completed),
        _ride(status: RideStatus.expired),
      ]);

      expect(a.completionRate, 0.5);
      expect(a.expiryRate, 0.5);
    });

    test('an empty window yields null rates rather than zero', () {
      final a = _analyse([]);
      // Zero would render as "0%", which reads as total failure rather than
      // no data.
      expect(a.completionRate, isNull);
      expect(a.averageRating, isNull);
    });
  });

  group('ratings', () {
    test('averages across every rated ride', () {
      final a = _analyse([
        _ride(status: RideStatus.completed, rating: 5),
        _ride(status: RideStatus.completed, rating: 4),
        _ride(status: RideStatus.completed, rating: 3),
      ]);
      expect(a.averageRating, 4);
      expect(a.unrated, 0);
    });

    test('counts completed rides that were never rated', () {
      final a = _analyse([
        _ride(status: RideStatus.completed, rating: 5),
        _ride(status: RideStatus.completed),
        _ride(status: RideStatus.completed),
      ]);
      // A high completion count next to a low rating count means the prompt
      // is being dismissed, which makes the driver averages unreliable.
      expect(a.unrated, 2);
    });

    test('never reports negative unrated rides', () {
      // Defensive: a rated cancellation would otherwise push this below zero.
      final a = _analyse([
        _ride(status: RideStatus.cancelled, rating: 1),
        _ride(status: RideStatus.completed, rating: 5),
      ]);
      expect(a.unrated, 0);
    });
  });

  group('daily series', () {
    test('seeds every day in the window, including empty ones', () {
      final a = _analyse([
        _ride(status: RideStatus.completed, createdAt: DateTime(2026, 8, 26)),
      ]);

      // An outage should read as a gap, not vanish from the chart.
      expect(a.daily, hasLength(7));
      expect(a.daily.first.day, DateTime(2026, 8, 20));
      expect(a.daily.first.total, 0);
      expect(a.daily.last.total, 1);
    });

    test('days come back in chronological order', () {
      final a = _analyse([
        _ride(status: RideStatus.completed, createdAt: DateTime(2026, 8, 25)),
        _ride(status: RideStatus.completed, createdAt: DateTime(2026, 8, 21)),
      ]);

      final days = a.daily.map((d) => d.day).toList();
      expect(days, orderedEquals(List.of(days)..sort()));
    });

    test('buckets by local calendar day', () {
      final a = _analyse([
        _ride(status: RideStatus.completed, createdAt: DateTime(2026, 8, 24, 23, 59)),
        _ride(status: RideStatus.completed, createdAt: DateTime(2026, 8, 25, 0, 1)),
      ]);

      final d24 = a.daily.firstWhere((d) => d.day.day == 24);
      final d25 = a.daily.firstWhere((d) => d.day.day == 25);
      expect(d24.completed, 1);
      expect(d25.completed, 1);
    });

    test('busiest day drives the chart scale', () {
      final a = _analyse([
        for (var i = 0; i < 4; i++)
          _ride(status: RideStatus.completed, createdAt: DateTime(2026, 8, 22, i)),
        _ride(status: RideStatus.cancelled, createdAt: DateTime(2026, 8, 23)),
      ]);
      expect(a.busiestDayTotal, 4);
    });
  });

  group('per driver', () {
    test('attributes rides and ratings to the assigned driver', () {
      final a = _analyse([
        _ride(status: RideStatus.completed, driver: 'ana@x.ph', rating: 5),
        _ride(status: RideStatus.completed, driver: 'ana@x.ph', rating: 3),
        _ride(status: RideStatus.cancelled, driver: 'ana@x.ph'),
      ]);

      final ana = a.drivers.single;
      expect(ana.email, 'ana@x.ph');
      expect(ana.completed, 2);
      expect(ana.cancelled, 1);
      expect(ana.averageRating, 4);
      expect(ana.concluded, 3);
    });

    test('an expired offer belongs to nobody', () {
      final a = _analyse([
        _ride(status: RideStatus.expired),
        _ride(status: RideStatus.completed, driver: 'ana@x.ph'),
      ]);

      expect(a.drivers, hasLength(1));
      expect(a.expired, 1);
    });

    test('ranks by completed rides', () {
      final a = _analyse([
        _ride(status: RideStatus.completed, driver: 'quiet@x.ph'),
        for (var i = 0; i < 6; i++)
          _ride(
              status: RideStatus.completed,
              driver: 'busy@x.ph',
              createdAt: DateTime(2026, 8, 26, i)),
      ]);

      expect(a.drivers.first.email, 'busy@x.ph');
      expect(a.drivers.last.email, 'quiet@x.ph');
    });

    test('breaks a tie on fewer cancellations', () {
      // Between two drivers who finished the same number, the one who called
      // off fewer is the one a dispatcher wants to see higher.
      final a = _analyse([
        _ride(status: RideStatus.completed, driver: 'a@x.ph'),
        _ride(status: RideStatus.cancelled, driver: 'a@x.ph'),
        _ride(status: RideStatus.completed, driver: 'b@x.ph'),
      ]);
      expect(a.drivers.first.email, 'b@x.ph');
    });

    test('a driver with no rated rides reports no average, not zero', () {
      final a = _analyse([
        _ride(status: RideStatus.completed, driver: 'ana@x.ph'),
      ]);
      expect(a.drivers.single.averageRating, isNull);
    });
  });

  group('bad data', () {
    test('a ride with no createdAt is skipped rather than crashing', () {
      final legacy = Ride(
        id: 'legacy',
        commuterUid: 'commuter-uid',
        commuterName: 'Test Commuter',
        commuterPhone: '09171234567',
        dispatch: const RideDispatch(),
        status: RideStatus.completed,
        pickup: const RidePlace(label: 'A'),
        dropoff: const RidePlace(label: 'B'),
      );

      // The web build wrote rides without a timestamp. One of them must not
      // take down the whole panel, and must not land in an arbitrary bucket.
      final a = _analyse([legacy, _ride(status: RideStatus.completed)]);
      expect(a.completed, 1);
    });

    test('truncation is carried through so the UI can say so', () {
      final a = _analyse([_ride(status: RideStatus.completed)], truncated: true);
      expect(a.truncated, isTrue);
    });
  });
}
