import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/features/rides/data/ride.dart';

/// Regular or special trips.
///
/// Special commits the commuter to a full load's fare, so the property worth
/// protecting is that nothing ever becomes special without being chosen.
void main() {
  const place = RidePlace(label: 'Plaza', geopoint: GeoPoint(14.97, 120.15));

  Map<String, dynamic> booking({RideService? service}) => service == null
      ? RideWrites.create(
          commuterUid: 'u',
          commuterName: 'Maria',
          commuterPhone: '09181234567',
          pickup: place,
          dropoff: place,
        )
      : RideWrites.create(
          commuterUid: 'u',
          commuterName: 'Maria',
          commuterPhone: '09181234567',
          pickup: place,
          dropoff: place,
          service: service,
        );

  test('a booking is regular unless the commuter chooses special', () {
    expect(booking()['serviceType'], 'regular');
  });

  test('a special booking is written as special', () {
    expect(booking(service: RideService.special)['serviceType'], 'special');
  });

  test('a ride booked before the choice existed reads as regular', () {
    expect(Ride.fromMap(const {}, 'r1').service, RideService.regular);
  });

  test('special reads back; an unknown value does not become special', () {
    expect(Ride.fromMap(const {'serviceType': 'special'}, 'r1').service,
        RideService.special);
    expect(Ride.fromMap(const {'serviceType': 'vip'}, 'r1').service,
        RideService.regular);
  });

  test('special is the fare for 5 passengers, regular for 1', () {
    expect(RideService.special.farePassengers, 5);
    expect(RideService.regular.farePassengers, 1);
  });
}
