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

> **Revised again 14 September 2026, for app version 1.0.5 (6).** Reading the
> kit against the app found three things the September rewrite still got
> wrong. The consent promised to delete the test rides — nobody can; rides are
> kept, with a commuter's name and number removed. It said the ID part could be
> skipped — the ID requirement makes that impossible. And it said data is
> deleted in the app — true only for commuters; a driver account can only be
> removed from the Firebase console, so drivers now register with
> facilitator-issued test details. It also never said that every booking needs
> a second person on the other role's phone. The printable pack is rebuilt to
> match, in `docs/uat-field-pack.html`. A printable copy is checked in as
> `docs/TrikeKoTo-UAT-Field-Pack.pdf`; regenerate it after any change with:
>
> ```
> chrome --headless=new --no-pdf-header-footer >   --print-to-pdf=docs/TrikeKoTo-UAT-Field-Pack.pdf docs/uat-field-pack.html
> ```

> **Revised again 23 September 2026, for app version 1.0.9 (10).** Four
> releases since the last revision changed what a participant meets and how a
> session ends.
>
> - **Driver accounts can be removed now**, by an admin, from the panel, in
>   one action. The Firebase-console procedure this kit used to describe is
>   gone. Drivers still register with test details, but the reason changed:
>   the account can be removed, and the finished test rides cannot — they keep
>   the driver's name, plate and email as the chapter's record.
> - **The dummy ID number has to fit its ID type.** The number field refuses
>   a PhilSys number that is not exactly 16 digits, a licence that is not 11,
>   and so on, and the submit button stays off until it fits. A card with an
>   arbitrary number would stop the session at task 3. Print the cards as
>   **Barangay ID** with a short number (setup, below).
> - **New things participants will see**, now observed rather than ignored:
>   the trip type (*Regular — 1 pasahero* or *Special — buong tricycle*)
>   before booking; the distance line (*0.4 km ang layo sa iyo*, *Sundo: 1.2 km
>   ang layo*); the approval notice in **Mga abiso**; the three-minute
>   *Wala pang tumatanggap* dialog; and **Kasaysayan ng biyahe**. Cues were
>   added to the existing tasks, and three tasks were added — commuter 9 and
>   10, driver 10. Account deletion moved to commuter task 11 so it stays last.
> - **Review IDs on the Android admin app**, not the web panel. Opening an ID
>   on the web creates a shareable link to the photo — an open finding in the
>   security review. A dummy card makes that harmless, but it is the wrong
>   habit to practise.
> - **The consent's location line was wrong** and has been corrected. It said
>   a nearby passenger sees an online driver's location. Since 10 September
>   only the passenger whose booking a driver accepted sees it, and only until
>   the trip ends — and nobody but that driver sees a passenger's pickup.

> **Revised again 7 October 2026, for app version 1.1.0 (11).** The release
> that answered the defence changed three things a session will meet.
>
> - **A regular trip can now be shared.** A driver carrying one passenger may
>   be offered another going the same way. That is a new driver task (8), and
>   the first thing in this kit that asks a participant to handle two things
>   at once.
> - **A service area can be configured**, and a booking outside it shows a
>   warning. Set it to the venue or leave the radius at 0 before a session —
>   an area still pointed at Balaybay while you sit somewhere else warns on
>   every booking, and a warning everybody learns to ignore is worse than none.
> - **The ID photo can be deleted the moment it is approved.** The app asks
>   after every approval; say yes. It removes a government ID from the session
>   within seconds of the only use it had.

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

## Setup — before the first session

Commuter tasks 5–10 and driver tasks 6–10 need a second person on the other
role's phone: a commuter's booking must be accepted by a driver, and a
driver's offer must come from a booking.
Run sessions with a helper, or with enough phones to play the other side
yourself.

- **Latest app on every phone you bring**, installed over mobile data. The
  landing screen must read `TrikeKoTo 1.1.0 (11)` or newer. Anything older
  lacks the trip type, the distance line, the notification area, the removal
  buttons and shared rides, all of which this kit relies on.
- **Admin phone** — the **Android app**, not the web panel — signed in as an
  administrator with the email already confirmed, open on **ID review**.
  **Aprubahan** stays disabled until you tap **Tingnan ang ID** — open every
  dummy card before approving it.
- **Helper driver phone** for commuter sessions: a verified, approved test
  driver, switched **Online** near the venue. For commuter task 10 it goes
  **Offline** for three minutes; switch it back on afterwards.
- **Helper commuter phone** for driver sessions: a verified test commuter,
  ready to book a pickup near the venue. Both helper accounts are verified once
  and reused all day.
- **Dispatch → Tumatanggap ng booking** switched on.
- **Saklaw ng serbisyo** decided for the venue: either set the centre on the
  map where you are sitting with a radius that covers your test pickups, or
  set the radius to **0** so no warning appears at all. An area left pointing
  at somewhere else warns on every booking of the day.
- **Kasabay na pasahero** left **on** (the default) if you are running driver
  task 8, and the helper commuter phone ready to book a second ride on roughly
  the same route.
- **One dummy ID card per participant** — a blank card printed **BARANGAY ID
  — SAMPLE**, a made-up name, and a number such as `UAT-0001`. The app accepts
  a Barangay ID number of 4 to 20 letters and digits and drops the dash, so
  this fits; a made-up PhilSys number would have to be exactly 16 digits.
  Barangay also avoids imitating a national government card. If a participant
  picks another ID type from the list and the field refuses their typing,
  that is a finding: write down what they chose and what they typed.
- **Driver test-detail slips** filled in (field pack, sheet 4). Test rides
  cannot be deleted, so a driver's real email, plate and number must never go
  into them. Use the facilitator's helper-phone number as the driver's mobile,
  so a commuter's "call the driver" reaches you.

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
> - **Pasahero — number ninyo.** Magpapadala po ang app ng code sa SMS sa
>   inyong mobile number. Libre po ang code.
> - **Driver — test na detalye.** Hindi po kailangan ang inyong email, plate
>   number o mobile number. Bibigyan ko po kayo ng test na detalye na
>   ilalagay sa app.
> - **Lokasyon.** Hihingi po ng permiso ang telepono para sa lokasyon habang
>   ginagamit ang app. Kapag tinanggap ng driver ang isang booking, ang
>   pasaherong iyon lang ang nakakakita ng lokasyon ng driver, hanggang
>   matapos ang biyahe. Ang pickup na pipiliin ng pasahero ay makikita ng
>   driver na tatanggap nito.
> - **Litrato ng ID.** Hindi po magamit ang app nang walang ID. **Huwag pong
>   gamitin ang totoong ID ninyo** — bibigyan ko po kayo ng pekeng card. Ang
>   proseso po ang sinusubukan, hindi kung sino kayo. Kung ayaw ninyong
>   magpadala ng litrato, kahit ng pekeng card, puwede pong huminto dito.
> - **Buburahin po ang account ninyo sa araw na ito** — ang pangalan, number,
>   litrato, at ang litrato ng pekeng ID.
> - **Ang mga biyahe ng pagsubok ay hindi po mabubura**, dahil record ng
>   sistema ang mga ito. Pasahero: aalisin po ang inyong pangalan at number sa
>   mga ito. Driver: test na detalye lang po ang nasa mga ito.
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
ID is approved. Bring a second phone signed in as admin — the Android app —
and approve each dummy submission live, during the session. **Say yes when it
asks to delete the ID photo**: the card has done its only job by then, and
deleting it there means no identity document — not even a dummy one — sits in
the system for the rest of the day. Removing the participant's account at the
end removes their verification along with everything else.

**Delete their data the same day — and know that the two roles differ.**

- **Commuters** delete their own account in the app: **Profile → Burahin ang
  account** (commuter task 11). It removes their name, number, photo, the
  dummy-ID photo, their verification and their sign-in, and strips name and
  number from their test rides. Do it together, in front of them, at the end
  — the most reassuring thing you can do for the next participant they talk
  to. If it cannot finish — it asks for a fresh sign-in on some phones — the
  admin does it instead: **Kasaysayan ng biyahe** → any ride of theirs →
  **Alisin ang pasahero** → **Alisin**. Same result.
- **Drivers** are removed by the admin, after the debrief: dashboard → the
  test driver's card → **Alisin** → **Alisin** on *Alisin si Driver Uno?*.
  One action removes the profile, the Online presence, the dummy-ID photo, the
  verification, the notices and the sign-in account. It is refused while the
  driver is on a ride — the card reads *May biyahe pa — suspindihin muna* —
  so finish or cancel the test ride first. Their finished test rides stay,
  with the driver's name, plate and email and without the phone number:
  exactly why drivers use test details. Show them it happening, too.
- **The helper accounts** are reused all day. Remove them at the end of the
  last session, not between participants.

Record every removal on the cleanup log (field pack, sheet 2).

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
| 3 | *(hand them the dummy card)* "Hihingin po ng app ang ID ninyo bago gamitin. Subukan ninyo pong ipadala." | Submission pending. **Watch what they do at the consent tick**, and whether the notice saying *why* an ID is needed reassures them or alarms them. Note whether they pick **Barangay ID** from the card, and what happens if they pick another type |
| 4 | *(approve it from the admin phone, without saying so)* "May nagbago po ba?" | They find **Magpatuloy** and reach the booking screen unprompted |
| 5 | "Mag-book po kayo ng tricycle papuntang [malapit na palengke]." | Ride reaches `searching`. Note whether they *notice* the pickup filled itself in, and whether they trust it. **Watch the trip type**: do they read *Regular* and *Special* or take the default — and afterwards, can they say what Special means? If a service-area warning appears, note whether they read it, ignore it, or stop booking because of it |
| 6 | *(accept on the helper driver phone)* "Gusto ninyong malaman kung nasaan na ang driver." | They find the live tracking without prompting. Note whether they read the distance beside the driver's name (*0.4 km ang layo sa iyo*) or only look at the map |
| 7 | "Nagbago ang isip ninyo. Ayaw ninyo nang sumakay." | Ride cancelled |
| 8 | *(have them book again; on the helper driver phone accept, start and complete it)* "Tapos na ang biyahe ninyo. May gusto pa po kayong gawin?" | They find the rating unprompted, or do not — both are findings |
| 9 | "Saan po ninyo makikita ang mga nakaraan ninyong biyahe?" | They open **Kasaysayan ng biyahe** and find the ride from task 8. It sits under the booking button, not in the app bar |
| 10 | *(helper driver phone **Offline**)* "Mag-book po kayo ulit papuntang [parehong lugar]." | Three minutes in, **Wala pang tumatanggap** appears. Done when they choose **Maghintay pa** or **Kanselahin ang ride**. Write down which, and whether they could say why it appeared. Optional — it costs three minutes of waiting — but run it with at least two commuters. Switch the helper driver back **Online** afterwards |
| 11 | "Kung ayaw na ninyong gamitin ang app, paano ninyo buburahin ang account ninyo?" | They find it, or do not. Do not help |

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

**Task 11 is a right, not a feature.** If people cannot find account deletion,
they cannot exercise it, and "we have deletion" becomes a claim rather than a
capability.

Task 8 is deliberately open. If nobody finds the rating without being told, your
rating coverage in production will be poor and the driver averages unreliable.

**Task 10 tests a sentence, not a timer.** The dialog exists because a
progress bar describes what the system is doing, not what the passenger wants
to know. If people close it without reading, or cannot say afterwards whether
anyone was coming, it is not doing that job.

---

## Driver tasks

| # | Task (say this) | Done when |
|---|---|---|
| 1 | *(hand them a test-detail slip)* "Gumawa po kayo ng account bilang driver gamit ang mga detalyeng ito." | Registration submitted, with the test details — never their own email, plate or number |
| 2 | *(hand them the dummy card)* "Hihingin po ng chapter ang ID ninyo bago gamitin ang app. Subukan ninyo pong ipadala." | ID submitted — they cannot reach the dashboard without it. Note whether they hesitate: a driver asked for a licence by an app feels different from one asked by a person they know |
| 3 | "Ano po ang nakikita ninyo ngayon? Puwede na po ba kayong tumanggap ng pasahero?" | They correctly read that they are waiting on the chapter |
| 4 | *(admin phone: **Tingnan ang ID** → **Aprubahan**, then approve the driver)* "May nagbago po ba?" | They find **Magpatuloy**, then notice the dashboard banner changed without being told. **Watch the bell** in the app bar: approving the driver puts a count on it. Do they open **Mga abiso** and read *Aprubado na ang account mo*? |
| 5 | "Ipakita ninyo pong available na kayo." | The switch reads **Online** (it shows **Kumokonekta…** first). If red text appears under it, photograph the screen |
| 6 | *(book a nearby pickup on the helper commuter phone)* "May pasahero po. Kunin ninyo." | Offer accepted. Before they tap **Tanggapin**, note whether they read *Sundo: … km ang layo* and the trip type — and ask afterwards whether either would ever make them decline |
| 7 | "Nasa inyo na po ang pasahero." | Trip started |
| 8 | *(while that trip is under way, book a second ride on the helper commuter phone, pickup and drop-off along the same road)* "May bago pong dumating. Ano po iyon?" | **Kasabay na pasahero** appears. Done when they accept or decline — both are findings. Then ask the question that matters: *ilan pong pasahero ang nasa inyo ngayon?* A driver who cannot say is carrying somebody they have forgotten |
| 9 | "Nakarating na po kayo sa una." | The *first* ride completed — note whether they pick the right card. Two cards, two sets of buttons, and the wrong one ends somebody else's trip |
| 10 | *(with their phone locked and in a pocket, book again on the helper commuter phone)* "May dumating pong booking. Napansin ninyo po ba?" | **They notice the push without being told to look.** This was impossible in August and is now the difference between a driver who must stare at their phone and one who can work |
| 11 | "Saan po ninyo makikita ang mga naihatid ninyong pasahero?" | They open **Kasaysayan ng biyahe** and find the rides from tasks 8 and 9. It shows the passenger's name and not their number — ask whether that is what they expected |

Task 4 tests the live approval update, which no participant will notice if you
tell them to look. It now tests the notice as well: an approval arrives hours
or days after registering in real use, and the bell is how a driver finds out.
If nobody opens it here, with the facilitator in the room, nobody will open it
at home.

**Task 8 is the new one, and it is the hardest thing this app asks of a
driver.** Everything else is one passenger at a time. Here a second offer
arrives while they are driving, the screen grows a second card, and the two
have separate buttons. Watch three things: whether they notice the offer at
all; whether they read it as a *second passenger* rather than as a mistake;
and whether, at task 9, they finish the right ride. A driver who taps
**Tapusin** on the wrong card has ended a trip for somebody still in the
tricycle, and that is a blocker, not a copy problem.

**Task 6 asks a question the app just answered.** The pickup distance is on the
offer because it is the number a driver decides on. If drivers accept without
looking at it, that is fine — at a terminal most pickups are close — but if
they say they would decline a far one and never looked, the line is in the
wrong place.

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
  9  │         │            │               │      │
 10  │         │            │               │      │
 11  │         │            │               │      │

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

### Two bars added in October

- **The shared offer.** If a driver cannot say how many passengers are with
  them after accepting a second, or finishes the wrong ride at task 9, stop
  and record it as a blocker. Sharing is the one feature here that can strand
  a passenger who is sitting in the tricycle.
- **The service-area warning.** If a commuter stops booking because of it,
  the wording is too strong for something that does not refuse anything.

### One bar added in September

- **The trip type.** If more than one commuter in five cannot say what
  *Special* means after choosing one, a driver will be told one thing at the
  kerb and paid for another. That is a blocker, not a copy tweak.

---

## Reporting

For each finding: what happened, how many participants hit it, a verbatim quote,
and severity. Sort by how many people hit it, not by how easy it is to fix — the
fixable ones are not always the ones that matter.

Keep the sheets. They are the evidence behind step 78's sign-off.
