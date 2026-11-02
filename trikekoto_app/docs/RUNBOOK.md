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
- Confirm the release keystore backup still exists, still opens, and still
  shows the fingerprint recorded under *Backing up the release keystore*. Not
  "the file is there" — decrypt it and check.

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

### "Could not send the code [39]" / "Error code:39"

Firebase does not document this code. Reports tie it to a failed Play Integrity
check on an app not installed from the Play Store, or to Firebase's abuse limits
on sending SMS.

The app now uses the reCAPTCHA check on Android instead of Play Integrity, so a
browser tab may open briefly during sign-in. If error 39 still appears on a build
with that change:

1. Wait 15 minutes, then try a different real number. If only one number fails,
   Firebase is probably limiting that number.
2. Check Authentication → Settings → SMS region policy still allows the Philippines,
   and Authentication → Usage for the daily SMS count.
3. Check whether App Check enforcement for Authentication is on. A sideloaded APK
   may not pass Play Integrity, so enforcement could refuse the request.

### "Wrong email or password"

Firebase gives the same answer for a wrong password and for an address with no
account, on purpose. Check Authentication → Users for the address. It will be gone
if an admin removed that driver. If it is there, use **Forgot password?** on the
sign-in screen.

### "That mobile number is already used by another account"

Each number can hold one account, across drivers and commuters, so a driver cannot
also sign up as a commuter with the same number. Driver numbers are not verified,
so someone may have typed this person's number by mistake or on purpose. Check
Firestore → `phone_claims` → the number in `+63…` form to see its `uid` and `role`.
Removing that driver or commuter from the admin panel frees the number.

### "Could not confirm this phone. Use a code instead."

The remembered-phone sign-in failed, so the commuter is asked for a code instead.
That is normal after moving the account to another phone. If it happens to everyone,
check the logs:

```bash
firebase functions:log --only signInWithDevice
```

An error mentioning `signBlob` or `iam.serviceAccounts` means the function's service
account cannot create sign-in tokens. See [Enabling one account per number and
remembered phones](#enabling-one-account-per-number-and-remembered-phones).

### "Nobody can book a ride"

Work through in order:

1. **Bookings are switched off.** Check **Accepting bookings** under Admin →
   Dispatch. While it is off, the rules refuse every new ride.
2. **The commuter cannot get past the ID screen.** Booking requires an approved
   government ID. Look for their submission under Admin → ID review.
3. **Nobody can sign in with a phone number.** Check that Authentication →
   Sign-in method → Phone shows *Enabled*, then see
   ["I can't get a code"](#i-cant-get-a-code--billing-not-enabled). Drivers and
   admins can still sign in during this, because they use email.

### "Everything is refused" / permission-denied everywhere

**Most likely:** a security rules change went out broken.

**Roll back immediately** — the console keeps rules history:

Firestore → Rules → **History** → select the last known-good version →
**Restore**. This takes seconds and does not need a deploy.

Then, before redeploying anything:

```bash
cd trikekoto_app/test_rules && TEMP='C:\Temp' TMP='C:\Temp' npm test
```

Every test must pass. If you are redeploying the previous web ruleset instead,
`firestore.rules.web-backup` at the repo root is the pre-rebuild version.

> **The rules are near Firestore's 1000-expression evaluation ceiling** on the
> `rides` update path. Adding a clause there can push a *legitimate* write
> over the limit, and it fails with a message that explains nothing. Never
> deploy a rules change without running the suite.

### "Writes are failing" / data stops saving

**Most likely:** billing lapsed and the Firestore free-tier daily write quota is
exhausted. Blaze is enabled on `trikekoto`, so check the billing account first: a
card expiring or billing being detached puts the project back on the free limits.

A pilot **does not fit in the free tier** — 20 drivers produce roughly 64,000
writes/day against a 20,000 allowance, and 93.5% of that is driver GPS
presence. It presents as writes being silently rejected, not as a bill.

**Fix:** restore billing. Actual cost at pilot scale is around ₱138/month, and the
budget alert is set at ₱500.

**Immediate relief without Blaze:** raise the distance filter. It is already
50 m; going to 100 m halves writes again at the cost of coarser tracking.

### "Drivers are not getting offers"

Work through in order:

1. Is the driver **Approved**, with an approved ID? A pending or suspended driver
   receives nothing, and without an ID they cannot go online.
2. Is their toggle **Online**? The empty state tells them, but people miss it.
3. Is any commuter **within the search radius**? Default is 5 km. Raise it
   temporarily in **Dispatch** to test.
4. Are the **dispatch functions healthy**? Matching runs on the server, in
   `dispatchOnBooking`, `advanceDispatch` and `requestDispatch`. Check their logs:

   ```
   firebase functions:log --only dispatchOnBooking,advanceDispatch,requestDispatch
   ```

   If those fail, `sweepStaleRides` still does the same work every minute, so the
   symptom is **slow offers, not no offers**. If it is failing too, look at
   `config/app`: an unreachable `routingBaseUrl` does not stop dispatch, but a
   `searchRadiusKm` someone set to a tiny value does.
5. Is the **commuter** on an old APK? Their app is the one that used to do
   the matching. Builds from before step 69 still try, and the rules now
   refuse them: the commuter can still book — the sweep catches the ride —
   but they see an error toast and the driver's offer arrives up to a minute
   late. Have them reinstall from the download link.

### "The distance or route looks wrong"

The app does not quote fares, so this is about the route, not the price. If the
trip card says **"Approximate — could not reach the route service"**,
OSRM is unreachable or rate-limiting.

The public demo server at `router.project-osrm.org` is **development-only** and
throttles. Point `routingBaseUrl` in the `config/app` document at a self-hosted
OSRM instance. No app release is needed — it is configuration.

Distances fall back to a straight-line estimate meanwhile, so this is a
degradation, not an outage.

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
you can never update an installed app — every driver uninstalls, reinstalls,
and signs in again, and there is no support ticket that undoes it. Android
accepts an update only from the same signing key.

### Backing up the release keystore

**Know which file it is.** There is more than one `trikekoto-release.jks` on
the original development machine, and only one of them signs releases: the one
at `trikekoto_app/trikekoto-release.jks`. The other, under
`~/trikekoto/android/keystore/`, is left over from the pre-Flutter project and
does not even open with the current password. Backing that one up backs up
nothing.

The signing key in use is identified by this fingerprint, which matches the
signer on every released APK:

```
C1:7A:12:5E:72:C2:43:4C:28:FA:7D:03:1F:46:54:E9:53:2C:BF:5E:BF:CE:A7:DF:85:31:78:54:3D:17:EA:9F
```

Check any APK against it with:

```bash
apksigner verify --print-certs build/web/download/trikekoto.apk
```

**Three things have to survive together.** Any one of them missing makes the
other two worthless:

1. the keystore file, `trikekoto_app/trikekoto-release.jks`;
2. the store password, key password and alias, which live in
   `trikekoto_app/android/key.properties` — gitignored, and deliberately never
   committed;
3. the fingerprint above, so a restored copy can be *proven* to be the right
   one rather than assumed.

**Make one encrypted bundle**, from `trikekoto_app/`:

```bash
tar -cf - trikekoto-release.jks android/key.properties \
  | gpg -c --cipher-algo AES256 -o ~/trikekoto-keystore-backup.gpg
```

It asks for a passphrase twice. That passphrase is now exactly as important as
the keystore, so write it down somewhere that is not the same place as the
file.

**Keep copies in at least two places that cannot be lost together.** A fire, a
theft or a dead disk should never be able to take both:

- a password manager entry holding the `.gpg` as an attachment, together with
  the passphrase and the fingerprint;
- a USB stick kept somewhere physically separate from the laptop;
- optionally cloud storage, but **only** the encrypted `.gpg`, never the raw
  `.jks`.

Never in the repository, never in email or chat, never alongside the
passphrase.

**Verify the backup, because an unverified backup is a guess.** Restore it
somewhere temporary and compare the fingerprint:

```bash
cd "$(mktemp -d)" && gpg -d ~/trikekoto-keystore-backup.gpg | tar -xf - \
  && keytool -list -v -keystore trikekoto-release.jks -alias trikekoto | grep SHA256:
```

It must print the fingerprint above. Delete the temporary directory
afterwards.

**Succession.** If TrikeKoTo outlives the thesis, somebody other than the
original author has to be able to reach this key, or the app dies with the
laptop. The usual arrangement is a sealed envelope held by the department
containing the passphrase, with the encrypted bundle stored separately.
Decide this before the pilot, not after.

---

## Enabling one account per number and remembered phones

Do these in order. The new rules refuse older APKs in two ways: a booking whose
typed number differs from the verified one, and any driver or commuter sign-up.
Plan the rules deploy with the new APK's rollout.

1. **Reserve existing numbers.** Run the dry run, review any duplicates, then commit.
   It needs `scripts/service-account.json`.

   ```bash
   cd scripts
   node backfill_phone_claims.mjs
   node backfill_phone_claims.mjs --commit
   ```

2. **Let the functions create sign-in tokens.** This assumes they run as the default
   compute service account, so check that in the Cloud console first:

   ```bash
   gcloud iam service-accounts add-iam-policy-binding 877860610923-compute@developer.gserviceaccount.com --member=serviceAccount:877860610923-compute@developer.gserviceaccount.com --role=roles/iam.serviceAccountTokenCreator --project trikekoto
   ```

3. **Deploy.** Run `bash scripts/verify.sh` and `npm test` in `functions/` first.

   ```bash
   firebase deploy --only functions,firestore:rules
   ```

4. **Distribute the new APK.**

---

## Maintenance plan

**Every release**

- CI green: analyze, Dart tests, emulator tests, functions typecheck
- `npm test` in `functions/`, because CI does not run the functions' tests
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
- Switch geohash range queries on for the driver scan instead of a full read
  of online drivers.

**Known debt, carried deliberately**

| Item | Why it is acceptable now |
|---|---|
| Suspended drivers still publish presence | Dispatch skips them and they cannot accept; re-checking costs a read per GPS ping |
| Rules near the expression ceiling | Every allowed path is tested; only denial paths hit the limit |
| CI builds a debug-signed APK | Test builds only; hand out APKs signed with the release key |
| Straight-line fallback distance | Flagged in the UI when it happens |
