import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/features/drivers/application/driver_controllers.dart';
import 'package:trikekoto_app/features/drivers/data/active_driver.dart';

/// The check-in an online driver's app sends while parked.
///
/// Dispatch treats a driver who stops checking in as gone, but only when the
/// presence document carries the promise. These pin that the promise is sent
/// on every ping, and that it matches how often the app actually checks in —
/// a promise of two minutes from an app that checks in every five would get
/// every parked driver skipped.
void main() {
  Map<String, dynamic> ping() => ActiveDriver.presencePayload(
        email: 'juan@toda.ph',
        isOnline: true,
        availability: 'idle',
        latitude: 14.97,
        longitude: 120.15,
        geohash: 'wdw',
      );

  test('every presence write carries the check-in promise', () {
    expect(ping()['heartbeatSeconds'], ActiveDriver.presenceHeartbeatSeconds);
  });

  test('the promise matches how often the app checks in', () {
    expect(presenceHeartbeat.inSeconds, ActiveDriver.presenceHeartbeatSeconds);
  });

  test('check-ins are frequent enough to notice a closed app within minutes',
      () {
    // Dispatch waits two and a half missed check-ins; at two minutes that is
    // five minutes of offers to a phone nobody is holding, at most.
    expect(presenceHeartbeat, lessThanOrEqualTo(const Duration(minutes: 2)));
  });
}
