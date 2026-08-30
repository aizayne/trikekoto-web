# TrikeKoTo — Security Review

**Reviewed:** 24 August 2026 · **Project:** `trikekoto` · **Ruleset:** deployed
**Verification:** 102 emulator tests, 19 of them adversarial
([`test_rules/attacks.test.mjs`](test_rules/attacks.test.mjs))

Every claim below was executed against the deployed ruleset in the Firestore
emulator, not reasoned about on paper. Where a gap exists it is stated, its
blast radius bounded, and a tripwire test pins the current behaviour so it
cannot change unnoticed.

```bash
cd test_rules && TEMP='C:\Temp' TMP='C:\Temp' npm test
```

---

## Summary

| | |
|---|---|
| Critical issues | **0** |
| High | **1** — Phone auth enabled but unused |
| Medium | **3** — rating inflation, no App Check, unrestricted API key |
| Accepted by design | **3** — documented below with tripwire tests |

The two findings from the original web build — an admin gate that trusted an
unverified email claim, and world-readable ride documents carrying commuter
phone numbers — are both closed and regression-tested.

---

## What an attacker cannot do

Each of these is a passing test, not an assertion.

**Harvest personal data.** A commuter cannot read the driver roster (phones,
licence details), cannot open another commuter's ride, and cannot list the
rides collection. A driver cannot read another driver's profile, cannot open a
ride they were not offered, and cannot query for pending rides at large. An
unauthenticated client reads nothing at all.

**Escalate privilege.** No client path writes to `admins/` — the collection is
`allow write: if false`. A driver cannot approve or suspend anyone, cannot
change their own verification state, and an account whose email address was
never verified cannot exercise admin power even with an `admins/` document
present. That last one closes the escalation the web build shipped with:
Firebase email/password signup does not prove ownership of an address, so
anyone could have registered an unverified account matching a known admin
email.

**Hijack a ride.** A driver cannot accept a ride offered to someone else. A
commuter cannot reassign their own ride to a chosen driver, cannot forge a
completed status to farm a rating, and cannot rewrite the fare after the fact.
Nobody — including admins — can delete a ride, because rides are the audit
trail.

**Tamper with runtime config.** `config/app` drives the search radius and the
whole fare table for every user. Writes are admin-only.

**Extract secrets from the APK.** Scanned: no service-account files, no
private keys, no `.jks`/`.p12`. The Firebase API keys present are public
configuration by design — they identify the project, they do not authorise
anything. Authorisation rests entirely on the rules.

---

## Findings

### HIGH — Phone sign-in is enabled and unused

**[Authentication → Sign-in method](https://console.firebase.google.com/project/trikekoto/authentication/providers)**
lists **Phone** as Enabled. Nothing in the app calls it: drivers and admins use
Email/Password, commuters use Anonymous.

An enabled SMS provider with no App Check is the standard toll-fraud vector —
an attacker drives verification texts toward premium-rate numbers they control
and the cost lands on your project. This is exactly what the console's own
"protect against billing fraud" banner refers to.

**Google is also enabled and unused.** No cost attached, but it is live
attack surface for no benefit.

**Fix:** disable both unless you plan to use them. If your panel requires
phone verification as a feature, implement it *and* enable App Check first —
an enabled provider is not a security control, only a cost.

### MEDIUM — Ratings can be inflated without taking a ride

Any signed-in user can increment `ratingSum`/`ratingCount` on any driver. The
rules verify the *arithmetic* — exactly one vote, worth 1 to 5 — but cannot
tie the increment to a completed ride, because each document in a transaction
is authorised independently.

**Bounded:** one vote per write, maximum 5 stars. There is no way to write an
arbitrary total; test `rejects an inflated aggregate increment` proves a
5000-point write is refused. Inflating a reputation meaningfully would take
hundreds of scripted writes, which would be visible in usage.

**Fix — written, awaiting deployment.** `onRideRated` in
[`functions/src/index.ts`](functions/src/index.ts) derives the increment from
the ride itself, so it can only happen once, for a real completed ride, with
the rating the commuter actually gave. It is idempotent: the transaction
re-reads the ride and refuses if `ratingCounted` is already set.

**Cutover, in this order:**

1. Enable Blaze and `firebase deploy --only functions`.
2. Delete the `(isSignedIn() && validRatingIncrement())` line from the
   `drivers` update rule and redeploy rules. The exact instructions are in a
   comment beside that function in `firestore.rules`.
3. Update the two tripwire tests in `test_rules/attacks.test.mjs` that
   currently assert this gap is open.

Tightening the rules **before** the function is deployed means no rating is
ever counted. No app release is required: the client's own increment is
already best-effort and fails quietly, and the function's idempotency guard
covers older APKs still attempting it.

### MEDIUM — App Check is not enabled

Nothing distinguishes the real APK from a script holding the same public API
key. App Check would attest that requests originate from your genuine app via
Play Integrity.

Without it, every "any signed-in user" gap above is reachable by a script
rather than requiring a modified client. This is the single highest-leverage
hardening step available, and it is free.

### MEDIUM — API key restrictions not applied

The Android and Web API keys are unrestricted in Google Cloud. Restricting the
Android key to your package name and SHA-1, and the Web key to your hosting
domain, limits reuse of the key elsewhere. This matters more once a release
keystore exists (step 81), since the SHA-1 changes with it.

---

## Accepted by design

Each has a tripwire test that fails if the behaviour changes.

**Online driver emails are enumerable by any signed-in user.** The greedy
match runs on the commuter's device, so it must query `active_drivers`. That
document deliberately carries *no* name, phone, plate, or rating — an email
address and a coordinate is the entire exposure, and the test asserts those
fields stay absent. Closing this means moving dispatch server-side (step 67),
after which `canDiscoverDrivers()` becomes `isAdmin()` — a one-function change
the schema was built to allow.

**A suspended driver can still publish presence.** Approval is not re-checked
on every GPS ping, because that would cost one document read per ping per
driver every few seconds. A suspended driver appears in the dispatch index but
**cannot accept anything** — the gate sits at ride acceptance, which is the
write that matters. Tested both halves.

**Commuter PII lives on the ride document.** Name and phone are readable by
the assigned driver and by any driver currently offered the ride. That is the
point — a driver needs to call their passenger. Exposure is limited to drivers
the dispatch loop actually pinged, and the ride is unreadable to everyone else.

---

## Fragility worth watching

The `rides` update rule is a chain of eight clauses and reaches Firestore's
**1000-expression evaluation ceiling** on full-denial paths. When the budget
is exhausted the rule returns *deny*, which is the correct answer for a write
that should fail — but a legitimate write whose matching clause sits late in
the chain would be refused with an error message that explains nothing.

Every allowed transition has a passing test, including an explicit one for the
admin override that sits last. **Adding another clause to that rule could push
a legitimate path over the limit**, so any change there needs the suite run
before deploying.

---

## Recommended order

1. **Disable Phone and Google sign-in** — one click, removes a live cost risk
2. **Enable App Check** — free, and closes the "script vs real app" gap
3. **Restrict API keys** — after the release keystore exists
4. **Blaze plan** → server-side rating aggregation (68) and dispatch (67)
5. Re-run this review after any rules change

---

## Not covered

- **Penetration testing of the deployed project.** Everything here ran against
  the emulator with the same ruleset. Rules behaviour is identical; quotas,
  App Check enforcement, and key restrictions are not exercised.
- **The Cloud Functions.** Written and typechecked but not deployed, so their
  runtime behaviour is unreviewed.
- **Device-level threats.** A rooted phone can read its own app storage; no
  mitigation is attempted and none is warranted at this scale.
