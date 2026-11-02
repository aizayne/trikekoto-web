# TrikeKoTo

The Flutter app for commuters, drivers and admins, with its Cloud Functions,
security rules and documentation. The React app at the repo root is the legacy
web build.

```
trikekoto_app/
├── lib/
│   ├── core/                      auth, routing, Firestore refs, maps, theme
│   ├── features/                  admin, commuter, drivers, feedback, identity,
│   │                              landing, notifications, rides
│   └── l10n/                      Filipino and English strings
├── functions/src/                 dispatch, pushes, ratings, ID retention, removal
├── firestore.rules                security rules (v2)
├── storage.rules                  profile photos and government IDs
├── firestore.indexes.json         composite indexes + GPS field exclusions
├── firebase.json                  rules + indexes + functions + emulator ports
├── SCHEMA.md                      field reference and design rationale
├── test/                          Dart unit and widget tests
├── test_rules/                    rules tests against the emulator
├── scripts/                       verification, seeding, release and document tools
└── docs/                          runbook, user guides, pilot and UAT material
```

---

## Step by step

### 1. Enable the auth providers

Firebase Console → Authentication → Sign-in method:

- **Phone** — commuters. Every commuter verifies a number before booking;
  `hasVerifiedPhone()` in the rules refuses a ride creation without one.
- **Email/Password** — drivers and admins.
- **Anonymous** — no longer used. The provider can stay off.

> ### Phone sign-in requires the Blaze plan
>
> Not a cost concern — a hard requirement. On the free plan phone verification
> fails with **"billing not enabled"**, and because accounts are mandatory,
> no commuter can use the app at all until billing is on.
>
> **Blaze is enabled on `trikekoto`.** It was the same wall as Cloud Functions
> (step 65) and Cloud Storage, and enabling it cleared all three.
>
> Anyone standing this project up on a fresh project hits the same wall and
> needs the same fix. See **Set a budget alert** below before doing anything
> else with it.

### 1b. Set a budget alert

**Done on `trikekoto`: ₱500/month, scoped to this project, email alerts.**

Blaze bills past the free quotas with no ceiling. At pilot scale the real cost
is close to nothing — see [COST_AND_PERFORMANCE.md](COST_AND_PERFORMANCE.md) —
but "close to nothing" is a projection, and a runaway loop or a leaked API key
does not respect projections.

Google Cloud Console → Billing → Budgets & alerts → **Create budget**:

- Scope: the `trikekoto` project only, not "All projects"
- Amount: **₱500/month** is well above the modelled pilot cost, so a trip
  means something is wrong rather than merely busy
- Alerts at 25%, 50%, 90%, 100%, emailed to the billing account owner

Email alerts need no Pub/Sub topic.

> **A budget alerts. It does not cap.** Nothing stops when the number is hit;
> Google offers no hard spending limit on Blaze. The actual stop is the pilot
> switch — setting `config/app.acceptingRides` to `false` refuses every new
> ride at the rules layer, so it holds even against a modified client.
>
> If an alert ever fires: **flip that switch first, investigate second.** See
> [docs/RUNBOOK.md](docs/RUNBOOK.md).

### 2. Point the CLI at your project

```bash
firebase use --add
```

### 3. Deploy rules and indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Composite indexes take a few minutes to build. Queries against them fail with a
console link until they finish — that link is not an error to fix, just a
progress indicator.

### 4. Create the first admin

No client path can create one, by design.

1. Authentication → Add user, then **verify the address**. `isAdmin()` requires
   `email_verified`, so an unverified admin is locked out of their own panel.
2. Firestore → collection `admins`, document ID = the **lowercased** email,
   fields `email`, `displayName`, `createdAt`.

### 5. Seed the runtime config

Collection `config`, document `app`:

```json
{
  "searchRadiusKm": 5,
  "offerTimeoutSeconds": 15,
  "maxDriversToTry": 10,
  "acceptingRides": true,
  "minAppVersion": "1.0.0"
}
```

Dispatch reads these at runtime, so tuning the search does not mean rebuilding
and redistributing the APK.

`acceptingRides` is the **pilot stop button**, enforced by the security rules
rather than the app: setting it to `false` halts new bookings on every phone
within seconds, while rides already in progress finish normally. Flip it from
**Admin → Dispatch**. Omitting it means open — a project that has not
been seeded must still work. See [pilot-plan.md](docs/pilot-plan.md).

> `minAppVersion` is seeded here by convention but **nothing enforces it**.
> There is no version gate in the app, so a broken build cannot be forced out
> of circulation — you can only stop bookings and redistribute.

Shared-ride and service-area settings live in the same document; see
[SCHEMA.md](SCHEMA.md).

### 6. Deploy the Cloud Functions

```bash
firebase deploy --only functions
```

These run dispatch, so no ride is offered to a driver until they are deployed.
See the function list in [SCHEMA.md](SCHEMA.md#cloud-functions).

### 7. Connect Flutter to the project

Dependencies are in `pubspec.yaml`.

```bash
flutter pub get
flutterfire configure
```

In the app, the driver's offer inbox, the admin queues and other screens go
through `FirestoreRefs` (`lib/core/firestore/firestore_refs.dart`) rather than
building queries inline. The queries there are the ones the rules allow and the
indexes cover.

### 8. Run the rules tests

```bash
cd test_rules
npm install
npm test
```

`npm test` boots the Firestore and Auth emulators, runs the suite, and shuts
them down.

> **Java 21+ required.** Current `firebase-tools` refuses to start the emulator
> on anything older. `test_rules/package.json` pins `firebase-tools@13` as a
> local devDependency, which still accepts Java 17 — the npm script resolves
> that local copy ahead of any globally installed CLI. If you are on Java 21 or
> newer you can drop the pin and use your global install.

---

## Verify everything

```bash
bash scripts/verify.sh
```

Runs all four checks CI runs — analyze, the Dart tests, the rules tests, and the
functions typecheck — and applies the `TEMP=C:\Temp` workaround automatically on
Windows.

The functions' own tests, including the dispatch ranking, are not part of this
or of CI. Run them separately when you change a function:

```bash
cd functions
npm test
```

Every check runs even after one fails, so a broken run tells you everything
that is wrong rather than the first thing. The summary at the end is the part
to read; failures exit non-zero.

Run it before deploying rules and before building an APK you intend to hand to
anyone. The rules suite in particular is the only thing standing between a
rules edit and a production data leak, and it was previously the easiest of the
four to skip — it lives in a different directory, needs `npm`, and dies with an
unrelated-looking error unless `TEMP` is set first.

---

## Continuous integration

[`.github/workflows/trikekoto-app.yml`](../.github/workflows/trikekoto-app.yml)
runs on every push and pull request that touches `trikekoto_app/`:

| Job | What it guards |
|---|---|
| **analyze** | `flutter analyze --fatal-infos` and the Dart tests |
| **rules** | Firestore emulator tests — rules, lifecycle, adversarial |
| **functions** | `tsc --noEmit` on the Cloud Functions; their tests do not run here |
| **build** | Release APK, uploaded as an artifact for 30 days |

The **rules** job matters most. Those tests are what stands between a rules
edit and a production data leak, and they cannot run on a Windows machine here
without the `TEMP=C:\Temp` workaround for a broken AF_UNIX socket. On the
Linux runner they simply run, which makes CI a more reliable place to execute
them than a laptop.

The **functions** job catches a function that no longer compiles against a schema
change. It does not run their tests.

`build` depends on `analyze` and `rules`, so a broken ruleset never produces a
downloadable APK. It does not depend on `functions`.

### Versioning

`version:` in `pubspec.yaml` carries the semantic version — `1.0.0+1`. The
build number is **overridden in CI** with the workflow run number:

```
flutter build apk --release --build-number=${{ github.run_number }}
```

Run numbers only ever increase, which is what Android requires: an update
whose `versionCode` went down is refused at install — but an equal one
installs silently over the old build, which is how an outdated APK once sat
on a test phone looking identical to the new one. Hand-maintained build
numbers eventually collide, usually when two people build the same release.

Bump the semantic version by hand in `pubspec.yaml` when the release warrants
it; leave the build number alone.

---

## Web build

```bash
flutter build web --release
```

An earlier build was checked against the live Firebase project, before commuter
accounts existed. Commuters on web now sign in with a phone number like everyone
else, so check that flow on the current build before relying on it.

### What does not work on web, and why

| | On web |
|---|---|
| **Crashlytics** | No web implementation at all. Guarded in `crash_reporter.dart`; web errors go to the browser console instead |
| **Push notifications** | Would need a service worker and a VAPID key. `onBackgroundMessage` is skipped on web |
| **Map tile cache** | `path_provider` has no web implementation, so every tile is fetched. Caught at startup and logged; the map still works |
| **Background GPS** | A browser tab cannot stream location while backgrounded |

The first of those was not a limitation but a **bug**: `CrashReporter.install()`
runs before `runApp`, and on web it threw, so the entire app rendered a blank
page. It compiled and would have deployed perfectly while being completely
broken — which is exactly why "the web build compiles" was never evidence that
it worked.

### Web is for commuters, not drivers

Because a browser tab cannot track location in the background and cannot
receive a push reliably, **the web build cannot serve drivers**. A driver needs
the APK. Plan web access as a commuter-only channel — which is also what makes
it the answer for iPhone users, since commuters only need the app in the
foreground while they book.

### Deploying it

This `firebase.json` has a `hosting` block serving `build/web`, so **a plain
`firebase deploy` from this directory replaces the live site**. Deploy rules or
functions with `--only`.

Hosting serves the web app and the APK download together, so publish them
together. After adding a plugin, run `flutter clean` first, which also deletes
the APK, so build both afterwards. Run these from Git Bash:

```bash
flutter build apk --release --build-name=<version> --build-number=<code>
flutter build web --release --build-name=<version> --build-number=<code>
bash scripts/stage_apk.sh
firebase deploy --only hosting
```

The order matters, because `flutter build web` rewrites `build/web` and would
remove an APK staged before it. The download is at
`https://trikekoto.web.app/download/trikekoto.apk`, and
[`docs/trikekoto-apk-qr.png`](docs/trikekoto-apk-qr.png) is a QR code for that
link. The link does not change between releases, so neither does the QR code.

The rewrite to `index.html` matters: GoRouter uses real paths, so without it a refresh on
`/driver` returns a 404 from Hosting rather than reaching the app.

A new Hosting domain must also be added under **Authentication → Settings →
Authorized domains**, or sign-in fails with `auth/unauthorized-domain` on the
live site while working perfectly on localhost.

---

## Release signing

The release key already exists at `trikekoto-release.jks`; see
[RUNBOOK.md](docs/RUNBOOK.md#backing-up-the-release-keystore) for how to back it
up. These steps are for a new checkout or project with no key.

**1. Create the keystore.** Run this from `trikekoto_app/`:

```bash
bash scripts/make-keystore.sh
```

It asks for a password, creates `trikekoto-release.jks`, writes
`android/key.properties` to match, and reads the certificate back to confirm
it worked. Both files are gitignored.

The password is read from your terminal and handed to `keytool` through the
environment — never as a command-line argument, which would put it in your
shell history and the process list. Run it yourself; nobody else should know
this password.

It refuses to overwrite an existing keystore. Replacing one that has already
signed an installed APK means every device holding that APK must uninstall and
reinstall, so that is not something a script should make easy.

**2.** Nothing — step 1 wrote `android/key.properties` for you.

**3. Build.** `flutter build apk --release` now signs with your key. Confirm:

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

The certificate DN should be yours, not `CN=Android Debug`.

### Why this is not automated

The signing identity is **permanent**. Android ties an installed app to the
key that signed it, so:

- **Lose the key and you can never update an installed app again.** Not
  "difficult" — impossible. Every driver would have to uninstall and reinstall,
  losing nothing but their patience and your credibility.
- **Change the key and the same thing happens.** Android refuses an update
  signed by a different identity.

So back it up somewhere that is not this repository and not only your laptop.
An offline copy is the point.

### Without a key

Builds fall back to debug signing and print a warning. Those APKs install
fine for testing on your own phone, but **must not be handed to drivers** —
they are signed with Android's shared debug key, which anyone can also sign
with, and switching later forces the uninstall-reinstall above.

CI is the same: it has no keystore, so its artifacts are test builds. Adding
one means putting the keystore and password into repository secrets, which is
worth doing only once real distribution starts.

---

## Migrating the existing web data

If the Flutter app points at the same Firebase project as the web build:

```bash
set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\serviceAccount.json
node scripts/migrate_from_web.mjs --dry-run
node scripts/migrate_from_web.mjs --commit
```

It lowercases `drivers.status`, backfills the rating counters and `uid`, and
reshapes `active_drivers.location` into `position{geohash, geopoint}`.

Existing ride documents are deliberately left alone. They have no `commuterUid`,
so under the new rules only admins can read them — which is the point: they hold
commuter names and phone numbers that were world-readable, and there is no uid
to retroactively attach them to.

---

## What changed from the web build's rules

| | Web build | Here |
|---|---|---|
| Commuter identity | none — unauthenticated writes | Phone-verified Auth uid, stored as `rides.commuterUid`, plus an approved government ID |
| `rides` read | `if true` — every commuter's name, phone, pickup and drop-off public | owner, assigned driver, offered driver, admin |
| Ride cancellation | anyone could cancel any ride | the owning commuter or the assigned driver |
| `drivers` read | `if true` — every driver's phone public | self and admin; commuter-facing fields denormalised onto the ride |
| Admin check | `exists(admins/{email})` on an **unverified** token | additionally requires `email_verified` |
| Ride acceptance | any signed-in user could claim any searching ride | only the driver currently offered it, and only if approved |
| Driver approval | admin-only via a field allowlist | unchanged — this part was already right |
| Ratings | write-once on the ride, no driver aggregate | write-once, with the driver aggregate updated only by a Cloud Function |

The admin gap is worth spelling out: Firebase email/password signup does not
prove you own the address you typed. Without `email_verified`, anyone could
register an unverified account matching a document in `admins/` and receive a
token that satisfied an email-keyed admin test — full access to the panel.

See the "Known limits" table in [SCHEMA.md](SCHEMA.md) for what is still
deliberately left open.
