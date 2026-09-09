# TrikeKoTo — Firestore backend

The data layer for the Flutter rebuild: schema, security rules, indexes, typed
Dart references, and rules tests. No UI, no dispatch algorithm — those sit on
top of this.

```
trikekoto_app/
├── firebase.json                  rules + indexes + emulator ports
├── firestore.rules                security rules (v2)
├── firestore.indexes.json         composite indexes + GPS field exclusions
├── SCHEMA.md                      field reference and design rationale
├── scripts/
│   └── migrate_from_web.mjs       one-off migration off the web build's data
├── test_rules/
│   ├── package.json
│   └── rules.test.mjs             167 rules tests against the emulator
└── lib/
    ├── core/firestore/
    │   ├── collection_paths.dart  collection names, enums, normalizeEmail()
    │   └── firestore_refs.dart    typed refs + every canonical query
    └── features/
        ├── drivers/data/driver.dart
        ├── drivers/data/active_driver.dart
        ├── rides/data/ride.dart           models + RideWrites payloads
        └── feedback/data/feedback_report.dart
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

### 6. Wire up Flutter

```yaml
dependencies:
  firebase_core: ^3.8.0
  firebase_auth: ^5.3.0
  cloud_firestore: ^5.5.0
  firebase_messaging: ^15.1.0
  flutter_riverpod: ^2.6.1
  go_router: ^14.6.0
  flutter_map: ^7.0.2
  geolocator: ^13.0.1
```

```bash
flutterfire configure
```

Then expose the refs through Riverpod:

```dart
final firestoreProvider = Provider((ref) => FirebaseFirestore.instance);

final refsProvider = Provider((ref) => FirestoreRefs(ref.watch(firestoreProvider)));
```

Everything downstream — the dispatch controller, the driver's offer inbox, the
admin queues — goes through `FirestoreRefs` rather than building queries inline.
The queries there are the ones the rules allow and the indexes cover.

### 7. Run the rules tests

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

Runs all four checks CI runs — analyze, 162 Dart tests, 167 rules tests, and the
functions typecheck — and applies the `TEMP=C:\Temp` workaround automatically on
Windows.

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
| **analyze** | `flutter analyze --fatal-infos` and 162 Dart tests |
| **rules** | 167 Firestore emulator tests — rules, lifecycle, adversarial |
| **functions** | `tsc --noEmit` on the Cloud Functions |
| **build** | Release APK, uploaded as an artifact for 30 days |

The **rules** job matters most. Those tests are what stands between a rules
edit and a production data leak, and they cannot run on a Windows machine here
without the `TEMP=C:\Temp` workaround for a broken AF_UNIX socket. On the
Linux runner they simply run, which makes CI a more reliable place to execute
them than a laptop.

The **functions** job exists because those functions cannot be deployed until
the Blaze plan is enabled. Typechecking is the only thing keeping them honest
against schema changes in the meantime.

`build` depends on `analyze` and `rules`, so a broken ruleset never produces a
downloadable APK.

### Versioning

`version:` in `pubspec.yaml` carries the semantic version — `1.0.0+1`. The
build number is **overridden in CI** with the workflow run number:

```
flutter build apk --release --build-number=${{ github.run_number }}
```

Run numbers only ever increase, which is what Android requires: an update
whose `versionCode` did not rise is refused at install. Hand-maintained build
numbers eventually collide, usually when two people build the same release.

Bump the semantic version by hand in `pubspec.yaml` when the release warrants
it; leave the build number alone.

---

## Web build

```bash
flutter build web --release
```

Verified working against the live Firebase project: the landing screen renders,
anonymous sign-in succeeds, and the commuter booking screen loads.

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

**Not wired up on purpose.** There is no `hosting` block in this
`firebase.json`, because the parent project's `firebase.json` already has one
serving the legacy React app from `dist/`. Adding a second here would mean a
plain `firebase deploy` from this directory silently replaces the live site —
a footgun aimed at whoever next deploys rules.

When you actually want the Flutter app on Hosting, decide first whether it
**replaces** the React app or runs beside it on a second Hosting site, then add
the block deliberately:

```json
"hosting": {
  "public": "build/web",
  "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
  "rewrites": [{ "source": "**", "destination": "/index.html" }]
}
```

The rewrite matters: GoRouter uses real paths, so without it a refresh on
`/driver` returns a 404 from Hosting rather than reaching the app.

Then add your Hosting domain under **Authentication → Settings → Authorized
domains**, or sign-in fails with `auth/unauthorized-domain` on the live site
while working perfectly on localhost.

---

## Release signing

Everything around signing is wired; the one step left is creating the key,
which is deliberately yours to do.

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

### Until then

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
| Commuter identity | none — unauthenticated writes | Anonymous Auth uid, stored as `rides.commuterUid` |
| `rides` read | `if true` — every commuter's name, phone, pickup and drop-off public | owner, assigned driver, offered driver, admin |
| Ride cancellation | anyone could cancel any ride | the owning commuter or the assigned driver |
| `drivers` read | `if true` — every driver's phone public | self and admin; commuter-facing fields denormalised onto the ride |
| Admin check | `exists(admins/{email})` on an **unverified** token | additionally requires `email_verified` |
| Ride acceptance | any signed-in user could claim any searching ride | only the driver currently offered it, and only if approved |
| Driver approval | admin-only via a field allowlist | unchanged — this part was already right |
| Ratings | write-once on the ride, no driver aggregate | write-once, plus a rules-verified aggregate increment |

The admin gap is worth spelling out: Firebase email/password signup does not
prove you own the address you typed. Without `email_verified`, anyone could
register an unverified account matching a document in `admins/` and receive a
token that satisfied an email-keyed admin test — full access to the panel.

See the "Known limits" table in [SCHEMA.md](SCHEMA.md) for what these rules
deliberately do **not** try to solve without Cloud Functions.
