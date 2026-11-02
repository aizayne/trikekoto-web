# TrikeKoTo — Firestore Schema

Companion to [`firestore.rules`](firestore.rules) and [`firestore.indexes.json`](firestore.indexes.json).
Every field below is enforced or deliberately left unenforced by a rule; where a
rule guards a field, it is noted.

---

## Identity model

| Role | Auth method | Key |
|---|---|---|
| Commuter | Phone number + SMS code | `uid` (stored as `rides.commuterUid`) |
| Driver | Email + password | lowercased email, used as document ID |
| Admin | Email + password, **verified** | lowercased email, used as document ID |

Commuters began as anonymous accounts and now verify a phone number before they
can book; `hasVerifiedPhone()` refuses a ride from anyone else. The uid gives
every ride document an owner, which is the difference between "anyone can read
every commuter's phone number" and "only the two parties and an admin can". A
leftover anonymous session is sent to sign in, and linking its phone credential
keeps the ride history attached to the same uid.

**One account per mobile number.** Firebase gives a verified number one sign-in;
[`phone_claims`](#phone_claimsnumber) extends that across drivers and commuters.

**Commuters and drivers also need an approved government ID.** Booking, going
online and accepting a ride all require an `id_verified/{uid}` marker. See
[`id_submissions`](#id_submissionssubjectuid).

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
| `phone` | string | E.164; must be held by this account in `phone_claims`; typed, not verified by SMS |
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
driver can never approve themselves. A driver may correct their own details,
except `phone`, only while `pending`; after approval an admin makes the change, so the approval cannot
carry over to a tricycle nobody checked. A driver may update `fcmToken` at any
status. `status` is never self-editable, so approval and suspension belong to
admins alone. No client may write `ratingSum` or `ratingCount`: the `onRideRated`
function derives each increment from a completed ride and guards against counting
it twice with `rides.ratingCounted`.

**Why the average isn't stored.** Rules cannot reliably compare floating-point
values, so a stored `ratingAvg` could not be validated and would become a
trivially forgeable field. Derive it: `ratingCount == 0 ? null : ratingSum / ratingCount`.

---

## `active_drivers/{driverEmail}`

The dispatch index — the collection the server-side search reads. Updated as the
driver moves and at each check-in, so updates do **no** document lookups in the
rules. Creating the row, which happens once per shift, checks `id_verified`.
Approval is checked by dispatch before an offer and by the rules at acceptance.

| Field | Type | Notes |
|---|---|---|
| `email` | string | lowercased; must equal the document ID |
| `isOnline` | bool | false when the driver goes off shift |
| `availability` | string | `idle` \| `on_ride`. Display only: it can lag, so dispatch works out who is busy from the rides |
| `position` | map | `{geohash: string, geopoint: GeoPoint}` |
| `heartbeatSeconds` | int? | how often this app promised to check in (120); absent on older apps |
| `accuracy`, `heading`, `speed` | number? | from Geolocator |
| `currentRideId` | string? | set while `availability == 'on_ride'` |
| `fcmToken` | string? | target for ride-offer pushes |
| `updatedAt` | timestamp | must equal `request.time` — no backdating |

Only admins can read this collection, for the dispatch monitor; each driver
writes their own row. Commuters could read it when matching ran on their device,
which let any account track the whole fleet, so matching moved to the server. The
document still carries **no name, phone, or plate**. The `{geohash, geopoint}`
shape is the `geoflutterfire_plus` convention, so radius queries work without
restructuring later.

> **Small-fleet shortcut.** For a single TODA chapter (tens of drivers, not
> thousands), dispatch skips geohash range queries: it fetches
> `isOnline == true` and sorts by Haversine distance in the function. It is one
> query, exact rather than approximate, and cheaper than the eight-cell neighbour
> scan a geohash radius search requires. The `geohash` field is written from day
> one so you can switch when the fleet outgrows it.

---

## `rides/{rideId}` — auto-ID

| Field | Type | Notes |
|---|---|---|
| `commuterUid` | string | owner; the commuter's Auth uid |
| `commuterName` | string | 1–60 |
| `commuterPhone` | string | must equal the verified number in the auth token |
| `commuterPhotoUrl` | string? | ≤500; copied from the rider's profile |
| `commuterFcmToken` | string? | target for ride status pushes |
| `pickup` | map | `{label: string, geopoint: GeoPoint}` |
| `dropoff` | map | `{label: string, geopoint: GeoPoint?}` |
| `serviceType` | string? | `regular` \| `special`; absent on older rides and treated as `regular` |
| `notes` | string? | ≤300 |
| `status` | string | see lifecycle below |
| `dispatch` | map | `{offeredTo: string?, offerSeq: int, offerExpiresAt: timestamp?, attemptedDrivers: string[], depth: int}` |
| `assignedDriver` | string? | lowercased driver email |
| `driverSnapshot` | map? | `{email, firstName, phone, plateNumber, ratingSum, ratingCount}` |
| `driverLocation` | GeoPoint? | live trike position |
| `driverLocationAt` | timestamp? | |
| `scheduledFor` | timestamp? | null = immediate |
| `rating` | int? | 1–5, write-once |
| `ratingCounted` | bool? | set by `onRideRated`, so a retried event cannot count a rating twice |
| `feedback` | string? | ≤500 |
| `noDriverNoticeSent` | bool? | set by dispatch, so the "no driver yet" push goes once |
| `createdAt` / `acceptedAt` / `startedAt` / `completedAt` / `cancelledAt` / `ratedAt` | timestamp? | |
| `cancelledBy` | string? | `commuter` \| `driver` \| `system` |

The app records no fare. TODA tariffs are set by ordinance and posted at the
terminal, and passengers pay the driver in cash.

### Lifecycle

```
searching ──accept──> accepted ──start──> in_transit ──complete──> completed ──rate──> completed
    │                     │                    │
    └──────────── cancelled / expired ─────────┘
```

### Dispatch state

While `status == 'searching'`, **Cloud Functions own `dispatch`**. No client rule
can aim `offeredTo` at a driver. An offered driver may only clear the offer when
declining, and a commuter may only reset it when cancelling.

- `offeredTo` — the single driver currently being offered the ride. Only this driver may accept.
- `offerSeq` — changes with every offer, so concurrent function runs can detect that another run moved the ride first.
- `attemptedDrivers` — everyone already offered this ride; later attempts skip them.
- `depth` — how many drivers have been tried. The ride expires at `config/app.maxDriversToTry` (default 10).
- `offerExpiresAt` — `now + offerTimeoutSeconds` (default 15); drives the countdown on the driver's screen.

A search also expires after five minutes, even if no driver was ever available.
See [Cloud Functions](#cloud-functions) for what moves it along and
`functions/src/dispatch.ts` for the ranking.

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

## `riders/{riderUid}`

A commuter's profile, keyed by uid so a phone number never becomes a guessable
document ID.

| Field | Type | Notes |
|---|---|---|
| `name` | string | 1–60 |
| `phone` | string | must equal the verified number in the auth token; cannot change afterwards |
| `profilePhotoUrl` | string? | ≤500 |
| `savedAddresses` | list | empty on create, ≤20 |
| `ratingSum`, `ratingCount` | int | start at 0; not editable by the rider |
| `createdAt`, `updatedAt` | timestamp | |

**Rules.** A rider can read, create and edit only their own document. Nobody can
`list` the collection, admins included, so the commuter roster cannot be
enumerated. An admin may delete a rider named on a ride but still cannot read
their document. See [Removing an account](#removing-an-account).

---

## `phone_claims/{number}`

`{uid, role, createdAt}`, keyed by the number in E.164 form. This is what limits a
number to one account, across drivers and commuters.

The profile that names a number must be written in one batch with its claim. A
second account's write lands on a document it does not own and is refused, and
nobody else can read the claim to learn who holds it. A rider can only claim the
number in their auth token. A driver can only claim the number on their own
profile. Only an admin or the account-removal functions can delete a claim, which
is what frees the number.

**Known limit.** A driver's number is typed, not verified by SMS. Someone could
register a driver account with another person's number, and that person would then
be refused when signing up as a commuter. An admin removing that driver frees the
number. Sending drivers a code too would close this.

---

## `landmarks/{landmarkId}`

`{name, point, createdAt}`: a place the chapter has named on the map. `name` is
1–80 characters and `point` is a GeoPoint. Anyone signed in can read them and only
an admin can add or remove one, because everyone sees them. They appear as named
pins in the map picker, and search matches them on the phone as the person types.
OpenStreetMap search still runs only on submit, because Nominatim's usage policy
forbids autocomplete on its public service.

`scripts/import_osm_landmarks.mjs` imports named places from OpenStreetMap with the
Admin SDK. Those also carry `source: 'osm'`, which is how `--remove` tells them from
landmarks added by hand.

---

## `device_logins/{uid}`

`{secretHash, phone, updatedAt}`. Lets one remembered phone sign back in without a
code. No client may read or write it, including an admin.

`rememberDevice` creates a 256-bit secret after a commuter signs in, keeps its
SHA-256 here, and returns the secret once to the phone's secure storage. A later
sign-in on a different phone replaces this document, which stops the old phone
working. `signInWithDevice` checks the secret and the account's current number,
then returns a custom sign-in token.

**The trade-off.** Signing out no longer stops someone holding that unlocked phone
from getting back in. Reinstalling, clearing app data or moving to a new phone
still needs a code, because app backup is switched off.

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
  "acceptingRides": true,
  "routingBaseUrl": "https://router.project-osrm.org",
  "minAppVersion": "1.0.0"
}
```

Readable by any signed-in user, writable by admins. `acceptingRides: false` makes
the rules refuse new bookings while rides already in progress finish normally.
`minAppVersion` is not enforced by anything. Shared-ride and service-area settings
are [listed below](#configapp--shared-rides-and-the-service-area).

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
retention both work. Create is refused once `id_verified/{uid}` exists, because a
second submission would collect a government ID for no purpose.

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

The verification outcome survives in `id_verified/{uid}`; the ID does not. If the
approval trigger ever failed, the retention job writes the marker before deleting
an approved submission, so nobody is locked out of an app they were cleared to
use.

---

## `id_verified/{subjectUid}`

`{role, verifiedBy, verifiedAt}`: the fact that an ID was approved, with no ID
type, number or image path. Booking, creating a presence row and accepting a ride
all require this document, and the router sends unverified commuters and drivers
to the ID screen.

It is separate from `id_submissions` because that document is deleted after 90
days, and gating on it would lock everyone out on day 91. **Only `onIdReviewed`
and the retention job write it.** The rules refuse every client write, admins
included, so a modified app cannot verify itself. The subject and admins can read
it.

---

## `config/app` — shared rides and the service area

Two settings added on 2026-10-02, both read by the dispatch functions and the
app from the same document.

| Field | Default | What it does |
|---|---|---|
| `sharedRidesEnabled` | `true` | Whether a driver carrying a regular passenger may be offered another ride going the same way. |
| `maxSharedPassengers` | `3` | Passengers one tricycle may carry at once, the first included. Clamped to 1–5. |
| `maxDetourKm` | `1.5` | How far the trike may go out of its way for the next passenger. Clamped to 0–20. |
| `serviceArea` | — | `{label, lat, lng, radiusKm}`. A booking outside it is **flagged, not refused**. `radiusKm: 0` turns the warning off, which is the state of a chapter that has not configured one. |

**Sharing is decided server-side**, in `canShare` (functions/src/dispatch.ts),
from the rides a driver already holds. Four refusals: a special trip is the
whole tricycle and neither shares nor joins; the tricycle fills up; the new
trip has to stay within the detour budget measured against *every* passenger
aboard, not the average; and a ride without coordinates cannot be measured, so
it is not shared. The driver's app shows each ride as its own card with its own
start and finish, because they end at different places.

**The service area warns rather than fences.** A resettlement's tricycles do
leave the resettlement, and refusing those trips would turn the most useful
rides into errors. The warning tells a commuter the one thing they cannot
otherwise know: there may be no driver near that end of the trip.

---

## Removing an account

Two paths, one shape: a client deletes the one document it is allowed to
delete, and a function takes apart everything that document was attached to.
Neither cascade is reachable from a client — half of it is refused to every
client by design, and the sign-in account needs the Admin SDK.

| | Rider | Driver |
|---|---|---|
| Deleted by | the rider, from their profile — or an admin, from a ride in the history | an admin, from the panel |
| Document | `riders/{uid}` | `drivers/{email}` |
| Function | `onRiderDeleted` | `onDriverRemoved` |
| Also deleted | ID + photo, `id_verified`, notices, the sign-in account | the same, plus the presence row |
| Live ride | cancelled | cancelled; an open offer is released |
| Rides | kept, commuter anonymised | kept, driver's phone cleared |

An admin may delete `riders/{uid}` but still cannot `get` or `list` one. The
grant is deliberately that narrow: a chapter has to be able to remove an
account used to harass drivers, and a ride is where such an account is already
identified — so the power is to erase a commuter named on a ride, never to
browse the people who use the app.

A finished ride survives either removal. It is the TODA's record of service —
who drove, which tricycle, when, what it was rated — and the personal details
that go are the ones whose purpose ended with the trip: the commuter's
identity in one case, the driver's phone number in the other.

`onDriverRemoved` also handles what the person was attached to at that second:
a ride under way is cancelled (which tells the commuter to rebook), and an
open offer is released so dispatch moves to the next nearest driver. The
sign-in account is kept in one case only — when the same address is also an
admin, since deleting it would lock the chapter out of its own panel.

---

## `notifications/{ownerUid}/items/{noticeId}`

In-app notices. One document per thing the system has told somebody, under
the uid of the person it was told to.

| Field | Type | Notes |
|---|---|---|
| `type` | string | What the notice is about — `account_approved` today. The app renders its own wording from this. |
| `title` | string | The server's English wording. Shown by a build that does not know `type`, and carried by the push. |
| `body` | string | As above. `"Your account has been approved by the admin. You can now log in."` |
| `createdAt` | timestamp | Server time. The screen sorts on it. |
| `readAt` | timestamp \| null | Null until the owner opens it. The unread count is exactly the notices with null here. |

**Written only by Cloud Functions.** A client able to create one could say
anything in the app's own voice — *"send your ID again to this number"* — and
the entire worth of a notice is that the system said it. Not even an admin
writes one: an admin's power is to approve a driver, and `onDriverApproved`
turns that into this. The owner's single power is to set `readAt`, and the
rules admit that field and no other.

**Under the uid, not keyed by it.** A flat collection with an `ownerUid` field
would need every query to carry a matching `where` clause for the rules to
admit it. Nested, the rule is a comparison on the path: a query for somebody
else's notices cannot be written in the first place.

**The document is the notice; the push is a convenience.** A driver is
approved hours or days after registering, with the app closed and — since
they have never been able to go online — usually no FCM token stored at all.
The push is sent when there is a token and forgotten when there is not; the
document waits.

**One notice per driver per approval.** The document ID is the type, so a
retried delivery of the same event rewrites the same row instead of stacking
a second. A suspension followed by a re-approval replaces it, unread again,
because that is genuinely new.

---

## Cloud Functions

All run in `asia-southeast1`, from `functions/src/`. The Admin SDK bypasses the
security rules, so these are the only writers of `dispatch`, `id_verified`,
`notifications` and the rating counters.

| Function | Runs | What it does |
|---|---|---|
| `dispatchOnBooking` | ride created | Offers a new booking straight away |
| `advanceDispatch` | ride updated | Moves to the next driver when an offer is declined or lapses |
| `requestDispatch` | callable, App Check enforced | The commuter's app asks for its own ride to be advanced; replies with an outcome word only |
| `sweepStaleRides` | every minute | Safety net: advances or expires searching rides that the others missed |
| `onRideOffered` | ride updated | Pushes the offer to the driver |
| `onRideStatusChanged` | ride updated | Pushes accepted, in transit and completed to the commuter |
| `onRideRated` | ride updated | Adds a rating to the driver's counters, once |
| `onDriverApproved` | driver updated | Writes the approval notice and pushes it |
| `onIdReviewed` | ID submission updated | Writes `id_verified/{uid}` on approval |
| `purgeExpiredIds` | daily, 03:15 Manila time | Deletes ID submissions and images after 90 days |
| `rememberDevice` | callable, signed-in commuter | Remembers this phone for sign-in without a code |
| `signInWithDevice` | callable, signed out, no App Check | Exchanges a remembered phone's secret for a sign-in token |
| `onDriverRemoved` | driver deleted | Cleans up the account and any live ride or offer |
| `onRiderDeleted` | rider deleted | Cleans up the account, cancels any live ride and anonymises past rides |

Each event can be delivered more than once, so offers are written with a
transaction that stands down if `offerSeq` has moved (`commitIfUnchanged`).

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
| `active_drivers` | `isOnline`, `availability`, `position.geohash` | the geohash range query kept for a larger fleet; current dispatch does not use it |
| `drivers` | `status`, `createdAt ↑` | admin verification queue, oldest first |
| `feedback` | `resolved`, `createdAt ↓` | admin feedback queue |
| `id_submissions` | `status`, `submittedAt ↑` | admin ID review queue, oldest first |

`notifications/{uid}/items` needs no entry: ordering one collection by one
field is served by the single-field index Firestore builds by default.

The `fieldOverrides` entries switch **off** indexing for `position.geopoint`,
`active_drivers.updatedAt`, `driverLocation` and `driverLocationAt`. Those fields are
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
| A driver's approval is not re-checked on every GPS ping, so a suspended driver can stay in the index. | One `get()` per ping, per driver, is a real and recurring cost. | Dispatch offers rides only to approved drivers, and the rules re-check approval at acceptance. To remove suspended drivers from the index immediately, put `approved` in a custom auth claim and check `request.auth.token.role`. |
| A driver's number is not verified, so it can reserve someone else's number. | Drivers sign in by email and receive no code. | Verify driver numbers by SMS at registration. |
| `minAppVersion` is not enforced, so a broken build cannot be forced out of circulation. | There is no version gate in the app. | Add a gate that compares the running version with `config/app`. Until then, `acceptingRides` stops bookings while a new APK is distributed. |
