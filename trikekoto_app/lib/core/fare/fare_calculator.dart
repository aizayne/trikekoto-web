import 'dart:math' as math;

/// Fare rules for a TODA chapter.
///
/// Tricycle fares in the Philippines are set per chapter under an LGU or
/// LTFRB ordinance, not nationally, so every value here is configuration
/// rather than a constant. The defaults match the shape of a typical
/// ordinance — a flag-down covering the first two kilometres, then a charge
/// per succeeding kilometre — and are overridden from `config/app` so a
/// chapter can be re-tariffed without shipping a new APK.
class FareConfig {
  const FareConfig({
    this.baseFare = 15,
    this.baseDistanceKm = 2,
    this.perKm = 5,
    this.minimumFare = 15,
    this.discountRate = 0.20,
  });

  /// Flag-down, covering everything up to [baseDistanceKm].
  final num baseFare;
  final num baseDistanceKm;

  /// Charged per *succeeding* kilometre, counted as started kilometres —
  /// 2.1 km beyond the base is billed as 3, which is how conductors and
  /// drivers actually compute it.
  final num perKm;

  final num minimumFare;

  /// Statutory fare discount for senior citizens (RA 9994) and persons with
  /// disability (RA 10754), both 20% on public land transport. Students are
  /// commonly granted the same rate by local ordinance.
  final num discountRate;

  factory FareConfig.fromMap(Map<String, dynamic>? data) {
    final d = data ?? const <String, dynamic>{};
    const fallback = FareConfig();
    return FareConfig(
      baseFare: (d['baseFare'] as num?) ?? fallback.baseFare,
      baseDistanceKm: (d['baseDistanceKm'] as num?) ?? fallback.baseDistanceKm,
      perKm: (d['farePerKm'] as num?) ?? fallback.perKm,
      minimumFare: (d['minimumFare'] as num?) ?? fallback.minimumFare,
      discountRate: (d['discountRate'] as num?) ?? fallback.discountRate,
    );
  }

  Map<String, dynamic> toMap() => {
        'baseFare': baseFare,
        'baseDistanceKm': baseDistanceKm,
        'farePerKm': perKm,
        'minimumFare': minimumFare,
        'discountRate': discountRate,
      };
}

/// Who is riding, for discount purposes.
enum FarePassengerType {
  regular,
  student,
  senior,
  pwd;

  bool get isDiscounted => this != regular;
}

/// An itemised quote. Kept itemised rather than a bare total so the booking
/// screen can show the commuter *why* the fare is what it is — an opaque
/// number is the fastest way to lose trust in a fare.
class FareQuote {
  const FareQuote({
    required this.distanceKm,
    required this.chargeableKm,
    required this.baseFare,
    required this.distanceCharge,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.passengerType,
  });

  final double distanceKm;

  /// Started kilometres beyond the base distance.
  final int chargeableKm;

  final num baseFare;
  final num distanceCharge;
  final num subtotal;
  final num discount;
  final num total;
  final FarePassengerType passengerType;

  String get formattedTotal => '₱${total.toStringAsFixed(0)}';

  @override
  String toString() =>
      'FareQuote(${distanceKm.toStringAsFixed(2)} km → $formattedTotal)';
}

/// Estimates the fare for a trip.
///
/// Deliberately a pure function of distance and configuration: no surge, no
/// time-of-day multiplier, no per-minute waiting charge. A TODA fare is a
/// published tariff a passenger can check against a posted matrix, and a
/// figure the app cannot justify is worse than no figure at all.
///
/// [distanceKm] that is negative, infinite, or NaN is treated as zero rather
/// than throwing — it arrives from GPS, which occasionally produces all
/// three, and a booking screen should not crash over a bad fix.
FareQuote estimateFare({
  required double distanceKm,
  FareConfig config = const FareConfig(),
  FarePassengerType passengerType = FarePassengerType.regular,
}) {
  final distance =
      (distanceKm.isNaN || distanceKm.isInfinite || distanceKm < 0)
          ? 0.0
          : distanceKm;

  final excessKm = math.max(0.0, distance - config.baseDistanceKm);

  // Started kilometres. The epsilon absorbs floating-point error so that a
  // distance computed as 2.0000000001 km does not bill an extra kilometre.
  final chargeableKm = excessKm <= 1e-9 ? 0 : (excessKm - 1e-9).ceil();

  final distanceCharge = chargeableKm * config.perKm;
  final rawSubtotal = config.baseFare + distanceCharge;
  final subtotal = math.max(rawSubtotal, config.minimumFare);

  final discount = passengerType.isDiscounted
      ? _roundPeso(subtotal * config.discountRate)
      : 0;

  final total = math.max(0, subtotal - discount);

  return FareQuote(
    distanceKm: distance,
    chargeableKm: chargeableKm,
    baseFare: config.baseFare,
    distanceCharge: distanceCharge,
    subtotal: subtotal,
    discount: discount,
    total: total,
    passengerType: passengerType,
  );
}

/// Fares are collected in coins, so quotes are whole pesos.
num _roundPeso(num value) => value.round();
