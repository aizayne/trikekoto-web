# TrikeKoTo — End-to-End Test Plan

This document walks through the full commuter ↔ driver ↔ admin
flow. Work through it in order — each section assumes the
previous sections have been verified.

## 0 · Prerequisites

- [ ] Firebase rules deployed
  (`firebase deploy --only firestore:rules` — already done)
- [ ] At least one admin doc exists. Either:
  - **Script path (recommended):**
    1. Firebase Console → Project Settings → Service Accounts → Generate new private key
    2. Save the downloaded JSON to the repo root as `service-account.json` (git-ignored)
    3. `npm run seed-admin jeloooaceee@gmail.com`
  - **Console path:** Firestore → Start collection → ID `admins`, doc ID `jeloooaceee@gmail.com`, leave body empty, Save
- [ ] `.env.local` populated with real Firebase keys (`cp .env.example .env.local` then fill in)
- [ ] `npm install` ran recently
- [ ] Two devices available, or two browsers (Chrome + Firefox) with different profiles
- [ ] Location services enabled on both devices
- [ ] Dev server running: `npm run dev`

---

## 1 · Shape migration check (important for existing installs)

The `active_drivers/*.location` field shape changed from
`{ latitude, longitude }` to `{ lat, lng }`. If any records
from before the refactor exist they'll break the greedy
ranking silently (those drivers will never enter the
ranking). Wipe the old ones once:

- [ ] Firestore Console → `active_drivers` → delete every doc
- [ ] Firestore Console → `rides` → delete every `searching` doc older than today

Once drivers sign in again their docs are recreated with the
new shape.

---

## 2 · Driver registration + approval gating

Use the **first** device/browser profile throughout this section.

- [ ] Visit `/driver` (or the driver nav from landing)
- [ ] Register a new driver with a never-used email — e.g. `testdriver@example.com`
- [ ] Firestore should show `drivers/testdriver@example.com` with `status: "Pending Verification"`
- [ ] Sign in as the pending driver → you should see the "Pending approval" gate, **not** the dashboard
- [ ] In a separate tab sign in as the admin (`jeloooaceee@gmail.com`) and open the Admin Panel
- [ ] The admin panel must show the pending driver; approve them
- [ ] Firestore should now show `status: "approved"` on that driver doc
- [ ] Refresh the pending driver's tab — they should now land on the driver dashboard

### Rules enforcement checks

- [ ] Try to edit `drivers/testdriver@example.com.status` from the driver's own tab via the JS console — it must **fail** with a permission error
- [ ] Try to read `admins/jeloooaceee@gmail.com` from a non-admin tab — it must **fail**

---

## 3 · Going online / GPS sync

- [ ] Driver dashboard → tap **Allow Location Access** → accept the permission prompt
- [ ] Tap **Go Online**
- [ ] Within ~3 seconds the location box should show lat/lng/accuracy
- [ ] Firestore `active_drivers/testdriver@example.com` should exist with:
  - `isOnline: true`
  - `location: { lat, lng, accuracy }` (verify field names are `lat`/`lng`, **not** `latitude`/`longitude`)
  - `updatedAt`: recent server timestamp
- [ ] Walk a few metres — the location should update
- [ ] Tap **Go Offline** → `isOnline` flips to `false` in Firestore

---

## 4 · Commuter ride request

Use the **second** device/browser profile.

- [ ] Visit `/` (landing) → tap **Book a Trike** (or similar)
- [ ] Allow location permission
- [ ] Fill pickup + dropoff, tap **Find Driver**
- [ ] Firestore should show a new `rides/{auto-id}` with:
  - `status: "searching"`
  - `assignedDriver: null`
  - `pickupCoords: { lat, lng }` (again, **not** `latitude`/`longitude`)
  - `createdAt`: recent server timestamp
- [ ] Commuter screen should show a "Searching for driver…" state

---

## 5 · Greedy nearest-driver matching

This is the new algorithm — test it deliberately.

### 5.1 · Single-driver case

- [ ] Only one driver online, within the proximity radius
- [ ] Commuter requests a ride
- [ ] Within ~5 seconds the driver should see a ride card with a **"Only driver"** badge (green)
- [ ] Driver taps **Accept** → ride transitions to `accepted`, driver email appears in `assignedDriver`

### 5.2 · Two drivers, same area (rank 0 vs 1)

- [ ] Two drivers online. Driver A is closer to the pickup than Driver B
- [ ] Commuter requests a ride
- [ ] Within 5s: **Driver A** sees the card with **"Closest · 1st offer"** badge (green)
- [ ] **Driver B** does NOT see the card yet
- [ ] Wait ~15s without either driver tapping
- [ ] Driver B should now see the card with **"2nd closest"** badge (amber)
- [ ] Driver A still sees their card too
- [ ] Driver B taps **Accept** → ride transitions to `accepted`; Driver A's card vanishes (status query filter re-fires)

### 5.3 · Tie-break determinism

- [ ] Two drivers online at the same GPS coordinates (e.g., same desk, two browsers)
- [ ] Commuter requests a ride
- [ ] Within 5s, **only one** of the drivers sees the card — the one whose email sorts earlier alphabetically
- [ ] The other driver sees it 15s later when the ranking expands to rank 1

### 5.4 · Proximity cutoff

- [ ] Drop pickup coords > 5 km from any online driver (set via browser devtools geolocation override)
- [ ] Commuter requests a ride
- [ ] No driver should see the card (all ranks are -1)
- [ ] Commuter's "Searching…" state should eventually time out after 10 min (`RIDE_MAX_AGE_MS`)

### 5.5 · Ignore flow

- [ ] Driver sees a ride offer → taps **Ignore**
- [ ] Card vanishes from their view (local session only)
- [ ] The ride should remain `status: "searching"` in Firestore
- [ ] After the offer window expands the ride should NOT re-appear for that driver in the same session
  *(current behaviour: ignored is session-local; refreshing clears it — documented limitation)*

---

## 6 · Race condition — two drivers tap Accept simultaneously

- [ ] Arrange a rank-1 (shared offer) scenario by waiting 15s after a commuter request
- [ ] Both drivers tap **Accept** as close to simultaneously as possible
- [ ] **Exactly one** driver should land on the active ride screen
- [ ] The other should see a quiet dismissal (card vanishes, no error toast — the `ALREADY_TAKEN` branch hides it)
- [ ] Firestore: `rides/{id}.assignedDriver` equals the winning driver's email

---

## 7 · Active ride lifecycle

- [ ] Driver on the active ride screen sees the correct pickup + dropoff
- [ ] Commuter screen shows "Driver on the way" with the driver's current GPS on the map
- [ ] Verify the map marker actually moves as the driver's GPS updates
- [ ] Driver taps **Complete Ride** → ride transitions to `completed`
- [ ] Commuter screen transitions to "Ride completed" state

---

## 8 · Cancellation paths

### 8.1 · Commuter cancels while searching

- [ ] Commuter taps **Cancel** while `status: "searching"`
- [ ] Ride transitions to `cancelled`
- [ ] Any driver who had the card offered should see it vanish within one snapshot tick

### 8.2 · Commuter cancels after driver accepted

- [ ] After the driver accepts, commuter taps **Cancel**
- [ ] Ride transitions to `cancelled`
- [ ] Driver's active ride screen should show the "commuter cancelled" alert (currently a `window.alert` — see open item in README)
- [ ] Driver returns to "waiting for rides" state

### 8.3 · Driver cancels their own active ride

- [ ] Driver on active ride screen taps **Cancel**
- [ ] Confirm prompt → OK
- [ ] Ride transitions to `cancelled` with `cancelledBy: "driver"`
- [ ] Commuter screen should show a ride-cancelled state

### 8.4 · Driver goes offline mid-ride

- [ ] Driver on active ride taps **Go Offline**
- [ ] Ride transitions to `cancelled` with `cancelledBy: "driver_went_offline"`
- [ ] Driver returns to the online/offline gate
- [ ] `active_drivers/{email}.isOnline` becomes `false`

---

## 9 · Push notifications

- [ ] Driver online, browser tab NOT focused
- [ ] Commuter requests a ride in the rank-0 slice for this driver
- [ ] A system notification should appear with body "You have a new ride request."
- [ ] Click the notification → tab focuses
- [ ] If notifications are blocked in the browser, the driver should see a "🔕 Notifications blocked" banner in the dashboard header

---

## 10 · PWA install

- [ ] `npm run build` → `npm run preview` on port 4173
- [ ] Open in Chrome on Android (or Edge on desktop)
- [ ] The install prompt should be offered
- [ ] After install the app icon on the home screen should show the amber trike glyph (not a default browser icon)
- [ ] Launch the installed app — it should open in standalone mode with the amber theme color on the status bar

---

## 11 · Rules spot-checks (manual Firestore writes)

Use the Firestore Console's "Manage Rules" → "Rules Playground" to validate:

- [ ] `rides/{newId}` create with `status: "searching"` + `assignedDriver: null`, unauthenticated → **allow**
- [ ] `rides/{newId}` create with `status: "accepted"`, unauthenticated → **deny**
- [ ] `rides/{existingId}` update, authenticated as driver A, trying to set `assignedDriver: "driverB@..."` → **deny**
- [ ] `drivers/foo@bar.com` update with `{ status: "approved" }`, authenticated as `foo@bar.com` (non-admin) → **deny**
- [ ] `drivers/foo@bar.com` update with `{ status: "approved" }`, authenticated as admin → **allow**
- [ ] `admins/bar@baz.com` write (any) from any client → **deny**

---

## 12 · Regression spot-checks

- [ ] `npm run lint` — zero errors
- [ ] `npm run build` — succeeds
- [ ] Service worker registration in devtools Application tab → both `sw.js` and `firebase-messaging-sw.js` active
- [ ] No console errors on driver dashboard or commuter booking page

---

## Known limitations documented for this release

- Ignored rides are session-local (not persisted per-driver); refreshing the tab re-shows them.
- `window.alert` is still used for commuter-cancelled-ride notifications. Replacement toast system is tracked separately.
- The greedy algorithm assumes all clients have a recent `active_drivers` snapshot; if a driver's network drops for >5s their rank may be computed inconsistently briefly until the next snapshot.
