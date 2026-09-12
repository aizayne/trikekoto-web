# TrikeKoTo — User Acceptance Testing Kit

Roadmap step 78. Real TODA drivers and commuters, on their own handsets, in Filipino.

**The blocker is cleared.** This used to say *do not run until offers arrive by
push* — without it every participant would have reported the same already-known
failure instead of telling you something new. Push was deployed and verified on
a real handset on 10 September, so the session can now show the system as it is
meant to work rather than as a demo with an apology attached.

---

> **Revised 10 September 2026.** The August version described an app where
> booking was one tap and no personal data was collected. Since then commuters
> must verify a phone number, the app can photograph a government ID, and
> account deletion exists.
>
> The consent form was the urgent part: it said *"walang panganib"* and
> mentioned none of it. A real driver could not have been shown the ID screen
> under it. Do not use a printed copy of the old form.

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
> - Walang bayad sa paglahok.
>
> **Tungkol sa mga impormasyong hihingin ng app:**
>
> - **Number ninyo.** Hihingi po ang app ng mobile number at magpapadala ng
>   code sa SMS. Kailangan po ito para makagamit. Libre po ang code.
> - **Lokasyon.** Hihingi po ng permiso ang telepono para sa lokasyon habang
>   ginagamit ang app.
> - **Larawan ng ID.** May bahagi po ang app na humihingi ng litrato ng ID.
>   **Huwag pong gamitin ang totoong ID ninyo.** Bibigyan ko po kayo ng
>   pekeng card para dito — ang proseso po ang sinusubukan, hindi kung sino
>   kayo. Kung mas gusto ninyong laktawan ang bahaging ito, ayos lang po.
> - **Buburahin ko po ang lahat ng ginawa ninyo pagkatapos ng session** —
>   ang account, ang mga biyahe, at kahit anong litrato.
>
> Naiintindihan ko po ang nasa itaas at pumapayag akong lumahok.
>
> Pangalan: ______________________  Lagda: ______________  Petsa: __________

**Do not skip the ID paragraph, and mean it.** Handing a participant a dummy
card is not a formality — it removes government ID from the session entirely,
which takes the whole of RA 10173 off your shoulders for an afternoon. You are
testing whether somebody can complete the flow, not whether their licence is
genuine. A blank loyalty card photographs exactly as well.

**The dummy card is no longer optional, and neither is an admin.** Since
2026-09-13 nobody reaches the booking screen or the driver dashboard until an
ID is approved. Bring a second phone signed in as admin and approve each
dummy submission live, during the session. Deleting the participant's account
at the end removes their verification along with everything else.

**Delete their data the same day.** Account deletion is in the app now
(Profile → Burahin ang account), and it anonymises their rides server-side.
Doing it in front of them, at the end, is also the most reassuring thing you
can do for the next participant they talk to.

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
| 1 | "Bago po tayo magsimula — buksan ninyo ang app at tingnan ninyo muna. Ano sa palagay ninyo ang magagawa dito?" | They describe it. A first-impression probe, not a task |
| 2 | "Gusto ninyong mag-book. Simulan ninyo po." | **They reach the ID screen.** Sign-in, an SMS code, a name — and now a government ID — before anything a passenger came for. Time it, and note every place they hesitate |
| 3 | *(hand them the dummy card)* "Hihingin po ng app ang ID ninyo bago gamitin. Subukan ninyo pong ipadala." | Submission pending. **Watch what they do at the consent tick**, and whether the notice saying *why* an ID is needed reassures them or alarms them |
| 4 | *(approve it from the admin phone, without saying so)* "May nagbago po ba?" | They find **Magpatuloy** and reach the booking screen unprompted |
| 5 | "Mag-book po kayo ng tricycle papuntang [malapit na palengke]." | Ride reaches `searching`. Note whether they *notice* the pickup filled itself in, and whether they trust it |
| 6 | "Gusto ninyong malaman kung nasaan na ang driver." | They find the live tracking without prompting |
| 7 | "Nagbago ang isip ninyo. Ayaw ninyo nang sumakay." | Ride cancelled |
| 8 | *(after a completed ride)* "Tapos na ang biyahe ninyo. May gusto pa po kayong gawin?" | They find the rating unprompted, or do not — both are findings |
| 9 | "Kung ayaw na ninyong gamitin ang app, paano ninyo buburahin ang account ninyo?" | They find it, or do not. Do not help |

**Task 2 is the one to watch, and it is longer than it was.** It did not exist
in August, when booking was one tap. A passenger now proves a phone number
*and hands over a government ID* before seeing a map, and that is the
highest-friction moment in the product — the point where a real user
who is late for something gives up. Time it with a watch, not an impression.

**Task 3 tests the consent tick, not the upload.** The submit button is
disabled until the box is ticked. Watch whether they read the notice, tick it
blind, or ask what it means. If everyone ticks without reading, the consent is
technically recorded and practically meaningless, and that is worth knowing
before a chapter rolls it out.

**Task 8 is a right, not a feature.** If people cannot find account deletion,
they cannot exercise it, and "we have deletion" becomes a claim rather than a
capability.

Task 6 is deliberately open. If nobody finds the rating without being told, your
rating coverage in production will be poor and the driver averages unreliable.

---

## Driver tasks

| # | Task (say this) | Done when |
|---|---|---|
| 1 | "Gumawa po kayo ng account bilang driver." | Registration submitted |
| 2 | *(hand them the dummy card)* "Hihingin po ng chapter ang ID ninyo bago gamitin ang app. Subukan ninyo pong ipadala." | ID submitted — they cannot reach the dashboard without it. Note whether they hesitate: a driver asked for a licence by an app feels different from one asked by a person they know |
| 3 | "Ano po ang nakikita ninyo ngayon? Puwede na po ba kayong tumanggap ng pasahero?" | They correctly read that they are waiting on the chapter |
| 4 | *(approve the ID, then the driver, from the admin phone)* "May nagbago po ba?" | They find **Magpatuloy**, then notice the dashboard banner changed without being told |
| 5 | "Ipakita ninyo pong available na kayo." | Online, `active_drivers` document exists |
| 6 | "May pasahero po. Kunin ninyo." | Offer accepted |
| 7 | "Nasa inyo na po ang pasahero." | Trip started |
| 8 | "Nakarating na po kayo." | Ride completed |
| 9 | *(with their phone locked and in a pocket, send them an offer)* "May dumating pong booking. Napansin ninyo po ba?" | **They notice the push without being told to look.** This was impossible in August and is now the difference between a driver who must stare at their phone and one who can work |

Task 4 tests the live approval update, which no participant will notice if you
tell them to look.

**Task 9 changed.** In August it was a question — *would you know?* — because
the honest answer was no: offers only arrived with the app open. Push is
deployed now, so it is a real task, and it is still the single most important
thing you will learn. A driver who does not notice the notification cannot use
this system at a terminal, whatever the logs say.

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

### Three bars that did not exist in August

- **Sign-in.** If more than one participant in five abandons before reaching
  the booking screen, the account requirement is costing more than it protects
  and that belongs in your findings, not in a backlog.
- **The push.** If a driver does not notice an offer with the phone pocketed,
  the system does not work at a terminal — whatever the function logs say.
- **The consent tick.** If every participant ticks it without reading, record
  that plainly. A consent that is technically captured and practically unread
  is a finding about the design, not about the participants.

---

## Reporting

For each finding: what happened, how many participants hit it, a verbatim quote,
and severity. Sort by how many people hit it, not by how easy it is to fix — the
fixable ones are not always the ones that matter.

Keep the sheets. They are the evidence behind step 78's sign-off.
