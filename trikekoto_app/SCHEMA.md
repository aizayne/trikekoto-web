# TrikeKoTo — Firestore Schema

Companion to [`firestore.rules`](firestore.rules) and [`firestore.indexes.json`](firestore.indexes.json).
Every field below is enforced or deliberately left unenforced by a rule; where a
rule guards a field, it is noted.

---

## Identity model

| Role | Auth method | Key |
|---|---|---|
| Commuter | Anonymous Auth | `uid` (stored as `rides.commuterUid`) |
| Driver | Email + password | lowercased email, used as document ID |
| Admin | Email + password, **verified** | lowercased email, used as document ID |

Commuters sign in anonymously on first launch. It costs them nothing — no form,
no password — but it gives every ride document an owner, which is the difference
between "anyone can read every commuter's phone number" and "only the two
parties and an admin can".

> **Email normalisation is mandatory.** Firebase Auth preserves the casing the
> user typed but treats addresses case-insensitively for uniqueness, so
> `Juan@x.com` and `juan@x.com` are one account and would be two documents.
> Always route through `normalizeEmail()` (`lib/core/firestore/collection_paths.dart`);
> the rules call `.lower()` on their side so the two always agree.

---

## `drivers/{driverEmail}`

Driver profile, verification state, and rating aggregates. Contains PII, so it is
**not** publicly readable — anything the commuter needs is copied onto the ride
document at accept time.

| Field | Type | Notes |
|---|---|---|
| `email` | string | lowercased; must equal the document ID |
| `uid` | string | Firebase Auth uid, pinned at registration |
| `firstName`, `lastName` | string | 1–60 chars |
| `phone` | string | 7–20 chars |
| `plateNumber` | string | 3–16 chars, stored uppercase |
| `todaChapter` | string | TODA chapter / association name, ≤80 |
| `todaBodyNumber` | string? | tricycle body number |
| `status` | string | `pending` \| `approved` \| `suspended` \| `rejected` |
| `verification` | map? | `{licenseNo, licenseExpiry, franchiseNo, reviewedBy, reviewedAt, rejectionReason}` |
| `ratingSum` | int | sum of all stars received |
| `ratingCount` | int | number of ratings; average is derived, not stored |
| `fcmToken` | string? | current device token |
| `createdAt`, `updatedAt` | timestamp | |

**Rules.** Self-registration is only permitted with `status: 'pending'`, so a
driver can never approve themselves. Self-update is restricted to contact fields
— `status` is absent from the allowlist, so approval and suspension belong to
admins alone. `ratingSum`/`ratingCount` accept an increment from any signed-in
commuter, with the arithmetic verified server-side (exactly one vote, worth 1–5).

**Why the average isn't stored.** Rules cannot reliably compare floating-point
values, so a stored `ratingAvg` could not be validated and would become a
trivially forgeable field. Derive it: `ratingCount == 0 ? null : ratingSum / ratingCount`.

---

## `active_drivers/{driverEmail}`

The dispatch index — the collection the greedy search queries. Rewritten every
few seconds while a driver is online, so its rules do **no** `get()` lookups;
approval is checked where it actually matters, at ride acceptance.

| Field | Type | Notes |
|---|---|---|
| `email` | string | lowercased; must equal the document ID |
| `isOnline` | bool | false when the driver goes off shift |
| `availability` | string | `idle` \| `on_ride` |
| `position` | map | `{geohash: string, geopoint: GeoPoint}` |
| `accuracy`, `heading`, `speed` | number? | from Geolocator |
| `currentRideId` | string? | set while `availability == 'on_ride'` |
| `fcmToken` | string? | target for ride-offer pushes |
| `updatedAt` | timestamp | must equal `request.time` — no backdating |

This document deliberately carries **no name, phone, or plate**, because every
signed-in commuter can read the collection in order to run the match locally.
The `{geohash, geopoint}` shape is the `geoflutterfire_plus` convention, so
radius queries work without restructuring later.

> **Small-fleet shortcut.** For a single TODA chapter (tens of drivers, not
> thousands), skip geohash range queries entirely: fetch
> `isOnline == true && availability == 'idle'` and sort by Haversine distance on
> the device. It is one query, exact rather than approximate, and cheaper than
> the eight-cell neighbour scan a geohash radius search requires. The `geohash`
> field is written from day one so you can switch when the fleet outgrows it.

---

## `rides/{rideId}` — auto-ID

| Field | Type | Notes |
|---|---|---|
| `commuterUid` | string | owner; anonymous-auth uid |
| `commuterName` | string | 1–60 |
| `commuterPhone` | string | 7–20 |
| `pickup` | map | `{label: string, geopoint: GeoPoint}` |
| `dropoff` | map | `{label: string, geopoint: GeoPoint?}` |
| `notes` | string? | ≤300 |
| `status` | string | see lifecycle below |
| `dispatch` | map | `{offeredTo: string?, offerSeq: int, offerExpiresAt: timestamp?, attemptedDrivers: string[], depth: int}` |
| `assignedDriver` | string? | lowercased driver email |
| `driverSnapshot` | map? | `{email, firstName, phone, plateNumber, ratingSum, ratingCount}` |
| `driverLocation` | GeoPoint? | live trike position |
| `driverLocationAt` | timestamp? | |
| `scheduledFor` | timestamp? | null = immediate |
| `fareEstimate`, `distanceKm` | number? | |
| `rating` | int? | 1–5, write-once |
| `feedback` | string? | ≤500 |
| `createdAt` / `acceptedAt` / `startedAt` / `completedAt` / `cancelledAt` / `ratedAt` | timestamp? | |
| `cancelledBy` | string? | `commuter` \| `driver` \| `system` |

### Lifecycle

```
searching ──accept──> accepted ──start──> in_transit ──complete──> completed ──rate──> completed
    │                     │                    │
    └──────────── cancelled / expired ─────────┘
```

### Dispatch state

While `status == 'searching'`, the commuter's device drives the greedy search by
rewriting `dispatch`:

- `offeredTo` — the single driver currently being pinged. Only this driver may accept.
- `attemptedDrivers` — everyone already pinged; the next sweep skips them. Capped at 10.
- `depth` — how far down the sorted-by-distance list the search has walked. Monotonic, capped at 10.
- `offerExpiresAt` — `now + 15s`; drives the countdown on the driver's screen.

**Why `driverLocation` is mirrored onto the ride.** The commuter tracks the trike
by listening to their own ride document, not to `active_drivers`. That keeps live
tracking to a single snapshot listener the commuter already owns, and means no
rule ever has to do a cross-document `get()` on a per-GPS-tick read path.

### How double-booking is prevented

Two mechanisms, and both are required:

1. **`runTransaction` on the client** resolves the race. Two drivers tapping
   Accept in the same instant both read `status == 'searching'`; the second
   commit detects that the document changed under it, retries, re-reads
   `status == 'accepted'`, and aborts.
2. **The security rule** makes it a guarantee rather than a convention. The
   accept clause requires the *pre-image* to satisfy `status == 'searching' &&
   assignedDriver == null`, so a hand-rolled client that skips the transaction
   still cannot steal an assigned ride.

A transaction alone would be defeated by a modified APK. A rule alone would let
honest clients thrash. Together they are airtight.

---

## `admins/{adminEmail}`

`{email, displayName, createdAt}`. **Created from the Firebase Console only** —
`allow write: if false` means no client path can mint an admin.

Self-read is permitted so the app can answer "am I an admin?" with an ordinary
document lookup: a non-admin reads their own non-existent doc and gets a clean
"does not exist" instead of a permission error to special-case.

> **The `email_verified` requirement.** Firebase email/password signup does not
> prove you own the address you typed. Without an `email_verified` check, anyone
> could register an unverified account matching a document in `admins/` and
> receive a token that satisfies an email-based admin test. `isAdmin()` therefore
> requires `request.auth.token.email_verified == true`. Verify admin addresses
> before granting them a document, or they will be locked out of their own panel.

---

## `feedback/{feedbackId}` — auto-ID

`{submittedByUid, category, role, message, contact?, resolved, createdAt, resolvedBy?, resolvedAt?}`

`category` ∈ `issue | suggestion | question | other`; `role` ∈ `commuter | driver | unknown`;
`message` 1–2000 chars. Submitters may read back their own report; only admins
can list, resolve, or delete.

---

## `config/app`

Runtime tunables, so dispatch behaviour changes without shipping a new APK —
which matters when distribution is a signed APK passed around rather than a
store listing with an update channel.

```json
{
  "searchRadiusKm": 5,
  "offerTimeoutSeconds": 15,
  "maxDriversToTry": 10,
  "baseFare": 15,
  "farePerKm": 5,
  "minAppVersion": "1.0.0"
}
```

Readable by any signed-in user, writable by admins.

---

## `id_submissions/{subjectUid}`

Government ID submitted for manual review. **The only collection in this
schema holding sensitive personal information** in the sense the Data Privacy
Act of 2012 (RA 10173) uses the term — everything else is ordinary personal
information.

Its own collection, not a field on `riders/` or `drivers/`, for three reasons.
`riders` refuses `list` to everyone including admins so the commuter roster
cannot be enumerated, and putting ID data there would have meant undoing that
to allow review. Retention becomes a delete of one document plus one Storage
object rather than surgery on a profile in daily use. And a mistake in these
rules reaches the review data only, not names, phone numbers and ride history.

| Field | Type | Notes |
|---|---|---|
| `subjectUid` | string | must equal the document ID |
| `role` | string | `driver` or `rider` |
| `idType` | string | key from a closed list — see `IdTypes` |
| `idNumber` | string | 4–40 chars |
| `idPhotoPath` | string | **a Storage path, never a URL** — always `ids/{uid}/card` |
| `status` | string | `pending` on create; only an admin may move it |
| `consentAt` | timestamp | must equal request time; cannot be back-dated |
| `submittedAt` | timestamp | must equal request time |
| `reviewedBy` | string? | the reviewing admin, must equal their own token email |
| `reviewedAt` | timestamp? | |
| `rejectionReason` | string? | required on rejection, 3–300 chars |

**Why a path and not a URL.** A Firebase download URL carries an access token
that bypasses the Storage rules entirely: anyone holding the string can fetch
the object, from anywhere, and it keeps working after the document is deleted.
That is an acceptable trade for a profile photo the driver is meant to see. It
is the wrong trade for a government ID. The reviewer reads bytes with
`getData()`, which is checked against the rules on every call and leaves
nothing behind.

**Rules.** Create is self-only with `status: 'pending'`, no reviewer fields, a
consent timestamp equal to request time, and a photo path pinned to the
subject's own uid. Read is the subject or a verified admin — explicitly not
the driver a commuter is riding with. `list` is admin-only. Update is
admin-only, may touch only the four decision fields, requires the pre-image to
be `pending` so a decision cannot be revisited, and requires a reason on
rejection. Delete is the subject or an admin, which is how withdrawal and
retention both work.

**Account deletion.** A rider deleting their account triggers `onRiderDeleted`,
which anonymises their ride history rather than removing it: `commuterUid`
cleared, `commuterName` set to `Deleted account`, `commuterPhone`,
`commuterPhotoUrl` and `commuterFcmToken` removed. The ride survives because
it is the audit trail; the person does not. Rides are never deletable by
anyone, so this is the only mechanism by which commuter PII leaves them.

**Retention.** 90 days from **submission**, enforced by `purgeExpiredIds` —
a scheduled function running daily at 03:15 Manila time. Withdrawal by the
subject is immediate and independent of it.

Measured from `submittedAt` rather than `reviewedAt` on purpose. A submission
nobody ever reviewed is the worst case, not an exempt one — the same sensitive
data, held with no decision to show for it — and measuring from review would
let it sit indefinitely. One clock is also auditable: *90 days after it
arrived* is a sentence anyone can check.

The image is deleted before the document. A document with no image is a
harmless orphan; an image with no document is personal data no screen will
show and nobody will think to look for. If the image delete fails the document
stays, so tomorrow's run retries the pair rather than leaving it half-removed.

The verification outcome goes too. Nothing gates on ID status, so keeping
*"verified in September"* would retain a record of a check for a permission
that does not exist. If gating is added later, a boolean on the subject's own
document is what to keep — not the ID.

**Not wired to anything.** Booking and going online do not currently check ID
status. Gating them is a one-line rules change and a policy decision, not a
technical one.

---

## Indexes

`firestore.indexes.json` carries no inline comments because the CLI validates
that file against a strict schema. What each one is for:

| Collection | Fields | Serves |
|---|---|---|
| `rides` | `commuterUid`, `createdAt ↓` | commuter's own ride history |
| `rides` | `assignedDriver`, `status`, `createdAt ↓` | driver history, and restoring an in-progress ride after the app is killed |
| `rides` | `dispatch.offeredTo`, `status`, `createdAt ↓` | the driver's offer inbox |
| `rides` | `status`, `createdAt ↓` | admin analytics |
| `active_drivers` | `isOnline`, `availability`, `position.geohash` | the greedy nearest-driver sweep |
| `drivers` | `status`, `createdAt ↑` | admin verification queue, oldest first |
| `feedback` | `resolved`, `createdAt ↓` | admin feedback queue |

The `fieldOverrides` entries switch **off** indexing for `position.geopoint`,
`position.updatedAt`, `driverLocation` and `driverLocationAt`. Those fields are
rewritten every few seconds by GPS pings; every indexed field costs an index
write on each update, and no query ever filters or orders by them. Disabling
them is the single largest write-cost saving in this schema.

---

## Deployment

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

### Bootstrapping the first admin

There is no client path that creates an admin, by design. In the Firebase
Console:

1. **Authentication → Add user** — create the account, then verify the address
   (send a verification email and click through, or set `emailVerified` via the
   Admin SDK). `isAdmin()` fails without it.
2. **Firestore → Start collection `admins`** — document ID = the **lowercased**
   email, fields `email`, `displayName`, `createdAt`.

### Migrating from the web app's data

The web build wrote `status: 'Pending Verification'` on `drivers`; this schema
uses lowercase enums (`pending` / `approved` / `suspended` / `rejected`). Existing
rides also predate `commuterUid` and are unreadable under the new rules, which is
the intended outcome — they contain unowned PII. Run
[`scripts/migrate_from_web.mjs`](scripts/migrate_from_web.mjs) once, with the
Admin SDK, before pointing the Flutter app at the same project.

---

## Known limits

| Limit | Why it exists | Upgrade path |
|---|---|---|
| A modified client could inflate a driver's rating without having taken a ride. The rules verify the *arithmetic* of the increment, but cannot tie it to a specific completed ride, because each document in a transaction is authorised independently. | Avoids requiring Cloud Functions (paid Blaze plan) for the core flow. | Move the increment into a Function triggered on `rides.rating` write, then restrict `ratingSum`/`ratingCount` to `if false`. |
| Dispatch stops if the commuter backgrounds the app mid-search, since the 15-second widening runs on their device. | Keeps the system to Auth + Firestore + FCM, as specified. | A scheduled Function sweeping stale `searching` rides. The schema does not change — `dispatch` is already the full state machine. |
| Ride-offer pushes cannot be sent from the app. FCM send requires a server credential; embedding one in a distributed APK would let anyone push to any driver. | Unavoidable — this is an FCM design constraint, not a schema choice. | A Function on `dispatch.offeredTo` change, sending to `active_drivers.fcmToken`. Until then, drivers get in-app offers via the snapshot listener while the app is foregrounded. |
| A driver's approval is not re-checked on every GPS ping. | One `get()` per ping, per driver, every few seconds is a real and recurring cost. | Suspension is enforced at ride acceptance, which is the write that matters. For instant effect, put `approved` in a custom auth claim and check `request.auth.token.role`. |
