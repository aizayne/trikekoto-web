# TrikeKoTo — Cost & Performance Projection

**Modelled:** 24 August 2026 · Firestore, `asia-southeast1`

Every rate below is read off the code, not assumed:

| Parameter | Value | Source |
|---|---|---|
| GPS distance filter | 20 m | `driver_controllers.dart`, `getPositionStream` |
| Offer timeout | 15 s | `DispatchDefaults` / `config/app` |
| Candidates per search | 10 max | capped by the security rules |
| Search radius | 5 km | `config/app` |

Assumptions stated so they can be argued with: an 8-hour shift, ~15 km/h
average through barangay streets, a trike **moving half the shift**, a 12-minute
ride, and a match after two dispatch sweeps.

---

## The headline

**A pilot does not fit in the Firestore free tier, and the binding constraint
is writes — not reads, and not money.**

| Scenario | Writes/day | vs 20k free | Reads/day | vs 50k free |
|---|---|---|---|---|
| **As built** — 20 drivers, 50 rides | **64,170** | **3.2× over** | 6,630 | fits |
| 50 m distance filter | 25,920 | 1.3× over | 4,380 | fits |
| **Small pilot** — 8 drivers, 20 rides | 25,668 | 1.3× over | 2,172 | fits |

Even an eight-driver pilot exceeds the free write allowance. If the plan was to
trial this on Spark, that will fail partway through the first day — and it will
present as writes being silently rejected, not as a bill.

**The cost itself is negligible.** Beyond the free tier, the as-built scenario
runs about **$2.39/month (~₱138)**. Firestore writes are cheap; there is no
affordability problem here, only a plan-tier problem.

Since Blaze is already required for the Cloud Functions (steps 62–67), this
changes nothing about the plan — but it does mean **Blaze is mandatory for the
pilot, not just for push notifications.**

---

## Where the writes go

```
presence GPS        60,000   93.5%   ←  one active_drivers write per GPS fix
ride GPS mirror      3,750    5.8%   ←  second write while carrying a passenger
ride lifecycle         250    0.4%
dispatch offers        100    0.2%
rating aggregate        50    0.1%
presence teardown       20    0.0%
```

**93.5% of all writes are one line of code**: the `active_drivers` update on
every GPS emission. Everything else in the system — every ride, every offer,
every rating — is rounding error beside it.

That is worth sitting with, because it means ride volume barely affects cost.
**Cost scales with drivers being online, not with rides being taken.** Twenty
idle drivers cost more than fifty completed rides.

---

## Mitigations, in order of effect

### 1. Widen the distance filter to 50 m — 2.5× fewer writes

One value in `driver_controllers.dart`. At 15 km/h a 50 m filter still updates
a driver's position every ~12 seconds, which is finer than the 15-second
dispatch cadence actually consumes. **The extra precision at 20 m is being paid
for and thrown away.**

This alone takes 20 drivers from 64k to 26k writes/day.

### 2. Do not bother with a minimum write interval

Modelled and rejected: at a 50 m filter the emission rate is already below a
10-second ceiling, so adding an interval clamp changes nothing and adds a
branch. Listed here so the idea is not re-proposed later.

### 3. Consider Realtime Database for presence

The deeper fix. Firestore bills **per document write**; Realtime Database bills
**per byte transferred**. A stream of tiny, high-frequency coordinate updates is
close to the worst case for one and the natural case for the other.

Moving only `active_drivers` to RTDB would remove ~94% of Firestore writes
while leaving rides, drivers, and the security model untouched. It is a real
architectural change and not worth doing before the pilot proves the app —
but it is the answer if the fleet grows past one chapter.

---

## Reads are comfortable

Never above 14% of the free allowance in any modelled scenario. The two
deliberate design decisions that keep it there:

- **Commuters track the trike through their own ride document**, not through
  `active_drivers`. One listener, no cross-document rule lookups.
- **Index exclusions on the GPS fields.** `position.geopoint`, `updatedAt`,
  `driverLocation` and `driverLocationAt` are unindexed, so the 60,000 daily
  presence writes cost one index write each instead of several.

That second one is the largest single cost saving already in the schema — it
was worth stating in `SCHEMA.md` and it holds up under the model.

### The analytics panel is the exception

The admin panel computes its figures by reading the window rather than keeping
denormalised counters, so it bills **one read per ride in the selected window**.
At a 50-ride/day pilot:

| Window | Reads per refresh |
|---|---|
| Today | ~50 |
| 7 days | ~350 |
| 30 days | ~1,500 |

Three things keep that from mattering:

- **It defaults to Today**, which is the reading an operator takes most often.
- **It is a one-shot fetch, not a listener.** A snapshot listener over the same
  window would bill a read for every ride update — including the GPS mirror
  during a trip — which would make an idle open admin tab the single most
  expensive thing in the system. It refreshes only when asked.
- **A 2,000-document cap**, and the panel says so when it hits it. Cost is
  bounded no matter how long the pilot runs.

The alternative — counter documents kept current by a Cloud Function — trades
these reads for a write on every ride transition, cannot be deployed on the
free plan, and drifts silently once wrong. At this scale reading the window is
both cheaper and more trustworthy.

---

## Not measured

- **Real device performance.** Cold start, battery drain over a shift, and
  memory on a low-end handset are unmeasured — they need a real phone, and the
  numbers here say nothing about them.
- **Actual movement patterns.** The 50% moving fraction is an estimate. A
  chapter whose drivers idle at a terminal most of the day would write far
  less; one covering a highway route would write more.
- **Cloud Functions cost.** The dispatch sweep runs 1,440 times/day, well
  inside the free invocation tier, but it reads up to 50 rides and the online
  driver set per run. Once deployed, that becomes the second-largest read
  source and should be re-modelled.
- **Network egress and tile bandwidth.** OSM tiles are cached for 30 days;
  first-load bandwidth per driver is unmeasured.

---

## Recommended before the pilot

1. **Enable Blaze** — required regardless; set a budget alert at ₱500/month
2. **Change the distance filter to 50 m** — one line, 2.5× fewer writes
3. Re-run this model with the real moving-fraction once a week of data exists
4. Re-model after the Cloud Functions deploy

Reproduce with `scripts/cost_model.py`.
