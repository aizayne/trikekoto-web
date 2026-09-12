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
| Medium | **0** — key restrictions applied; see the caveat on what they actually enforce |
| New surface | **1** — government ID collection, added deliberately; see below |
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

### ~~MEDIUM — API key restrictions not applied~~ — APPLIED, WITH A CAVEAT

Both keys now carry application restrictions: the web key to
`trikekoto.web.app`, `trikekoto.firebaseapp.com` and `localhost`; the Android
key to `ph.trikekoto.trikekoto_app` with the release certificate's SHA-1
(`06:2A:…:94:6D`). API restrictions were already in place — Firebase sets them
when it mints the keys.

**A note on what this actually buys, because the common advice oversells it.**
The restrictions were verified working in the direction that matters: the web
key is accepted from `trikekoto.web.app`. But the same key, complete and
correct, was *also* accepted from `https://example.com` — tested against
Identity Toolkit, Firestore and Firebase Installations, none of which refused
it on referrer grounds, several minutes after the restriction was confirmed
saved in the console.

So for these Firebase endpoints the referrer restriction should be treated as
defence in depth, not as a control that prevents key reuse. That is consistent
with Google's own position that a Firebase API key identifies a project rather
than authorising access, and that access is controlled by Security Rules.

**The control that does hold is App Check enforcement**, which was verified end
to end: a request without a valid attestation token is refused regardless of
which origin it comes from. If a claim about key security appears in the
thesis, it should rest on App Check and the Security Rules rather than on
these restrictions.

A misleading label is worth recording too: Google Cloud lists the key the
**Android** app uses under the name *"Browser key"*, because `flutterfire
configure` reused the project's earliest key rather than minting a new one.
Restricting by the console's row name rather than by the key value would have
broken Android.

---

## New surface — government ID verification

Added after this review was written, at the project owner's decision and
against my recommendation, which was drivers only. Recording that here because
a reviewer should know the trade was made knowingly rather than by default.

**What changed.** The system previously held a name, a phone number and an
optional selfie. It now holds government ID images and numbers for both
drivers and commuters — **sensitive personal information under RA 10173**,
a category it did not previously touch at all.

**Why this is a step change, not an increment.** A breach of the old data set
exposes contact details. A breach of this one exposes identity documents,
which are reusable against the person elsewhere. The obligations differ too:
lawful basis, documented consent, retention limits, and breach notification
all attach.

**Controls built for it.**

| | |
|---|---|
| Isolation | Its own collection and Storage path, so `riders` keeps `list: false` and a mistake here reaches nothing else |
| No URLs | The image is never given a download URL; reviewers read bytes, checked against the rules every call |
| Consent | A blocking checkbox with the terms on screen, and a server timestamp the rules require and refuse to back-date |
| Least privilege | Read is subject or verified admin only — explicitly not the driver a commuter rides with |
| No self-approval | `status` forced to `pending` on create; only an admin may move it, only once, and never while altering the submission |
| Withdrawal | The subject can delete their own document and image, without asking |
| Coverage | 30 emulator tests and 18 unit tests, written before the UI existed |
| Retention | `purgeExpiredIds`, daily, 90 days from submission — enforced, not documented |

**What is not done, and should be before real collection begins.**

- ~~**No scheduled deletion.**~~ **Done.** `purgeExpiredIds` runs daily and
  deletes submissions 90 days after they arrive, image first. Retention that
  depends on someone remembering is not retention, it is an intention.
- **No privacy notice outside the app.** The consent text is in the app; a
  thesis pilot collecting from real people should have one their adviser and
  the TODA chapter have seen.
- **Not reviewed by anyone qualified.** I am not a lawyer and this is not
  legal advice. PRMSU will likely have an ethics review process; this belongs
  in it before a single real ID is collected.
- **It is now required, and that changes the consent question.** Since
  2026-09-13 an approved ID is a precondition of use: the rules refuse a ride
  from, and presence or acceptance by, anyone without an `id_verified`
  marker. The owner chose this deliberately, for scam and troll protection.
  The cost is on the legal side. RA 10173 wants consent to be *freely given*,
  and consent that is a condition of using a service is weaker than consent
  to an optional feature. The checkbox on the ID screen is still worth
  having, but it can no longer carry the justification alone; the honest
  basis is closer to the service's legitimate interest in knowing who is
  getting into whose tricycle. Defensible — and exactly the argument an
  ethics review should see written down before a single real ID is collected.
- **Every new user now waits for a human.** Nobody's first ride can happen
  until a TODA officer approves an ID. One admin, asleep, is a service that
  cannot onboard anyone until morning. Decide before the pilot who reviews,
  and how quickly.
- **The marker outlives the ID, by design.** `id_verified/{uid}` holds no ID
  type, number or image — only that approval happened, by whom, and when. It
  is what lets retention delete the ID at 90 days without un-verifying the
  person, and it is removed when the account is.

---

## Closed

**Online driver emails were enumerable by any signed-in user** until step 69.
The greedy match ran on the commuter's device, so it had to query
`active_drivers`, so `canDiscoverDrivers()` had to admit every signed-in
account. The exposure was deliberately thin — an email and a coordinate, no
name, phone, plate or rating — but it was a live fleet tracker available to
anyone willing to verify a phone number, and it needed no booking to use.

The match moved into the `requestDispatch` callable, which reads the index
with admin credentials and replies with one word: `offered`, `waiting`,
`held`, `expired` or `skipped`. No driver, no distance, no count. The rule is
now `isAdmin()`, leaving the TODA officer's shift board as the only
client-side reader.

Two tests hold the line — one asserting a commuter is refused both the query
and the single-document read, one asserting an admin still gets the board.
The second matters as much as the first: closing a gap by blinding the person
whose job needs the data is not a fix.

---

## Accepted by design

Each has a tripwire test that fails if the behaviour changes.

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
4. ~~**Restrict API keys**~~ — applied to both keys. Read the caveat in that
   section before relying on them: they were not observed to block a foreign
   origin on the Firebase endpoints tested.
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
