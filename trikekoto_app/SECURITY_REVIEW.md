# TrikeKoTo — Security Review

**Reviewed:** 24 August 2026 · **Project:** `trikekoto` · **Ruleset:** deployed
**Verification:** 125 emulator tests, 19 of them adversarial
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
| High | **0** — the SMS toll-fraud finding is closed; App Check is enforced on both platforms |
| Medium | **1** — unrestricted API key |
| Closed since this review | **1** — rating inflation, by the step 68 cutover |
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

### ~~HIGH — SMS toll fraud through phone sign-in~~ — CLOSED

**Originally written as "Phone sign-in is enabled and unused", with the fix
being to disable it. That fix is now impossible and the finding is worse.**

Phone verification is how every commuter authenticates — accounts are
mandatory on every platform — so the provider cannot be turned off. Two things
changed the risk since this review was written:

1. It went from **unused** to **load-bearing**.
2. Blaze was enabled, so abuse now **bills** instead of being refused.

The attack is the standard one: drive verification texts at premium-rate
numbers the attacker controls and collect a cut of the termination fee. The
web build is the exposed surface — `https://trikekoto.web.app` is public, and
anyone with the link can make the project send SMS.

**Mitigations in place**

| | |
|---|---|
| SMS region policy | **Allowlist, Philippines only.** Removes essentially all the profit — the expensive destinations are unreachable. Costs nothing in legitimate reach: every user of a Zambales tricycle service has a `+63` number. |
| App Check (Android) | Play Integrity, attesting the real APK. |
| App Check (web) | **reCAPTCHA Enterprise, enforced.** |
| Budget alert | ₱500/month. Detection, not prevention — it fires after the money is spent. |

**Closed.** App Check is now *enforced*, not merely activated — the distinction
that matters. Activated means a token is offered; enforced means Firebase
refuses the request without one. Until enforcement was switched on, a script
could ignore App Check entirely and still be served.

Enterprise rather than the classic v3 provider, because Firebase deprecated
plain reCAPTCHA for App Check. Its free tier is 10,000 assessments a month,
which one TODA chapter will not approach.

Verified end to end rather than assumed: the deployed page loads
`enterprise.js` and defines `grecaptcha.enterprise`, and after enforcement was
switched on a real number still received a real code and reached the booking
screen. That second half is the one that matters — enforcing against a build
whose tokens are rejected takes the whole web app down at once, and the only
proof it has not is a working sign-in.

Residual risk: someone holding a genuine attested client can still request
codes. Bounded by the region allowlist and Firebase's own per-number rate
limits, and visible through the budget alert.

~~**Google sign-in is also enabled and unused.**~~ **Disabled.** It carried no
cost, but it was live attack surface for no benefit. That half of the original
recommendation survived the rewrite intact and has been actioned.

### ~~MEDIUM — Ratings can be inflated without taking a ride~~ — CLOSED

Any signed-in user could increment `ratingSum`/`ratingCount` on any driver.
The rules verified the *arithmetic* — exactly one vote, worth 1 to 5 — but
could not tie the increment to a completed ride, because each document in a
transaction is authorised independently.

**Closed by the step 68 cutover.** `onRideRated` in
[`functions/src/index.ts`](functions/src/index.ts) is deployed and owns the
aggregate: it derives the increment from the ride itself, so it can only
happen once, for a real completed ride, with the rating the commuter actually
gave. It writes through the Admin SDK, which bypasses the rules. The
`validRatingIncrement()` clause is gone from `firestore.rules`, so no client
write of those fields is admitted at all — well-formed or not.

The tripwire that asserted the gap was open is now an assertion that it is
shut, in `attacks.test.mjs`, alongside a new case covering a driver inflating
their own rating.

> **A note on the window between the two steps.** The order was: deploy the
> function, *then* delete the rule. Reversing it means no rating is counted at
> all. But leaving both in place — which is the state that existed between the
> two deploys — means **every rating counts twice**: the function's
> `ratingCounted` guard stops it re-running, and cannot see a client
> increment at all. If a rating was cast in that window, its driver's
> aggregate is double. Nothing rated during it here, because no commuter could
> sign in yet.

No app release was required. The client's increment is best-effort inside a
try/catch that records a non-fatal and stays silent, so installed APKs now
fail that write invisibly while their rating still lands on the ride.

### ~~MEDIUM — App Check is not enabled~~ — CLOSED

Nothing distinguished the real APK from a script holding the same public API
key, and every "any signed-in user" gap below was therefore reachable by a
script rather than requiring a modified client.

Both platforms now attest and both are enforced: Play Integrity on Android,
reCAPTCHA Enterprise on web. The remaining gaps still exist, but reaching them
now requires a genuine build of this app rather than a shell script.

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

1. ~~**Disable Phone and Google sign-in**~~ — **resolved, in two different
   ways.** Google sign-in: disabled. Phone sign-in: cannot be disabled, since
   it is how every commuter authenticates — mitigated instead with an SMS
   region allowlist (Philippines only).
2. ~~**App Check on web**~~ — done. reCAPTCHA Enterprise, wired and
   **enforced**, verified by a real sign-in after enforcement was switched on.
3. ~~**A budget alert**~~ — done, ₱500/month scoped to the project.
4. **Restrict API keys** — the release keystore now exists, so this is
   unblocked.
5. ~~**Blaze plan** → server-side rating aggregation (68) and dispatch (67)~~
   — done. Both functions are deployed.
6. Re-run this review after any rules change. **It is due one now:** the rider
   collection, mandatory accounts, and the rating cutover all postdate it.

---

## Not covered

- **Penetration testing of the deployed project.** Everything here ran against
  the emulator with the same ruleset. Rules behaviour is identical; quotas,
  App Check enforcement, and key restrictions are not exercised.
- **The Cloud Functions.** Written and typechecked but not deployed, so their
  runtime behaviour is unreviewed.
- **Device-level threats.** A rooted phone can read its own app storage; no
  mitigation is attempted and none is warranted at this scale.
