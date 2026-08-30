# TrikeKoTo — User Acceptance Testing Kit

Roadmap step 78. Real TODA drivers and commuters, on their own handsets, in Filipino.

**Do not run this until offers arrive by push** (step 62, needs Blaze). Without it
a driver must keep the app open to receive anything, and every participant will
report the same already-known failure instead of telling you something new.

---

## Before you recruit

### How many people

**Five per role.** Five commuters, five drivers. That is the standard rule of
thumb for finding usability problems — the fifth participant rarely shows you
anything the first four did not.

Be honest about what that sample can and cannot support. Five people will find
most of the problems in the interface. Five people will **not** give you a
statistically meaningful satisfaction score. Report the SUS number as an
indication, not a finding, and say `n = 5` next to it every time you print it.

### Who

Drivers should be **actual TODA members from the chapter you intend to pilot
with**, not classmates. Commuters should be people who actually ride tricycles —
mix ages, and deliberately include at least one person who is not confident with
smartphones. That participant will teach you more than the other four combined.

### On their own handsets

This matters more than it sounds. Your phone is fast, charged, on Wi-Fi, and has
the permissions already granted. Theirs is not. Install the APK on **their**
device, over **their** mobile data, and let them hit the permission prompts
themselves. Record the handset model and Android version for each participant.

---

## Consent form

Print one per participant. Read it aloud rather than handing it over — several
participants will not want to admit they would rather not read it.

> **Pahintulot sa Paglahok**
>
> Ginagawa ko po itong pag-aaral para sa aking thesis tungkol sa TrikeKoTo, isang
> app para sa pagbook ng tricycle.
>
> - **Ang app po ang sinusubukan, hindi kayo.** Walang mali o tamang sagot.
> - Kusang-loob po ang paglahok. Puwede kayong huminto anumang oras, at hindi
>   ninyo kailangang magpaliwanag.
> - Isusulat ko po ang mga napansin ko habang ginagamit ninyo ang app.
> - Hindi po ilalagay ang inyong pangalan sa report. Gagamit po ako ng tulad ng
>   "Driver 1" o "Pasahero 3".
> - Walang bayad at walang panganib sa paglahok.
>
> Naiintindihan ko po ang nasa itaas at pumapayag akong lumahok.
>
> Pangalan: ______________________  Lagda: ______________  Petsa: __________

If you plan to photograph or record audio, add a separate line for it and let
them decline that part while still taking part.

---

## Facilitator rules

These are the whole method. Everything else is paperwork.

1. **Give the goal, never the steps.** "Mag-book po kayo ng tricycle papuntang
   palengke" — not "pindutin ninyo ang pickup, tapos…". The moment you describe
   the interface you stop learning whether it explains itself.
2. **Count to ten before helping.** Silence is uncomfortable and it is where the
   findings are. Most facilitators rescue far too early.
3. **Never say "just" or "simply".** Both tell a struggling participant that what
   they cannot do is obvious.
4. **Ask what they expected, not why they failed.** "Ano po ang inaasahan ninyong
   mangyari?" beats "Bakit po hindi ninyo napindot?"
5. **Record what they did, not what they say they would do.** Stated intent is
   close to worthless; observed behaviour is the data.
6. **Say out loud, more than once, that you are testing the app.** Participants
   who think they are being judged stop trying things.

Open every session with this, in Filipino:

> "Ang app po ang sinusubukan natin, hindi kayo. Kung may hindi kayo maintindihan,
> problema po iyon ng app at iyon mismo ang gusto kong malaman. Sabihin ninyo po
> nang malakas kung ano ang iniisip ninyo habang ginagawa."

---

## Commuter tasks

Give one at a time. Do not read the next until the current one ends — completed,
abandoned, or five minutes elapsed.

| # | Task (say this) | Done when |
|---|---|---|
| 1 | "Bago po tayo magsimula — buksan ninyo ang app at tingnan ninyo muna. Ano sa palagay ninyo ang magagawa dito?" | They describe it. This is a first-impression probe, not a task |
| 2 | "Mag-book po kayo ng tricycle mula dito papuntang [malapit na palengke]." | Ride reaches `searching` |
| 3 | "Gusto ninyong malaman kung nasaan na ang driver." | They find the live tracking without prompting |
| 4 | "Nagbago ang isip ninyo. Ayaw ninyo nang sumakay." | Ride cancelled |
| 5 | *(after a completed ride)* "Tapos na ang biyahe ninyo. May gusto pa po kayong gawin?" | They find the rating unprompted, or do not — both are findings |

Task 5 is deliberately open. If nobody finds the rating without being told, your
rating coverage in production will be poor and the driver averages unreliable.

---

## Driver tasks

| # | Task (say this) | Done when |
|---|---|---|
| 1 | "Gumawa po kayo ng account bilang driver." | Registration submitted |
| 2 | "Ano po ang nakikita ninyo ngayon? Puwede na po ba kayong tumanggap ng pasahero?" | They correctly read the pending state |
| 3 | *(after approval)* "May nagbago po ba?" | They notice the banner changed without being told |
| 4 | "Ipakita ninyo pong available na kayo." | Online, `active_drivers` document exists |
| 5 | "May pasahero po. Kunin ninyo." | Offer accepted |
| 6 | "Nasa inyo na po ang pasahero." | Trip started |
| 7 | "Nakarating na po kayo." | Ride completed |
| 8 | "Kung nasa terminal po kayo at may dumating na booking, sa tingin ninyo malalaman ninyo?" | Their answer about notifications — critical for the pilot |

Task 3 tests the live approval update, which no participant will notice if you
tell them to look. Task 8 is a question, not a task, and it is the single most
important thing you will learn about whether this works in the field.

---

## Observation sheet

One page per participant.

```
Participant ____   Role: Driver / Pasahero
Handset ______________________  Android ______  Network: data / wifi
Date ____________  Facilitator ____________

Task │ Mag-isa │ May tulong │ Hindi natapos │ Oras │ Saan natigil / sinabi
─────┼─────────┼────────────┼───────────────┼──────┼──────────────────────
  1  │         │            │               │      │
  2  │         │            │               │      │
  3  │         │            │               │      │
  4  │         │            │               │      │
  5  │         │            │               │      │
  6  │         │            │               │      │
  7  │         │            │               │      │
  8  │         │            │               │      │

Mga eksaktong sinabi (quote them, do not paraphrase):


Kung saan sila natigil nang matagal:


Ano ang inaasahan nila na hindi nangyari:
```

Write **quotes, not summaries**. "Hindi ko alam kung saan ko ilalagay" is
evidence. "Confused about the pickup field" is your interpretation of evidence,
and by the time you write the report you will not remember which was which.

---

## Satisfaction questionnaire — SUS

The System Usability Scale (Brooke, 1996), the standard 10-item instrument.
Free to use; cite it.

**The Filipino below is a working translation, not a validated instrument.**
Say so in your methodology. A validated Filipino SUS is not something you should
claim without the validation study behind it.

Scale for every item: **1 = Hindi sang-ayon** … **5 = Sang-ayon**

| # | English | Filipino |
|---|---|---|
| 1 | I would like to use this system frequently | Gusto kong gamitin nang madalas ang app na ito |
| 2 | I found the system unnecessarily complex | Masyadong kumplikado ang app para sa kailangan kong gawin |
| 3 | I thought the system was easy to use | Madaling gamitin ang app |
| 4 | I would need support from a technical person | Kailangan ko ng tulong ng ibang tao para magamit ito |
| 5 | The functions were well integrated | Magkakaugnay at pare-pareho ang mga bahagi ng app |
| 6 | There was too much inconsistency | Marami akong napansing hindi magkatugma sa app |
| 7 | Most people would learn this very quickly | Mabilis matututo ang karamihan na gamitin ito |
| 8 | The system was cumbersome to use | Nakakalito at nakakapagod gamitin ang app |
| 9 | I felt confident using the system | Kumpiyansa ako habang ginagamit ang app |
| 10 | I needed to learn a lot before I could start | Marami akong kailangang matutunan bago ko ito magamit |

### Scoring

- Odd-numbered items: **score − 1**
- Even-numbered items: **5 − score**
- Add the ten adjusted values, then **multiply by 2.5**

Result runs 0–100. It is **not a percentage**. Around **68 is average**; above 80
is good. Report the mean across participants with `n` beside it.

---

## Debrief

Three questions, after the questionnaire, recorded verbatim:

1. "Ano po ang pinakanakakainis sa app?"
2. "Kung may isang bagay lang kayong mababago, ano po iyon?"
3. *(drivers)* "Gagamitin ninyo po ba ito sa totoong pamamasada? Bakit o bakit hindi?"

Question 3 is your acceptance criterion. A driver who completed every task
perfectly and then says they would not use it has told you the study's most
important result, and no task-completion table will surface it.

---

## What counts as passing

Decide this **before** you run a single session, and write it down. Deciding
afterwards is how a study talks itself into a positive result.

A defensible bar:

| Measure | Target |
|---|---|
| Core task completion, unaided | ≥ 80% (4 of 5 participants per task) |
| Tasks abandoned | 0 on booking, accepting, and completing |
| Mean SUS | ≥ 68 |
| Drivers who say they would use it | ≥ 4 of 5 |

Anything that blocks a participant from finishing a core task is a **blocker** and
should be fixed before the pilot, regardless of the scores around it.

---

## Reporting

For each finding: what happened, how many participants hit it, a verbatim quote,
and severity. Sort by how many people hit it, not by how easy it is to fix — the
fixable ones are not always the ones that matter.

Keep the sheets. They are the evidence behind step 78's sign-off.
