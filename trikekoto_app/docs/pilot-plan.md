# TrikeKoTo — Pilot Rollout Plan

Roadmap step 89. One TODA chapter, monitored daily, with a rollback plan.

Depends on step 78 (UAT) and step 85 (crash monitoring). In practice it also
needs Blaze, a real keystore, and a passing end-to-end run — see
[RUNBOOK.md](RUNBOOK.md) for what to do when something breaks.

---

## The rollback problem, and what was done about it

An APK handed around over Wi-Fi cannot be recalled. There is no store listing to
unpublish, no remote uninstall, and no way to make a driver's phone forget an
app. Before this plan existed, "rollback" meant messaging fifteen people and
hoping.

So there is now a **server-side stop button**: `config/app.acceptingRides`.

- Flip it in **Admin → Dispatch**. One switch, saves immediately, no
  Save button to remember.
- The **security rules** enforce it, not the app. A modified or stale client
  cannot book while it is false, because the server refuses the write.
- Takes effect on every phone **within seconds**, with no app update.
- Scoped to ride *creation* only. **Rides already in progress finish normally** —
  pressing stop never strands a passenger sitting in a tricycle.

That is the real rollback. Everything below assumes it exists.

### What it is not

It does not stop drivers publishing GPS presence, and it does not sign anyone
out. It stops new bookings. That is the blast radius you want: the system goes
quiet without anything appearing broken mid-trip.

### The other levers

| Lever | Where | Effect |
|---|---|---|
| `acceptingRides` | Admin panel | Halts new bookings. **The stop button** |
| `searchRadiusKm` | Admin panel | Widen if rides expire; narrow if drivers are pulled too far |
| `offerTimeoutSeconds` | Admin panel | Raise if drivers cannot answer in time |
| `maxDriversToTry` | Admin panel | Capped at 10 by the rules; minimum 1 |
| Rules redeploy | `firebase deploy --only firestore:rules` | Nuclear. Seconds to take effect |

**`minAppVersion` is seeded and documented but enforced nowhere.** There is no
version gate in the app. If you ship a broken build you cannot force an update —
you can only stop bookings and re-distribute. Worth knowing before you rely on
it; worth building before a second chapter.

---

## Scope

**One chapter. Eight to twelve drivers. Two weeks.**

Resist adding a second chapter until the first has run a full week without an
unplanned stop. Two chapters double the drivers, the coordination, and the
number of people who need telling when something changes — while roughly
doubling the information you get, which is a bad trade at this stage.

### Entry criteria — all of them, before day 1

- [ ] End-to-end run passed on real hardware (step 75)
- [ ] UAT complete, no blockers outstanding (step 78)
- [ ] Blaze enabled with a **budget alert**, functions deployed
- [ ] Push notifications confirmed working on a backgrounded phone
- [ ] APK signed with the real keystore, **and the keystore backed up offline**
- [ ] Admin account created and email verified
- [ ] `config/app` seeded (search radius, offer timeout, drivers to try)
- [ ] Crashlytics receiving a deliberately triggered test crash
- [ ] Every driver has the [driver guide](driver-guide.md) and a way to reach you

The Crashlytics check matters more than it looks. Reporting is off in debug
builds, so it is entirely possible to reach day 1 having never confirmed a
single report arrives.

---

## Day 0 — the briefing

Do this in person, at the terminal, with the drivers who will actually use it.

1. Install the APK on each phone yourself. Watch the permission prompts.
2. Register each driver, then approve them from the admin panel while they
   watch — the banner flipping to verified is what makes it feel real.
3. Have every driver complete **one practice ride** with you as the commuter.
4. Give them the stop signal: what you will say, and where, if you halt the
   pilot. A group chat that everyone is already in beats anything new.
5. Tell them plainly: **the app shows no fares at all. Payment is the posted
   tariff, in cash, exactly as before.**

Then agree the one thing that will decide whether this works — **that they keep
the app running during their shift** — and find out what that costs them in
battery. Ask on day 2, not at the end.

---

## Daily monitoring

Fifteen minutes, same time each day. The admin panel's **Today** window is built
for exactly this.

| Check | Where | Investigate when |
|---|---|---|
| Completion rate | Analytics | Below 80% |
| **No driver found** | Analytics | Above 10%, or rising day on day |
| Cancelled | Analytics | Rising, or clustered on one driver |
| Unrated completions | Analytics | Most rides unrated — driver averages are unreliable |
| Crashes | Crashlytics | **Any** crash gets read the same day |
| Feedback | Admin → Feedback | Clear it daily; an unanswered report teaches people not to send them |
| Spend | Firebase console | Against your budget alert |

**"No driver found" is the number that tells you something you can act on.**
Everything else describes what people did; that one says the app failed to find
anyone. Rising means too few drivers online, or a search radius too tight.

Write one line a day even when nothing happens. A fortnight of "quiet, 12 rides,
no crashes" is the pilot report, and it cannot be reconstructed afterwards.

---

## When to stop

### Stop immediately

Flip `acceptingRides` off, then investigate. Do not debug a live system.

- A commuter's data appearing to the wrong person
- Rides being assigned to the wrong driver, or double-assigned
- A crash loop — the app closing repeatedly for anyone
- Any write failure caused by hitting a quota

### Stop at the end of the day

- Crash rate above roughly 1 in 20 sessions
- More than a third of rides ending in "no driver found" for two days running
- Two or more drivers independently saying they have gone back to waiting at
  the terminal

### Keep going, but fix

- One driver struggling — retrain before you change the app
- Fare disputes — nothing to do with the app; it shows no prices. Point to the
  posted tariff at the terminal
- Slow route lookups — OSRM latency, falls back to straight-line automatically

### How to restart after a stop

1. Fix the cause, and confirm the fix with `bash scripts/verify.sh`
2. If it needed an app change, redistribute the APK **and confirm each driver
   installed it** — there is no version gate to do this for you
3. Flip `acceptingRides` back on
4. Tell the drivers in the same channel you used to stop them
5. Write down what happened while it is still fresh

---

## Success criteria

Decide these now, not at the end.

| Measure | Target |
|---|---|
| Completed rides over the pilot | ≥ 100 |
| Completion rate | ≥ 85% |
| "No driver found" | ≤ 10% |
| Crash-free sessions | ≥ 99% |
| Drivers still using it in week 2 | ≥ 75% of those who started |
| Unplanned stops | 0 |

The one that actually matters is **week 2 retention**. Drivers will use anything
for three days because you asked them to. What they are still using in week two
is what works.

---

## The pilot report

Step 89's deliverable. Structure it around what happened, not what was built:

1. Chapter, dates, driver and commuter counts, handsets
2. The daily log, unedited
3. Analytics for the full period, with the window stated
4. Every stop: what triggered it, how long, what fixed it
5. Crashes, grouped, with what was done about each
6. Feedback themes, with quotes
7. Against the criteria above — met, missed, or not measurable
8. What to change before a second chapter

Include the misses. A pilot that reports only successes tells the reader
nothing about whether the system is ready, and a panel will ask.
