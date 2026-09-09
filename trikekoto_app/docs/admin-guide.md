# TrikeKoTo — Administrator Guide

For the TODA officer who verifies drivers and keeps the service running.
Written in English, since admin work involves the Firebase console.

---

## Getting access

Admin access is **not** something you can grant from inside the app — by
design, no client can create an admin. It requires two things:

1. An entry in the `admins` collection, keyed by your **lowercased** email.
   Whoever runs the project adds this once, from the Firebase console.
2. A Firebase account whose email address is **confirmed**.

Sign in through **Driver / Admin sign in** — the app decides which panel you
land in from your account, not from anything you pick.

### Confirming your email

The first time you sign in, you will probably land on **"Confirm your email to
open the admin panel"** rather than the panel itself. That is expected, not a
fault: signing up does not prove you own an address, so the server withholds
admin access until you show that you do.

1. Tap **Send verification email**
2. Open the link in your inbox — check spam
3. Come back to the app and tap **I have confirmed it**

The panel appears. You only ever do this once.

If it still says the address is unconfirmed after you have opened the link,
tap **I have confirmed it** a second time — occasionally the first tap runs
before Apple or Google has finished processing the link. The button also
waits 60 seconds between emails, so a countdown means it is working, not
stuck.

> If you land in the **driver** screens instead of the admin panel, your
> `admins` entry does not match your address. It is almost always a capital
> letter — the document ID must be entirely lowercase.

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

## Dispatch

**Dispatch** edits settings that apply to **every phone within seconds**. There is no confirmation step and no undo, so change one value at a
time and watch what happens.

### The stop button

At the top of that screen is a switch reading **Accepting bookings**. Turning
it off halts new bookings on every phone within seconds. You do not need to
update the app, and you do not need to reach the drivers.

Use it when something is going wrong and you need the system to stop while you
work out what. It asks you to confirm, because it stops the service.

**Rides already in progress finish normally.** Nobody sitting in a tricycle is
stranded — only new bookings are refused. Turning it back on takes effect just
as quickly, and does not ask for confirmation: being stuck stopped is worse
than an accidental restart.

While it is off, the card turns red and reads **Bookings stopped**, so nobody
has to wonder whether it took.

### The settings

Below the switch. Press **Save settings** when you have finished editing.

| Setting | What it does |
|---|---|
| Search radius (km) | Drivers further than this are never offered a ride |
| Offer timeout (seconds) | How long one driver has before the search moves on |
| Drivers to try | How many candidates before the search gives up. **Capped at 10** — larger values are rejected by the server. |

> **The app does not handle fares at all.** It never quotes a price and never
> records one. Passengers pay the posted TODA tariff in cash, exactly as they
> did before — there is no second figure on a phone to disagree with the
> board at the terminal.

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

### By driver

Ranked by trips completed, with fewer cancellations as the tie-break — between
two drivers who finished the same number, the one who called off fewer sits
higher.

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

## Light and dark

Every screen has a moon or sun in the top bar. The app opens light; tap it for
dark and it stays that way next time you open the app. It changes nothing but
the colours.

---

## What you cannot do, and why

| | |
|---|---|
| Delete a ride | Rides are the audit trail. Nobody can delete one, including you. |
| Create another admin | No client path can. Someone with console access adds the `admins` document. |
| Set or change a fare | The app has no fares. Tariffs are set by ordinance and posted at the terminal. |
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
5. **Nobody can book, and you did not change anything** — check the
   **Accepting bookings** switch under Dispatch. If it is off, someone
   stopped the service on purpose.
6. **A driver's status pill reads something odd** — words like *Active* or
   *Pending Verification* are left over from the old web system. Those drivers
   cannot work until they are approved again here, which resets them to the
   wording this app understands.
