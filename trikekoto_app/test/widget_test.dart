import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trikekoto_app/core/config/app_config.dart';
import 'package:trikekoto_app/core/fare/fare_calculator.dart';
import 'package:trikekoto_app/core/firestore/collection_paths.dart';
import 'package:trikekoto_app/core/geo/geo_utils.dart';
import 'package:trikekoto_app/features/drivers/data/active_driver.dart';
import 'package:trikekoto_app/features/drivers/data/driver.dart';
import 'package:trikekoto_app/features/feedback/data/feedback_report.dart';
import 'package:trikekoto_app/features/rides/data/ride.dart';

/// Pure-Dart tests for the logic that does not need Firebase.
///
/// The security rules have their own suite in `test_rules/`, which runs
/// against the emulator; these cover the client-side pieces the rules assume
/// are correct.
void main() {
  group('email normalisation', () {
    test('lowercases and trims, matching the rules .lower() comparison', () {
      expect(normalizeEmail('  Juan@TODA.PH '), 'juan@toda.ph');
    });

    test('survives null without throwing', () {
      expect(normalizeEmail(null), '');
    });
  });

  group('distance', () {
    test('is zero for the same point', () {
      expect(haversineKm(14.5995, 120.9842, 14.5995, 120.9842), closeTo(0, 1e-9));
    });

    test('matches a known Manila to Quezon City separation', () {
      // ~11 km as the crow flies.
      final km = haversineKm(14.5995, 120.9842, 14.6760, 121.0437);
      expect(km, closeTo(11.0, 1.5));
    });

    test('orders candidates nearest-first, which is what the sweep relies on',
        () {
      const pickup = GeoPoint(14.5995, 120.9842);
      final far = distanceKmBetween(pickup, const GeoPoint(14.6760, 121.0437));
      final near = distanceKmBetween(pickup, const GeoPoint(14.6010, 120.9850));
      expect(near, lessThan(far));
    });
  });

  group('geohash', () {
    test('produces the requested precision', () {
      expect(encodeGeohash(14.5995, 120.9842).length, 9);
      expect(encodeGeohash(14.5995, 120.9842, precision: 5).length, 5);
    });

    test('nearby points share a prefix, which is what makes range scans work',
        () {
      final a = encodeGeohash(14.5995, 120.9842);
      final b = encodeGeohash(14.5996, 120.9843);
      expect(a.substring(0, 5), b.substring(0, 5));
    });
  });

  group('dispatch state machine', () {
    test('offerTo advances depth and records the attempt', () {
      const initial = RideDispatch();
      final next = initial.offerTo('Driver.One@toda.ph');

      expect(next.offeredTo, 'driver.one@toda.ph');
      expect(next.depth, 1);
      expect(next.offerSeq, 1);
      expect(next.attemptedDrivers, ['driver.one@toda.ph']);
      expect(next.hasLiveOffer, isTrue);
    });

    test('never offers the same driver twice', () {
      final once = const RideDispatch().offerTo('a@toda.ph');
      final twice = once.offerTo('a@toda.ph');
      expect(twice.attemptedDrivers, ['a@toda.ph']);
    });

    test('declining clears the offer but keeps the attempt recorded', () {
      final offered = const RideDispatch().offerTo('a@toda.ph');
      final declined = offered.declinedBy('a@toda.ph');

      expect(declined.offeredTo, isNull);
      expect(declined.attemptedDrivers, contains('a@toda.ph'));
      expect(declined.depth, offered.depth);
      expect(declined.hasLiveOffer, isFalse);
    });

    test('reports exhaustion at the 10-driver cap the rules enforce', () {
      var dispatch = const RideDispatch();
      for (var i = 0; i < DispatchDefaults.maxDriversToTry; i++) {
        dispatch = dispatch.offerTo('driver$i@toda.ph');
      }
      expect(dispatch.depth, DispatchDefaults.maxDriversToTry);
      expect(dispatch.isExhausted, isTrue);
    });
  });

  group('ride write payloads', () {
    test('a new ride starts unassigned, unrated, and searching', () {
      final payload = RideWrites.create(
        commuterUid: 'uid-1',
        commuterName: 'Maria',
        commuterPhone: '09181234567',
        pickup: const RidePlace(
          label: 'Plaza',
          geopoint: GeoPoint(14.5995, 120.9842),
        ),
        dropoff: const RidePlace(label: 'Palengke'),
      );

      expect(payload['status'], RideStatus.searching.wire);
      expect(payload['assignedDriver'], isNull);
      expect(payload['rating'], isNull);
      expect((payload['dispatch'] as Map)['depth'], 0);
    });

    test('accept normalises the driver email the rule compares against', () {
      final payload = RideWrites.accept(
        driverEmail: 'Driver.One@TODA.ph',
        snapshot: const RideDriverSnapshot(
          email: 'driver.one@toda.ph',
          firstName: 'Juan',
          phone: '09171234567',
          plateNumber: 'ABC1234',
        ),
      );

      expect(payload['assignedDriver'], 'driver.one@toda.ph');
      expect(payload['status'], RideStatus.accepted.wire);
    });

    test('status wire values round-trip', () {
      for (final status in RideStatus.values) {
        expect(RideStatus.fromWire(status.wire), status);
      }
    });

    test('terminal and live states are classified correctly', () {
      expect(RideStatus.completed.isTerminal, isTrue);
      expect(RideStatus.cancelled.isTerminal, isTrue);
      expect(RideStatus.searching.isTerminal, isFalse);
      expect(RideStatus.inTransit.isLive, isTrue);
      expect(RideStatus.completed.isLive, isFalse);
    });
  });

  // ── Model serialisation ──────────────────────────────────────
  //
  // The realistic failure here is not a malformed document — it is a
  // document written by the previous web build, which predates half these
  // fields. An admin listing every driver or ride receives those rows, so a
  // throw during parsing fails the entire query rather than one item.
  group('model serialisation', () {
    group('Driver', () {
      test('parses a fully populated document', () {
        final driver = Driver.fromMap({
          'email': 'juan@toda.ph',
          'uid': 'uid-1',
          'firstName': 'Juan',
          'lastName': 'Dela Cruz',
          'phone': '09171234567',
          'plateNumber': 'ABC1234',
          'todaChapter': 'Barangay Uno TODA',
          'status': DriverStatus.approved,
          'ratingSum': 22,
          'ratingCount': 5,
        }, 'juan@toda.ph');

        expect(driver.fullName, 'Juan Dela Cruz');
        expect(driver.isApproved, isTrue);
        expect(driver.ratingAverage, closeTo(4.4, 1e-9));
      });

      test('survives an entirely empty document', () {
        final driver = Driver.fromMap(const {}, 'ghost@toda.ph');

        expect(driver.email, 'ghost@toda.ph'); // falls back to the doc ID
        expect(driver.firstName, '');
        expect(driver.status, DriverStatus.pending); // never assume approved
        expect(driver.ratingCount, 0);
        expect(driver.ratingAverage, isNull); // not 0.0 — nobody has rated
      });

      test('survives a null document', () {
        expect(() => Driver.fromMap(null, 'x@toda.ph'), returnsNormally);
      });

      test('treats explicit nulls the same as absent fields', () {
        final driver = Driver.fromMap(const {
          'firstName': null,
          'status': null,
          'ratingSum': null,
          'ratingCount': null,
          'todaBodyNumber': null,
        }, 'x@toda.ph');

        expect(driver.firstName, '');
        expect(driver.status, DriverStatus.pending);
        expect(driver.ratingSum, 0);
        expect(driver.todaBodyNumber, isNull);
      });

      test('an unapproved driver never reads as approved', () {
        for (final status in [
          DriverStatus.pending,
          DriverStatus.suspended,
          DriverStatus.rejected,
        ]) {
          expect(
            Driver.fromMap({'status': status}, 'x@toda.ph').isApproved,
            isFalse,
            reason: '$status must not grant driving privileges',
          );
        }
      });
    });

    group('Ride', () {
      test('parses a legacy web-build ride with no dispatch block', () {
        // Exactly the shape the React app wrote: no commuterUid, no
        // dispatch, no driverSnapshot, pickup as a bare string, and
        // driverLocation as a {lat,lng} map rather than a GeoPoint.
        final ride = Ride.fromMap(const {
          'commuter': 'Maria',
          'pickup': 'Plaza',
          'dropoff': 'Palengke',
          'status': 'accepted',
          'assignedDriver': 'juan@toda.ph',
          'driverLocation': {'lat': 14.5995, 'lng': 120.9842},
        }, 'legacy-1');

        expect(ride.id, 'legacy-1');
        expect(ride.commuterUid, '');
        expect(ride.status, RideStatus.accepted);
        expect(ride.dispatch.depth, 0);
        expect(ride.dispatch.attemptedDrivers, isEmpty);
        expect(ride.driverSnapshot, isNull);

        // The label survives even though the old shape was a bare string.
        expect(ride.pickup.label, 'Plaza');
        expect(ride.dropoff.label, 'Palengke');
        expect(ride.pickup.geopoint, isNull);

        // An unconvertible driverLocation reads as absent, not as a crash.
        expect(ride.driverLocation, isNull);
      });

      test('survives an entirely empty document', () {
        final ride = Ride.fromMap(const {}, 'r1');

        expect(ride.pickup.label, '');
        expect(ride.pickup.geopoint, isNull);
        expect(ride.dispatch.offeredTo, isNull);
        expect(ride.rating, isNull);
        expect(ride.isRateable, isFalse);
      });

      test('an unknown status falls back to searching, not a crash', () {
        expect(Ride.fromMap(const {'status': 'zombie'}, 'r1').status,
            RideStatus.searching);
        expect(Ride.fromMap(const {'status': null}, 'r1').status,
            RideStatus.searching);
      });

      test('parses nested pickup, dispatch, and driver snapshot', () {
        final ride = Ride.fromMap({
          'commuterUid': 'uid-1',
          'status': 'accepted',
          'pickup': {
            'label': 'Plaza',
            'geopoint': const GeoPoint(14.5995, 120.9842),
          },
          'dispatch': {
            'offeredTo': 'juan@toda.ph',
            'offerSeq': 3,
            'attemptedDrivers': ['a@toda.ph', 'juan@toda.ph'],
            'depth': 2,
          },
          'driverSnapshot': {
            'email': 'juan@toda.ph',
            'firstName': 'Juan',
            'phone': '09171234567',
            'plateNumber': 'ABC1234',
          },
        }, 'r1');

        expect(ride.pickup.geopoint!.latitude, closeTo(14.5995, 1e-9));
        expect(ride.dispatch.depth, 2);
        expect(ride.dispatch.attemptedDrivers, hasLength(2));
        expect(ride.driverSnapshot!.plateNumber, 'ABC1234');
        expect(ride.driverSnapshot!.ratingAverage, isNull);
      });

      test('a rating stored as a double still reads as an int', () {
        // Firestore hands back numbers without distinguishing int from
        // double once they round-trip through JSON.
        expect(Ride.fromMap(const {'rating': 4.0}, 'r1').rating, 4);
      });

      test('a completed unrated ride is rateable; a rated one is not', () {
        expect(
          Ride.fromMap(const {'status': 'completed'}, 'r1').isRateable,
          isTrue,
        );
        expect(
          Ride.fromMap(const {'status': 'completed', 'rating': 5}, 'r1')
              .isRateable,
          isFalse,
        );
      });
    });

    group('ActiveDriver', () {
      test('parses a current presence document', () {
        final d = ActiveDriver.fromMap({
          'email': 'juan@toda.ph',
          'isOnline': true,
          'availability': DriverAvailability.idle,
          'position': {
            'geohash': 'wdw2q1abc',
            'geopoint': const GeoPoint(14.5995, 120.9842),
          },
        }, 'juan@toda.ph');

        expect(d.isAvailable, isTrue);
        expect(d.hasPosition, isTrue);
        expect(d.geopoint.longitude, closeTo(120.9842, 1e-9));
      });

      test('an unmigrated document is excluded rather than placed at 0,0', () {
        // The web build nested coordinates under `location`, which this
        // parser does not read. Without hasPosition the row would look like
        // a driver sitting in the Gulf of Guinea.
        final d = ActiveDriver.fromMap(const {
          'email': 'old@toda.ph',
          'isOnline': true,
          'location': {'lat': 14.5995, 'lng': 120.9842},
        }, 'old@toda.ph');

        expect(d.latitude, 0);
        expect(d.hasPosition, isFalse);
      });

      test('survives an entirely empty document', () {
        final d = ActiveDriver.fromMap(const {}, 'x@toda.ph');
        expect(d.isOnline, isFalse);
        expect(d.isAvailable, isFalse);
        expect(d.hasPosition, isFalse);
      });

      test('a driver already on a ride is not available', () {
        final d = ActiveDriver.fromMap({
          'isOnline': true,
          'availability': DriverAvailability.onRide,
          'position': {
            'geohash': 'wdw2q1abc',
            'geopoint': const GeoPoint(14.6, 121.0),
          },
        }, 'x@toda.ph');

        expect(d.isAvailable, isFalse);
      });
    });

    group('FeedbackReport', () {
      test('survives an empty document and defaults to unresolved', () {
        final f = FeedbackReport.fromMap(const {}, 'f1');
        expect(f.resolved, isFalse);
        expect(f.category, FeedbackCategory.other);
        expect(f.role, FeedbackRole.unknown);
      });
    });
  });

  // ── Fare calculation ─────────────────────────────────────────
  //
  // Tricycle tariffs are set per chapter by local ordinance, so the rules
  // are configuration. What must hold regardless: fares are whole pesos,
  // never below the minimum, and the statutory 20% discount is applied
  // exactly once.
  group('fare calculation', () {
    const config = FareConfig(); // ₱15 flag-down covering 2 km, then ₱5/km

    test('a trip inside the base distance costs the flag-down', () {
      for (final km in [0.0, 0.5, 1.0, 2.0]) {
        final quote = estimateFare(distanceKm: km, config: config);
        expect(quote.total, 15, reason: '$km km should be flag-down only');
        expect(quote.chargeableKm, 0);
      }
    });

    test('charges per started kilometre beyond the base', () {
      expect(estimateFare(distanceKm: 2.1, config: config).total, 20);
      expect(estimateFare(distanceKm: 3.0, config: config).total, 20);
      expect(estimateFare(distanceKm: 3.01, config: config).total, 25);
      expect(estimateFare(distanceKm: 5.0, config: config).total, 30);
    });

    test('floating-point error does not bill a phantom kilometre', () {
      // Haversine over real coordinates rarely lands on a whole number.
      final quote = estimateFare(distanceKm: 2.0000000001, config: config);
      expect(quote.chargeableKm, 0);
      expect(quote.total, 15);
    });

    test('applies the statutory 20% discount', () {
      final regular = estimateFare(distanceKm: 5, config: config);
      expect(regular.total, 30);

      for (final type in [
        FarePassengerType.senior,
        FarePassengerType.pwd,
        FarePassengerType.student,
      ]) {
        final quote =
            estimateFare(distanceKm: 5, config: config, passengerType: type);
        expect(quote.discount, 6);
        expect(quote.total, 24, reason: '$type is entitled to 20% off');
      }
    });

    test('a regular passenger receives no discount', () {
      final quote = estimateFare(distanceKm: 5, config: config);
      expect(quote.discount, 0);
      expect(quote.total, quote.subtotal);
    });

    test('never quotes below the minimum fare', () {
      const cheap = FareConfig(baseFare: 5, minimumFare: 12);
      expect(estimateFare(distanceKm: 0.5, config: cheap).total, 12);
    });

    test('quotes are whole pesos', () {
      const odd = FareConfig(baseFare: 13, baseDistanceKm: 1, perKm: 7);
      for (final km in [0.4, 1.7, 3.3, 9.9]) {
        final total = estimateFare(
          distanceKm: km,
          config: odd,
          passengerType: FarePassengerType.senior,
        ).total;
        expect(total, total.roundToDouble(),
            reason: 'a driver cannot make change for centavos');
      }
    });

    test('a bad GPS fix yields the flag-down instead of crashing', () {
      for (final bad in [-5.0, double.nan, double.infinity]) {
        final quote = estimateFare(distanceKm: bad, config: config);
        expect(quote.total, 15);
        expect(quote.distanceKm, 0);
      }
    });

    test('the itemised breakdown adds up', () {
      final quote = estimateFare(
        distanceKm: 7.5,
        config: config,
        passengerType: FarePassengerType.senior,
      );

      expect(quote.chargeableKm, 6); // 5.5 km beyond base, rounded up
      expect(quote.distanceCharge, 30);
      expect(quote.subtotal, quote.baseFare + quote.distanceCharge);
      expect(quote.total, quote.subtotal - quote.discount);
      expect(quote.formattedTotal, '₱36');
    });

  });

  // ── Runtime configuration ────────────────────────────────────
  //
  // These values live in `config/app` so a chapter can be re-tariffed or its
  // search widened without shipping an APK — which matters because the APK
  // reaches drivers as a file over Wi-Fi, not through an update channel.
  group('runtime config', () {
    test('dispatch tuning reads from config, and is capped by the rules', () {
      final tuned = DispatchConfig.fromMap(const {
        'searchRadiusKm': 12.5,
        'offerTimeoutSeconds': 30,
        'maxDriversToTry': 7,
      });
      expect(tuned.searchRadiusKm, 12.5);
      expect(tuned.offerTimeout, const Duration(seconds: 30));
      expect(tuned.maxDriversToTry, 7);

      // The security rules reject a dispatch depth above 10, so a larger
      // value must clamp rather than produce writes the server refuses.
      expect(
        DispatchConfig.fromMap(const {'maxDriversToTry': 99}).maxDriversToTry,
        DispatchDefaults.maxDriversToTry,
      );
      expect(
        DispatchConfig.fromMap(const {'maxDriversToTry': 0}).maxDriversToTry,
        1,
      );
    });

    test('a missing or nonsensical config falls back to the defaults', () {
      const fallback = DispatchConfig();
      for (final bad in <Map<String, dynamic>?>[
        null,
        const {},
        const {'offerTimeoutSeconds': 0},
        const {'offerTimeoutSeconds': -5},
        const {'searchRadiusKm': null},
      ]) {
        final config = DispatchConfig.fromMap(bad);
        expect(config.offerTimeout, fallback.offerTimeout);
        expect(config.searchRadiusKm, fallback.searchRadiusKm);
      }
    });

    test('the editor round-trips every field it writes', () {
      const dispatch = DispatchConfig(
        searchRadiusKm: 8,
        offerTimeout: Duration(seconds: 20),
        maxDriversToTry: 6,
      );
      const fare = FareConfig(baseFare: 20, perKm: 8);

      final document = configDocumentFrom(dispatch, fare);
      final back = DispatchConfig.fromMap(document);
      final fareBack = FareConfig.fromMap(document);

      expect(back.searchRadiusKm, dispatch.searchRadiusKm);
      expect(back.offerTimeout, dispatch.offerTimeout);
      expect(back.maxDriversToTry, dispatch.maxDriversToTry);
      expect(fareBack.baseFare, fare.baseFare);
      expect(fareBack.perKm, fare.perKm);
    });

    test('reads a chapter tariff from config, falling back per field', () {
      final partial = FareConfig.fromMap(const {'baseFare': 20});
      expect(partial.baseFare, 20);
      expect(partial.perKm, const FareConfig().perKm); // untouched default

      final empty = FareConfig.fromMap(null);
      expect(empty.baseFare, const FareConfig().baseFare);

      final full = FareConfig.fromMap(const {
        'baseFare': 25,
        'baseDistanceKm': 3,
        'farePerKm': 8,
        'minimumFare': 25,
        'discountRate': 0.20,
      });
      expect(estimateFare(distanceKm: 6, config: full).total, 49);
    });
  });
}
