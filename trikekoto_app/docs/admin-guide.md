# TrikeKoTo — Administrator Guide

For the TODA officer who verifies drivers and keeps the service running.
Written in English, since admin work involves the Firebase console.

---

## Getting access

Admin access is **not** something you can grant from inside the app — by
design, no client can create an admin. It requires two things:

1. An entry in the `admins` collection, keyed by your lowercased email
2. A Firebase account whose email address is **verified**

Both are done once by whoever runs the project, using
`scripts/seed_admin.mjs`. If you can sign in but every action is refused with
*"The server refused that action"*, the second condition is almost certainly
the missing one.

Sign in through **Driver / Admin sign in** — the app decides which panel you
land in from your account, not from anything you pick.

---

## Verifying drivers

This is the job the app exists to support. A driver cannot accept a single
ride until you approve them.

**Pending verification** at the top of your dashboard shows everyone waiting,
with a count badge. For each you see their name, plate number, mobile number,
email and TODA chapter.

**Before approving, confirm against your chapter records** that the person,
the plate, and the chapter actually match. The app cannot check this — it only
records what the driver typed. Approving someone unverified puts an
unaccountable driver in front of passengers.

Press **Approve**. Their app updates within seconds; they do not need to sign
out and back in.

### Suspending

Press **Suspend** on any approved driver. Effective immediately for anything
that matters: they cannot accept new rides.

> **One caveat worth knowing.** A suspended driver's phone may still appear in
> the dispatch index for a short while, because approval is not re-checked on
> every GPS update. They will be *offered* rides but the server refuses their
> acceptance. Nobody gets stranded — the ride simply moves to the next driver.

Suspension is reversible: press **Approve** to reinstate.

---

## Reading feedback

**Feedback** on the dashboard shows reports from drivers and commuters, with a
badge when any are unhandled.

Reports are split into **Needs attention** and **Resolved**. Press **Mark
resolved** once you have acted; **Reopen** if it comes back. Resolved history
stays visible on purpose — a recurring complaint is only recognisable against
what came before it.

If someone left a contact, it appears with the report.

---

## Dispatch and fares

**Dispatch & fares** edits settings that apply to **every phone within
seconds**. There is no confirmation step and no undo, so change one value at a
time and watch what happens.

| Setting | What it does |
|---|---|
| Search radius (km) | Drivers further than this are never offered a ride |
| Offer timeout (seconds) | How long one driver has before the search moves on |
| Drivers to try | How many candidates before the search gives up. **Capped at 10** — larger values are rejected by the server. |
| Flag-down fare | Covers everything up to the base distance |
| Base distance (km) | Distance included in the flag-down |
| Per succeeding km | Charged per started kilometre beyond the base |
| Minimum fare | No quote falls below this |
| Statutory discount | **0.20 is the legal rate** for seniors (RA 9994) and PWDs (RA 10754). Lowering it is unlawful. |

> The fares here are **estimates shown to commuters**. They do not collect
> money. Keep them matching your posted tariff, or passengers will arrive
> expecting the wrong figure.

---

## Ride analytics

At the top of the dashboard. Pick a window — **Today**, **7 days**, or
**30 days** — and press **Refresh** to re-read. It does not update on its own;
that is deliberate, because a live panel left open costs money all day.

### The headline row

| Figure | What it means |
|---|---|
| **completed** | Trips that finished |
| **completion rate** | Completed, out of the rides that reached *any* conclusion |
| **cancelled** | Called off by the commuter or the driver |
| **no driver found** | The offer chain ran out — nobody accepted |
| **avg rating** | Across every rated ride in the window |

Rides still in progress are left out of the completion rate on purpose. If
they counted as failures, every reading taken during the day would look bad
and then quietly improve overnight.

**"No driver found" is the number to watch during a pilot.** It is the only
one on the panel that points at something you can fix: too few drivers online,
or a search radius that is too tight. Everything else describes what people
did; this describes what the app failed to do.

A high **cancelled** count is worth pairing with the feedback inbox — the
figure tells you it happened, the reports tell you why.

### About the money

The fares box is **what the app quoted**, not what anyone collected.
Passengers pay the driver in cash and the app never touches a payment, so
treat it as an estimate of activity, never as takings. It counts completed
trips only — a cancelled ride keeps the fare it was quoted, and adding those
in would show income from trips that never happened.

If **average fare** looks low, check whether trips are completing without a
recorded distance rather than assuming fares were discounted.

### By driver

Ranked by trips completed, with fares as the tie-break — six short trips rank
above one long one, which is usually the driver you actually want to see at
the top.

A driver's rating here is only as good as its sample. If the panel says many
completed rides went unrated, the averages are thin, and a single bad score
can move one a long way. Read a low average as a reason to look, not as a
finding.

### Two things that can make the numbers wrong

- **Partial window.** Past 2,000 rides the panel reads only the most recent
  and says so at the top. The totals below that notice are incomplete.
- **Rides from the old web app.** Those carry no timestamp, so they are left
  out of every window rather than being dropped into an arbitrary day.

---

## What you cannot do, and why

| | |
|---|---|
| Delete a ride | Rides are the audit trail. Nobody can delete one, including you. |
| Create another admin | No client path can. It needs the seeding script. |
| Change a fare a driver already charged | Completed rides are immutable. |
| See a commuter's identity | Commuters are anonymous. You see the name and number they typed for that ride, nothing more. |

---

## When something is wrong

1. **Nobody can book** — check that Anonymous sign-in is still enabled in the
   Firebase console under Authentication → Sign-in method.
2. **A driver says they get no offers** — confirm they are Approved, that
   their toggle is Online, and that a commuter is within the search radius.
3. **The app closed on someone** — crashes are reported automatically. Ask
   whoever runs the project to check Crashlytics.
4. **Everything is refused** — most likely the security rules were changed.
   Contact the project maintainer before changing anything yourself.
