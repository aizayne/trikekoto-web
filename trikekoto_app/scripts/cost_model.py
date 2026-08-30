"""Firestore operation model for a TrikeKoTo pilot.

Every rate below is read off the code, not assumed:

  distanceFilter 20 m          driver_controllers.dart, getPositionStream
  offerTimeout   15 s          DispatchDefaults / config app
  maxDriversToTry 10           capped by the security rules
  searchRadiusKm 5             config app

Firestore Spark (free) daily allowance: 50k reads, 20k writes, 20k deletes.
"""

SPARK = {"reads": 50_000, "writes": 20_000, "deletes": 20_000}

# Blaze standard pricing, USD per 100k ops. Regional rates vary; treat the
# money as indicative and the operation counts as the finding.
PRICE = {"reads": 0.06, "writes": 0.18, "deletes": 0.02}
USD_PHP = 58.0


def gps_emissions_per_shift(distance_filter_m, speed_kmh, hours, moving_frac):
    """How often Geolocator fires, given a distance filter."""
    metres_per_hour = speed_kmh * 1000
    moving_hours = hours * moving_frac
    return (metres_per_hour * moving_hours) / distance_filter_m


def model(drivers, rides_per_day, distance_filter_m=20, hours=8,
          speed_kmh=15, moving_frac=0.5, presence_min_interval_s=None):
    emissions = gps_emissions_per_shift(distance_filter_m, speed_kmh, hours,
                                        moving_frac)

    # A minimum interval clamps emissions to a ceiling regardless of movement.
    if presence_min_interval_s:
        ceiling = hours * 3600 / presence_min_interval_s
        emissions = min(emissions, ceiling)

    writes = {}
    reads = {}

    # ── Driver presence ──────────────────────────────────────
    # One active_drivers write per emission, all shift.
    writes["presence GPS"] = drivers * emissions

    # While carrying a passenger the driver ALSO mirrors position onto the
    # ride document. Assume a ride occupies ~12 min and each driver runs
    # rides_per_day/drivers of them.
    rides_each = rides_per_day / drivers
    ride_minutes = 12
    on_ride_frac = (rides_each * ride_minutes) / (hours * 60)
    writes["ride GPS mirror"] = drivers * emissions * on_ride_frac

    # ── Dispatch ─────────────────────────────────────────────
    # The commuter sweeps every 15 s while searching. Assume a ride is
    # matched after ~2 sweeps.
    sweeps = 2
    reads["dispatch driver scan"] = rides_per_day * sweeps * drivers
    reads["dispatch ride re-read"] = rides_per_day * sweeps
    writes["dispatch offers"] = rides_per_day * sweeps

    # ── Ride lifecycle ───────────────────────────────────────
    # create, accept, start, complete, rate = 5 writes; plus the driver
    # rating aggregate.
    writes["ride lifecycle"] = rides_per_day * 5
    writes["rating aggregate"] = rides_per_day

    # ── Listeners ────────────────────────────────────────────
    # Each listener bills one read per changed document delivered.
    # Driver watches: own profile, offers, active ride.
    reads["driver listeners"] = drivers * (
        emissions * on_ride_frac  # own ride updates echo back
        + rides_each * 6          # offer + lifecycle transitions
    )
    # Commuter watches their own ride through the lifecycle.
    reads["commuter listener"] = rides_per_day * 8
    # Admin panel: drivers list + feedback, if open ~1 h/day.
    reads["admin panel"] = drivers * 4

    writes["presence teardown"] = drivers  # delete on going offline
    return reads, writes


def report(label, drivers, rides, **kw):
    reads, writes = model(drivers, rides, **kw)
    tr, tw = sum(reads.values()), sum(writes.values())

    print(f"\n{'='*66}\n{label}\n{'='*66}")
    print(f"{drivers} drivers | {rides} rides/day | "
          f"distanceFilter {kw.get('distance_filter_m', 20)} m"
          + (f" | min interval {kw['presence_min_interval_s']}s"
             if kw.get('presence_min_interval_s') else ""))

    print("\n  WRITES/day")
    for k, v in sorted(writes.items(), key=lambda x: -x[1]):
        print(f"    {k:<24} {v:>10,.0f}  {v/tw*100:5.1f}%")
    print(f"    {'TOTAL':<24} {tw:>10,.0f}   free tier {SPARK['writes']:,}"
          f"  ->  {'OVER by %.1fx' % (tw/SPARK['writes']) if tw > SPARK['writes'] else 'fits'}")

    print("\n  READS/day")
    for k, v in sorted(reads.items(), key=lambda x: -x[1]):
        print(f"    {k:<24} {v:>10,.0f}  {v/tr*100:5.1f}%")
    print(f"    {'TOTAL':<24} {tr:>10,.0f}   free tier {SPARK['reads']:,}"
          f"  ->  {'OVER by %.1fx' % (tr/SPARK['reads']) if tr > SPARK['reads'] else 'fits'}")

    billable_w = max(0, tw - SPARK["writes"])
    billable_r = max(0, tr - SPARK["reads"])
    usd = (billable_w / 100_000 * PRICE["writes"]
           + billable_r / 100_000 * PRICE["reads"]) * 30
    print(f"\n  Beyond free tier: ~${usd:,.2f}/month  (~PHP {usd*USD_PHP:,.0f})")
    return tw, tr


report("AS BUILT - one TODA chapter", 20, 50)
report("MITIGATION 1 - coarser distance filter", 20, 50, distance_filter_m=50)
report("MITIGATION 2 - filter + 10s minimum interval between presence writes",
       20, 50, distance_filter_m=50, presence_min_interval_s=10)
report("SMALL PILOT - as built", 8, 20)
