import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trikekoto_app/core/config/app_config.dart';

/// The chapter's service area.
///
/// It warns and never refuses, so the property worth pinning is the opposite
/// of the usual one: every booking must survive it, including the ones it
/// flags, and a chapter that has not configured an area must see no warnings
/// at all rather than a warning on everything.

// San Marcelino plaza, and a point about 4 km north of it.
const _centre = GeoPoint(14.9747, 120.1577);
const _nearby = GeoPoint(14.9800, 120.1577); // ~0.6 km
const _farOff = GeoPoint(15.0107, 120.1577); // ~4.0 km

ServiceArea _area({double radiusKm = 3}) => ServiceArea.fromMap({
      'label': 'Balaybay Resettlement',
      'lat': _centre.latitude,
      'lng': _centre.longitude,
      'radiusKm': radiusKm,
    });

void main() {
  group('a chapter that has not set an area', () {
    test('warns about nothing', () {
      const none = ServiceArea.fallback;
      expect(none.warns, isFalse);
      expect(none.covers(_farOff), isTrue);
      expect(none.coversPoint(LatLng(0, 0)), isTrue);
    });

    test('and neither does an empty or broken document', () {
      for (final value in <Object?>[
        null,
        <String, dynamic>{},
        {'label': '', 'radiusKm': 0},
        // A negative radius is a typo, not a tiny circle that warns on
        // everything.
        {'lat': 14.9, 'lng': 120.1, 'radiusKm': -5},
      ]) {
        expect(ServiceArea.fromMap(value).warns, isFalse, reason: '$value');
      }
    });

    test('and the name falls back to something a warning can print', () {
      expect(ServiceArea.fromMap(null).label, 'Balaybay Resettlement');
      expect(ServiceArea.fromMap({'label': '   '}).label,
          'Balaybay Resettlement');
    });
  });

  group('a configured area', () {
    test('covers what is inside it and flags what is not', () {
      final area = _area();
      expect(area.warns, isTrue);
      expect(area.covers(_centre), isTrue);
      expect(area.covers(_nearby), isTrue);
      expect(area.covers(_farOff), isFalse);
    });

    test('measures a map point the same way', () {
      final area = _area();
      expect(area.coversPoint(LatLng(_nearby.latitude, _nearby.longitude)),
          isTrue);
      expect(area.coversPoint(LatLng(_farOff.latitude, _farOff.longitude)),
          isFalse);
    });

    test('a wider radius takes the same trip back in', () {
      expect(_area(radiusKm: 3).covers(_farOff), isFalse);
      expect(_area(radiusKm: 10).covers(_farOff), isTrue);
    });

    test('an absurd radius is clamped rather than trusted', () {
      expect(ServiceArea.fromMap({'radiusKm': 5000}).radiusKm, 100);
    });

    test('round-trips through the document an admin saves', () {
      final saved = _area(radiusKm: 2.5).toMap();
      final read = ServiceArea.fromMap(saved);
      expect(read.label, 'Balaybay Resettlement');
      expect(read.radiusKm, 2.5);
      expect(read.center.latitude, closeTo(_centre.latitude, 0.000001));
      expect(read.center.longitude, closeTo(_centre.longitude, 0.000001));
    });
  });
}
