# TrikeKoTo — Operations Runbook

For whoever keeps the service running. Written for the moment something is
wrong and you need the answer, not a tour of the architecture.

**Project:** `trikekoto` · **Region:** `asia-southeast1`
**Console:** https://console.firebase.google.com/project/trikekoto

---

## Access you need before an incident, not during one

| Thing | Where | Who should have it |
|---|---|---|
| Firebase console | Google account with project access | Maintainer + one backup |
| Admin app account | `admins/{email}` doc **and** a verified email | At least two people |
| Service-account key | Project Settings → Service Accounts | Maintainer only, never committed |
| Release keystore | Wherever you stored it | Maintainer + an offline backup |
| GitHub repo | `github.com/aizayne/trikekoto-web` | Maintainer |

> **Two admins, minimum.** Admin accounts cannot be created from inside the
> app by design. If the only admin loses access, nobody can approve a driver
> until someone runs `scripts/seed_admin.mjs` with a service-account key.

---

## Routine checks

**Daily during a pilot** — five minutes.

- Firestore usage: **writes** against the daily quota. Writes are the binding
  constraint, not reads (see `COST_AND_PERFORMANCE.md`).
- Crashlytics: any new crash cluster.
- Admin panel: the pending-verification queue, and the feedback badge.

**Weekly.**

- Ride analytics. `expired` climbing means searches are exhausting all ten
  candidates — too few drivers online, or the radius is too tight.
- Read the resolved feedback, not just the open items. Patterns show there.

**Monthly.**

- Billing against your budget alert.
- `flutter pub outdated` and `npm outdated` in `functions/` and `test_rules/`.

**Quarterly.**

- Re-run the security review (`SECURITY_REVIEW.md`) and the full test suite.
- Re-run `scripts/cost_model.py` with the real moving-fraction observed.
- Confirm the release keystore backup still exists and still opens.

---

## Incidents

Each entry is: what you'll be told → what it actually means → what to do.

### "I can't get a code" / "billing not enabled"

Every commuter signs in with a phone number, and **phone verification requires
the Blaze plan**. On the free plan it fails outright with *billing not
enabled*.

Nothing in the app can work around this — it is a Firebase platform
requirement, not a setting. Enable billing on the project. It is the same
wall as Cloud Functions and Cloud Storage, and one upgrade clears all three.

**How to recognise it:** the error carries `billing` or shows a code in
brackets on the sign-in screen. Every commuter is affected at once, on both
Android and web, while drivers and admins sign in normally — they use email.

Until billing is on, the commuter half of the service does not run.

> **Blaze is enabled on `trikekoto`,** so this should not occur. Kept because
> it can come back without any code changing: a card expiring, a payment
> failing, or billing being detached from the project. The symptom is
> identical, so check the billing account before looking anywhere else.

### "Nobody can book a ride"

Commuters tap **Book a ride** and nothing happens.

**Most likely:** Anonymous sign-in got disabled in the Firebase console.
Everything else about the app keeps working, which is what makes this
confusing — drivers and admins can still sign in.

**Check:** Authentication → Sign-in method → Anonymous shows *Enabled*.

**Confirm from the command line:**

```bash
node -e "fetch('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=AIzaSyB4dy7KIUMVC53bbCoCEBAytQDsUtiXASU',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({returnSecureToken:true})}).then(r=>r.json()).then(j=>console.log(j.error?j.error.message:'ENABLED'))"
```

`ADMIN_ONLY_OPERATION` means it is off.

### "Everything is refused" / permission-denied everywhere

**Most likely:** a security rules change went out broken.

**Roll back immediately** — the console keeps rules history:

Firestore → Rules → **History** → select the last known-good version →
**Restore**. This takes seconds and does not need a deploy.

Then, before redeploying anything:

```bash
cd trikekoto_app/test_rules && TEMP='C:\Temp' TMP='C:\Temp' npm test
```

All 91 must pass. If you are redeploying the previous web ruleset instead,
`firestore.rules.web-backup` at the repo root is the pre-rebuild version.

> **The rules are near Firestore's 1000-expression evaluation ceiling** on the
> `rides` update path. Adding a clause there can push a *legitimate* write
> over the limit, and it fails with a message that explains nothing. Never
> deploy a rules change without running the suite.

### "Writes are failing" / data stops saving

**Most likely:** the Firestore free-tier daily write quota is exhausted.

A pilot **does not fit in the free tier** — 20 drivers produce roughly 64,000
writes/day against a 20,000 allowance, and 93.5% of that is driver GPS
presence. It presents as writes being silently rejected, not as a bill.

**Fix:** enable the Blaze plan. Actual cost at pilot scale is around ₱138/month.
Set a budget alert at ₱500 when you do.

**Immediate relief without Blaze:** raise the distance filter. It is already
50 m; going to 100 m halves writes again at the cost of coarser tracking.

### "Drivers are not getting offers"

Work through in order:

1. Is the driver **Approved**? A pending or suspended driver receives nothing.
2. Is their toggle **Online**? The empty state tells them, but people miss it.
3. Is any commuter **within the search radius**? Default is 5 km. Raise it
   temporarily in **Dispatch** to test.
4. Is the commuter's app in the **foreground**? Until the Cloud Functions are
   deployed, the dispatch sweep stops when the commuter locks their screen.
   This is the single most likely cause of "I booked and nothing happened".

### "Fares look wrong"

If the trip card says **"Approximate — could not reach the route service"**,
OSRM is unreachable or rate-limiting.

The public demo server at `router.project-osrm.org` is **development-only** and
throttles. Point `routingBaseUrl` in the `config/app` document at a self-hosted
OSRM instance. No app release is needed — it is configuration.

Fares silently fall back to a padded straight-line estimate meanwhile, so this
is a degradation, not an outage.

### "The app closed"

Crashes report automatically. Firebase console → Crashlytics.

Reports carry the user's **role** and, for drivers and admins, their email.
Breadcrumbs show the sequence leading to the crash.

> Crashlytics only shows data once a **release** build crashes on a device.
> An empty dashboard is indistinguishable from "not working" — force one test
> crash on a real handset before you trust it.

### "I can't get into the admin panel"

Signs in fine, every action refused.

**Almost certainly:** the account's email address is not verified. `isAdmin()`
requires `email_verified` because Firebase email/password signup does not
prove ownership of an address.

**Fix:** run the seeding script with a service-account key present:

```bash
cd trikekoto_app/scripts && node seed_admin.mjs <email> <password>
```

It sets the flag and writes the `admins/` document.

### "There's an SMS charge I don't recognise"

**Phone sign-in is enabled on this project and nothing in the app uses it.**
An enabled SMS provider without App Check is the standard toll-fraud vector.

**Fix:** disable Phone (and Google) sign-in in Authentication → Sign-in method,
then enable App Check.

### "The emulator won't start" (development only)

`java.io.IOException: Unable to establish loopback connection`.

AF_UNIX sockets fail inside `%LOCALAPPDATA%\Temp` on the maintainer's machine.
Prefix Java-backed commands:

```bash
TEMP='C:\Temp' TMP='C:\Temp' npm test
```

`C:\Temp` must exist. Does not affect CI, which runs on Linux.

---

## Rollbacks

| What | How | Speed |
|---|---|---|
| Security rules | Console → Firestore → Rules → History → Restore | Seconds |
| Dispatch config | Admin panel → Dispatch, re-enter previous values | Seconds |
| App version | Redistribute the previous APK. **Android will refuse a lower `versionCode`** — users must uninstall first. | Slow |
| Cloud Functions | `firebase deploy --only functions` from the previous commit | Minutes |

> Config and rules roll back instantly; **app versions effectively do not.**
> That asymmetry is why anything tunable lives in `config/app`.

---

## Backups

Firestore has **no automatic backup on the free tier**, and rides are your only
record of what happened.

Manual export (needs Blaze and `gcloud`):

```bash
gcloud firestore export gs://trikekoto-backups/$(date +%Y-%m-%d) --project=trikekoto
```

Worth scheduling weekly once the pilot starts. Test a restore at least once —
an untested backup is a guess.

**What cannot be recovered by any backup:** the release keystore. Lose it and
you can never update an installed app. Keep an offline copy.

---

## Maintenance plan

**Every release**

- CI green: analyze, 95 Dart tests, 125 emulator tests, functions typecheck
- Bump the semantic version in `pubspec.yaml`; CI supplies the build number
- Rebuild and redistribute the APK

**Quarterly**

- Re-run `SECURITY_REVIEW.md` end to end
- Dependency upgrades, then the full suite
- Re-run the cost model against observed usage
- Verify the keystore backup opens

**When the fleet outgrows one chapter**

- Move `active_drivers` to Realtime Database. Firestore bills per write, RTDB
  per byte; a stream of tiny coordinates is the worst case for one and the
  natural case for the other. Removes ~94% of Firestore writes.
- Move dispatch server-side (roadmap step 67), then tighten
  `canDiscoverDrivers()` to `isAdmin()` — a one-function change the schema was
  built to allow.
- Switch geohash range queries on for the driver scan instead of a full read
  of online drivers.

**Known debt, carried deliberately**

| Item | Why it is acceptable now |
|---|---|
| Ratings can be inflated by any signed-in user | Bounded to one vote of 1–5 per write; needs a Cloud Function to close |
| Suspended drivers still publish presence | They cannot accept; re-checking costs a read per GPS ping |
| Rules near the expression ceiling | Every allowed path is tested; only denial paths hit the limit |
| Debug-signed APK | Fine for sideloading; must change before wider distribution |
| Straight-line fallback distance | Flagged in the UI when it happens |
