// Builds the TrikeKoTo end-user manual in two formats from ONE source:
//
//   docs/user-manual.md              — the repository copy (source of truth)
//   docs/TrikeKoTo-User-Manual.docx  — for the thesis appendix and printing
//
// Run from trikekoto_app/ with the globally installed docx package:
//   NODE_PATH="$(npm root -g)" node scripts/build_user_manual.cjs
//
// Every label quoted here is copied from lib/l10n/app_fil.arb and app_en.arb,
// which are what the app renders. If a label changes in the app, change it
// here and rebuild; do not edit the two outputs by hand, or they will drift
// apart from each other and from the build.
'use strict';

const fs = require('fs');
const path = require('path');
const {
  AlignmentType, BorderStyle, Document, Footer, HeadingLevel, LevelFormat,
  PageBreak, PageNumber, Packer, Paragraph, ShadingType, Table, TableCell,
  TableOfContents, TableRow, TextRun, WidthType, ImageRun,
} = require('docx');

const VERSION = '1.0.5 (6)';
const DATE = 'September 2026';

// ── Content ─────────────────────────────────────────────────────────────
// Block types: h1 h2 h3 p steps bullets table note figure pagebreak
// Inline **bold** is supported in every string.

const L = (fil, en) => `**${fil}** (${en})`; // a button or label, as shown

// Screenshots come from test/manual/manual_screenshots_test.dart, which renders
// the shipped screens over made-up data. Regenerate them there, not by hand.
let fig = 0;
const figure = (caption, file) => ({ figure: `Figure ${++fig}. ${caption}`, file });

const content = [
  { h1: '1. Introduction' },
  { p: 'TrikeKoTo is a tricycle ride-hailing system for Tricycle Operators and Drivers’ Associations (TODA). A commuter books a tricycle from a phone, the system offers the ride to the nearest available driver, and both follow the trip on a live map until the passenger is dropped off.' },
  { p: 'This manual explains how to install and use the system. It has one part for each kind of user:' },
  { bullets: [
    '**Commuters** — passengers who book rides (Section 4).',
    '**Drivers** — TODA members who accept and complete rides (Section 5).',
    '**Administrators** — TODA officers who approve drivers and IDs and run the service (Section 6).',
  ] },
  { h2: 'How to read this manual' },
  { p: `The app opens in Filipino. Buttons and labels are written the way they appear on screen, with the English wording in brackets — for example ${L('Mag-book ng ride', 'Book a ride')}. If you switch the app to English, look for the wording in brackets.` },
  { note: `This manual describes version ${VERSION}. The version is printed at the bottom of the landing screen, the driver screen, the commuter Profile screen and the ID verification screen.` },

  { h1: '2. Before You Start' },
  { h2: '2.1 What you need' },
  { table: {
    head: ['', 'Requirement'],
    widths: [2600, 6760],
    rows: [
      ['Android phone', 'Android 7.0 or newer, with GPS and an internet connection (mobile data or Wi-Fi).'],
      ['iPhone, tablet or computer', 'A current web browser. Use the web version at **trikekoto.web.app**.'],
      ['Commuters', 'A Philippine mobile number that can receive SMS, and a government-issued ID.'],
      ['Drivers', 'An email address, a registered tricycle and plate number, TODA membership, and a government-issued ID.'],
      ['Administrators', 'An administrator account set up by the project team (see Section 6.1).'],
    ],
  } },
  { h2: '2.2 Installing the app on Android' },
  { steps: [
    'On the phone, open the download link **trikekoto.web.app/download/trikekoto.apk**, or scan the QR code given by your TODA.',
    'When the download finishes, tap the file to open it.',
    'If Android asks, allow your browser or file manager to **install unknown apps**, then go back and tap **Install**.',
    'Open **TrikeKoTo** from your home screen.',
  ] },
  { note: 'Download the app over a connection you trust, such as your mobile data. To update, install the new file over the existing app — you stay signed in and keep your data. Uninstalling first signs you out.' },
  { h2: '2.3 Using the web version' },
  { p: 'On an iPhone or a computer, open **trikekoto.web.app** in a browser. The web version has the same screens. When the browser asks to use your location, choose **Allow**.' },
  { h2: '2.4 Controls at the top of the screen' },
  { p: 'Most screens have some or all of these controls in the bar at the top:' },
  { table: {
    head: ['Control', 'What it does'],
    widths: [2600, 6760],
    rows: [
      ['**EN** or **FIL**', 'Switches the whole app between Filipino and English. The label shows the language you will switch **to**. Your choice is remembered.'],
      ['Moon or sun icon', 'Switches between light and dark colours. Your choice is remembered.'],
      ['Flag icon', 'Reports a problem or suggestion to the TODA administrator (Section 4.9). Found on the booking and driver screens.'],
      ['Exit icon', 'Signs you out of the app.'],
    ],
  } },
  { h2: '2.5 Signing in and staying signed in' },
  { p: 'After the first sign-in, TrikeKoTo keeps you signed in on that phone. Commuters are asked for an SMS code again only when they:' },
  { bullets: ['sign out,', 'uninstall and reinstall the app, or', 'sign in on a different phone.'] },
  { p: 'Your ID verification belongs to your account, so it carries over to a new phone. You never need to verify your ID again (Section 7.2).' },

  { h1: '3. Identity Verification' },
  { p: 'To protect passengers and drivers from scams and trolls, **every account must have a government ID approved by the TODA chapter before it can be used**. Commuters cannot book, and drivers cannot go online or accept rides, until their ID is approved.' },
  { h2: '3.1 Accepted IDs' },
  { p: 'PhilSys National ID, Driver’s License (LTO), UMID, PhilHealth ID, Postal ID, Voter’s ID, Passport, Senior Citizen ID, Student ID, and Barangay ID.' },
  { h2: '3.2 Submitting your ID' },
  { p: `The ${L('ID verification', 'ID verification')} screen appears on its own after you sign up.` },
  figure('The ID verification screen', 'fig-1-id-verification.png'),
  { steps: [
    `Choose your ID from ${L('Uri ng ID', 'ID type')}.`,
    `Type the number printed on the card in ${L('Numero ng ID', 'ID number')}.`,
    `Tap the photo area and choose ${L('Kunan ng litrato ang ID', 'Photograph the ID')} or ${L('Pumili sa gallery', 'Choose from gallery')}. Make sure the name and number can be read.`,
    `Read ${L('Paano gagamitin ang ID mo', 'How your ID is used')}, then tick ${L('Pumapayag ako na iproseso ang ID ko para sa pagkumpirma', 'I agree to my ID being processed for verification')}.`,
    `Tap ${L('Ipadala para sa review', 'Send for review')}.`,
  ] },
  { p: `The screen changes to ${L('Hinihintay ang review', 'Waiting for review')}. You do not need to keep it open.` },
  { h2: '3.3 After review' },
  { table: {
    head: ['You see', 'What it means', 'What to do'],
    widths: [2500, 3430, 3430],
    rows: [
      [`${L('Beripikado na', 'Verified')}`, 'The chapter approved your ID.', `Tap ${L('Magpatuloy', 'Continue')} to start using the app.`],
      [`${L('Hindi tinanggap', 'Not accepted')}`, 'The chapter could not accept it. The reason is shown below the title.', `Tap ${L('Bawiin at burahin ang ID', 'Withdraw and delete the ID')}, then send a clearer photo or a different ID.`],
      [`${L('Hinihintay ang review', 'Waiting for review')}`, 'An officer has not looked at it yet.', 'Wait. Approval is done by a person, so it may take some time.'],
    ],
  } },
  { note: 'Only one ID is ever needed per account. Once approved, the app shows **Beripikado ang ID** (ID verified) and will not ask again, even after the photo is deleted.' },

  { pagebreak: true },
  { h1: '4. Commuter Guide' },
  { h2: '4.1 Creating your account' },
  { steps: [
    `Open the app and tap ${L('Mag-book ng ride', 'Book a ride')}.`,
    `Under ${L('Ano ang number mo?', 'What is your number?')}, type your mobile number (09XX XXX XXXX) and tap ${L('Ipadala ang code', 'Send code')}.`,
    `Type the six-digit code from the SMS and tap ${L('Kumpirmahin', 'Confirm')}. To use a different number, tap ${L('Ibang number', 'Use a different number')}.`,
    `On ${L('Konti na lang', 'Almost done')}, add a photo if you like (you can skip it) and type the name the driver should call you.`,
    `Tap ${L('Simulan', 'Start')}.`,
    'Submit your ID and wait for approval (Section 3).',
  ] },
  figure('Signing in with a mobile number', 'fig-2-sign-in.png'),
  { note: 'Your number is not shown to any driver until you book a ride.' },
  { h2: '4.2 Booking a ride' },
  figure('The booking screen', 'fig-3-booking.png'),
  { steps: [
    `On ${L('Saan tayo?', 'Where to?')}, check ${L('Sundo', 'Pickup')}. The app fills it in with your current location. To change it, tap it and set it on the map (Section 4.3).`,
    `Tap ${L('Babaan', 'Drop-off')} and set where you are going.`,
    `Check the trip line, which shows the distance and about how many minutes the trip takes.`,
    `Check your name and mobile number, so the driver can find and call you.`,
    `Tap ${L('Maghanap ng driver', 'Find a driver')}.`,
  ] },
  { note: 'The app does not show or charge a fare. Pay the posted TODA fare to the driver in cash.' },
  { h2: '4.3 Setting a place on the map' },
  { p: 'There are three ways to place the pin:' },
  { bullets: [
    `Type a place in ${L('Maghanap ng lugar', 'Search a place')} and tap ${L('Hanapin', 'Search')}.`,
    'Drag the map, or tap a spot on it, to move the pin.',
    `Tap ${L('Nasa akin ngayon', 'Where I am now')} to use your current location.`,
  ] },
  { p: `Then type a name for the place in ${L('Pangalanan ang lugar', 'Name this place')} — for example Plaza, Palengke or Barangay Hall — and tap ${L('Kumpirmahin ang location', 'Confirm location')}. The driver sees this name.` },
  { h2: '4.4 Waiting for a driver' },
  { p: `The screen shows ${L('Naghahanap ng driver…', 'Looking for a driver…')}. The system offers your ride to the nearest available driver first. If that driver does not answer within 15 seconds, it asks the next nearest, and so on. The line ${L('Natanong na ang 3 sa 10 malapit na driver', 'Asked 3 of 10 nearby drivers')} shows how many have been asked.` },
  { bullets: [
    'The search continues even if you close the app.',
    'If no driver accepts after 10 drivers or about 5 minutes, the search stops and the booking screen appears again. Try again later.',
  ] },
  { h2: '4.5 When a driver accepts' },
  figure('Tracking an accepted ride', 'fig-4-tracking.png'),
  { p: `The screen changes to ${L('Papunta na ang driver', 'Driver is on the way')} and shows the driver’s name and tricycle plate number. The map shows where the driver is and how far away.` },
  { bullets: [
    `To call the driver, tap the phone button, ${L('Tawagan si …', 'Call …')}.`,
    `When the trip starts, the screen changes to ${L('Papunta na sa babaan mo', 'On the way to your drop-off')}.`,
  ] },
  { h2: '4.6 Cancelling a ride' },
  { p: `Tap ${L('Kanselahin ang ride', 'Cancel ride')}. You can cancel while searching and after a driver accepts, but **not after the trip has started**.` },
  { h2: '4.7 Rating your driver' },
  { p: `After you are dropped off, the app asks ${L('Kumusta ang biyahe mo?', 'How was your ride?')}. Tap 1 to 5 stars. Each ride can be rated **once**, and the rating cannot be changed.` },
  { h2: '4.8 Your profile' },
  { p: 'Tap your photo at the top of the booking screen (a person icon if you have not added one) to open **Profile**.' },
  { bullets: [
    `**Photo** — tap it to take a new one, choose from the gallery, or ${L('Alisin ang litrato', 'Remove photo')}. Tap ${L('I-save', 'Save')} to keep the change.`,
    `**Name** — edit it and tap ${L('I-save', 'Save')}.`,
    '**Mobile number** — shown as confirmed. It cannot be edited. Signing in with a different number creates a separate account, which needs its own ID verification.',
    `**ID** — shows ${L('Beripikado ang ID', 'ID verified')} once approved. Tap it to see your ID or delete the photo.`,
  ] },
  { h3: 'Deleting your account' },
  { steps: [
    `At the bottom of Profile, tap ${L('Burahin ang account', 'Delete account')}.`,
    'Read what will be deleted and what will be kept, then confirm.',
  ] },
  { p: 'Your name, photo, ID and account are deleted permanently. Past rides stay as a TODA record, but your name and number are removed from them. If the app asks you to sign in again first, do so — this is a security check.' },
  { h2: '4.9 Reporting a problem' },
  { steps: [
    'Tap the flag icon at the top of the screen.',
    `Choose ${L('Problema', 'Problem')}, ${L('Mungkahi', 'Suggestion')}, ${L('Tanong', 'Question')} or ${L('Iba pa', 'Other')}.`,
    `Describe what happened in ${L('Ano ang nangyari?', 'What happened?')}.`,
    `Add a contact in ${L('Contact (opsyonal)', 'Contact (optional)')} only if you want a reply.`,
    `Tap ${L('Ipadala ang report', 'Send report')}.`,
  ] },

  { pagebreak: true },
  { h1: '5. Driver Guide' },
  { h2: '5.1 Registering' },
  { steps: [
    `Open the app and tap ${L('Mag-sign in bilang driver o admin', 'Driver / Admin sign in')}.`,
    `Tap ${L('Magparehistro bilang TODA driver', 'Register as a TODA driver')}.`,
    'Fill in the form (see the table below).',
    `Tap ${L('Gumawa ng account', 'Create account')}.`,
    'Submit your ID (Section 3).',
  ] },
  { table: {
    head: ['Field', 'What to enter'],
    widths: [3000, 6360],
    rows: [
      [`${L('Pangalan', 'First name')} / ${L('Apelyido', 'Last name')}`, 'Your name, as printed on your license.'],
      ['**Mobile number**', 'The number commuters will call when you accept their ride.'],
      ['**Plate number**', 'Your tricycle’s plate. Commuters use it to find you.'],
      ['**TODA chapter**', 'The chapter you belong to.'],
      ['**Email** and **Password**', 'What you will use to sign in. The password needs at least 6 characters.'],
    ],
  } },
  { h2: '5.2 Waiting for approval' },
  { p: 'Two approvals are needed before you can take rides: your **ID** (Section 3) and your **driver registration**. The banner at the top of the driver screen shows your registration status and updates on its own.' },
  { table: {
    head: ['Banner', 'Meaning'],
    widths: [3400, 5960],
    rows: [
      [`${L('Hinihintay ang verification', 'Pending verification')}`, 'An administrator has not approved you yet. Tell your TODA officer you have registered.'],
      ['**Verified TODA driver**', 'You are approved and can go online.'],
      [`${L('Naka-suspend ang account mo', 'Your account is suspended')}`, 'You cannot accept rides. Talk to your TODA officer.'],
      [`${L('Hindi natanggap ang registration mo', 'Your registration was rejected')}`, 'Talk to your TODA officer.'],
    ],
  } },
  { h2: '5.3 Going online' },
  figure('The driver screen with the Online switch', 'fig-5-driver-online.png'),
  { steps: [
    'Turn on **Location** on your phone.',
    'Slide the **Offline** switch to **Online**.',
    'If asked, allow location access **while using the app**, and allow notifications.',
    `Wait while the switch shows ${L('Kumokonekta…', 'Connecting…')}. Do not tap it again.`,
  ] },
  { p: `When the switch shows **Online**, you appear to nearby commuters and the screen says ${L('Naghihintay ng biyahe', 'Waiting for a ride')}.` },
  { p: 'If going online fails, a red message explains why (see Section 8). If a line starting with **Detalye para sa suporta** (Details for support) appears under the switch, take a screenshot and send it to your TODA officer.' },
  { h2: '5.4 Accepting a ride' },
  { p: `When a commuter nearby books, your phone shows a notification and the screen shows ${L('Bagong ride offer', 'New ride offer')} with the pickup and drop-off.` },
  { bullets: [
    `${L('Tanggapin', 'Accept')} — the ride is yours.`,
    `${L('Tanggihan', 'Decline')} — the ride goes to the next nearest driver.`,
  ] },
  { p: 'Each offer lasts about 15 seconds. If you do not answer in time, the ride goes to another driver. If two drivers accept at the same moment, only one gets the ride, and the app tells the other.' },
  { h2: '5.5 During the ride' },
  { p: `The ${L('Kasalukuyang biyahe', 'Current ride')} card shows a map to ${L('Sunduin sa …', 'Pick up at …')} and then ${L('Ibaba sa …', 'Drop off at …')}.` },
  { bullets: [
    `${L('Buksan sa maps', 'Open in maps')} opens directions in your maps app.`,
    'The phone button calls the commuter if you cannot find them.',
  ] },
  { steps: [
    `When the passenger is on board, tap ${L('Simulan ang biyahe', 'Start trip')}.`,
    `When they have been dropped off, tap ${L('Tapusin ang biyahe', 'Complete ride')}.`,
    'Collect the posted TODA fare in cash.',
  ] },
  { p: `To call off a ride, tap ${L('Kanselahin', 'Cancel')}.` },
  { h2: '5.6 Going offline' },
  { p: 'Slide the switch back to **Offline**. You stop receiving offers and the app stops using your location. Go offline when you finish your shift — staying online uses battery and data.' },

  { pagebreak: true },
  { h1: '6. Administrator Guide' },
  { h2: '6.1 Getting access' },
  { p: 'Administrator accounts cannot be created from inside the app. The project team adds your email address to the list of administrators. You then:' },
  { steps: [
    `Open the app and tap ${L('Mag-sign in bilang driver o admin', 'Driver / Admin sign in')}, then sign in with your email and password.`,
    `If you see ${L('Kumpirmahin ang email mo', 'Confirm your email')}, tap ${L('Ipadala ang verification email', 'Send verification email')}, open the link in your email (check spam), come back and tap ${L('Nakumpirma ko na', 'I have confirmed it')}.`,
  ] },
  { p: 'You only confirm your email once. If you are taken to the driver screen instead, your administrator entry does not match your email address; contact the project team.' },
  { h2: '6.2 The dashboard' },
  { p: 'The administrator dashboard has shortcuts to **Feedback**, **Dispatch** and **ID review**, a ride summary, and the list of drivers.' },
  figure('The administrator dashboard', 'fig-6-admin-dashboard.png'),
  { h3: 'Ride summary' },
  { p: `Choose **Today**, **7 days** or **30 days**, then tap ${L('I-refresh', 'Refresh')}. The summary does not update live while you watch it; tap it again to load the latest rides.` },
  { table: {
    head: ['Figure', 'Meaning'],
    widths: [3000, 6360],
    rows: [
      [`${L('natapos', 'completed')}`, 'Rides that finished.'],
      ['**completion rate**', 'Completed rides out of all rides that ended. Rides still in progress are not counted.'],
      [`${L('kinansela', 'cancelled')}`, 'Rides called off by the commuter or the driver.'],
      [`${L('walang nakitang driver', 'no driver found')}`, 'Rides no driver accepted. A high number means too few drivers online or a search radius that is too small.'],
      [`${L('average na rating', 'avg rating')}`, 'The average star rating of rated rides.'],
    ],
  } },
  { p: `Below the figures are a daily chart and a ${L('Kada driver', 'By driver')} table.` },
  { h2: '6.3 Approving drivers' },
  { p: `New registrations appear under ${L('Naghihintay ng verification', 'Pending verification')} with their name, plate, mobile number, email and TODA chapter.` },
  { steps: [
    'Check the details against your chapter records. The app only records what the driver typed.',
    `Tap ${L('Aprubahan', 'Approve')}. The driver’s app updates within seconds.`,
  ] },
  { p: `To stop a driver from accepting rides, tap ${L('I-suspend', 'Suspend')} on their entry in ${L('Lahat ng driver', 'All drivers')}. To reinstate them, tap ${L('Aprubahan', 'Approve')}.` },
  { h2: '6.4 Reviewing IDs' },
  figure('Reviewing a submitted ID', 'fig-7-id-review.png'),
  { steps: [
    `Open ${L('ID review', 'ID review')}. Each card shows whether the person is a driver or commuter, the ID type and number.`,
    `Tap ${L('Tingnan ang ID', 'View the ID')} and check the photo.`,
    `If the ID is valid and matches, tap ${L('Aprubahan', 'Approve')}.`,
    `If not, tap ${L('Hindi tanggap', 'Not accepted')}, type the reason (for example, a blurry photo), and tap ${L('Ipadala', 'Send')}. The person sees your reason.`,
  ] },
  { note: `${L('Aprubahan', 'Approve')} stays disabled until you have opened the photo — an ID has to be seen before it can be approved. ID photos are never saved on your phone.` },
  { h2: '6.5 Handling feedback' },
  { p: `Reports from drivers and commuters are listed under ${L('Kailangan ng atensyon', 'Needs attention')}. After acting on one, tap ${L('Markahang naresolba', 'Mark resolved')}. If the problem returns, tap ${L('Buksan ulit', 'Reopen')} under ${L('Naresolba', 'Resolved')}.` },
  { h2: '6.6 Dispatch settings' },
  { p: 'Changes here reach every phone within seconds, without an app update.' },
  { table: {
    head: ['Setting', 'Default', 'Allowed', 'What it does'],
    widths: [2500, 1100, 1300, 4460],
    rows: [
      ['**Search radius (km)**', '5', '0.5–50', 'Drivers farther than this are never offered the ride.'],
      ['**Offer timeout (seconds)**', '15', '5–120', 'How long one driver has to answer before the next is asked.'],
      [`${L('Bilang ng driver na susubukan', 'Drivers to try')}`, '10', '1–10', 'How many drivers are asked before the search stops.'],
    ],
  } },
  { p: `Tap ${L('I-save ang settings', 'Save settings')} after editing.` },
  { h3: 'Stopping bookings' },
  { p: `To halt the service, turn off ${L('Tumatanggap ng booking', 'Accepting bookings')} and confirm with ${L('Ihinto ang booking', 'Stop bookings')}. Commuters cannot book until you turn it back on. **Rides already in progress finish normally.**` },

  { pagebreak: true },
  { h1: '7. Your Data and Privacy' },
  { h2: '7.1 Your government ID' },
  { bullets: [
    'Only TODA chapter officers can see your ID, to confirm who you are. Other passengers and drivers cannot.',
    'The ID photo and details are deleted automatically **90 days** after you submit them, or immediately when you withdraw them.',
    `You can delete your ID at any time from the ID verification screen with ${L('Bawiin at burahin ang ID', 'Withdraw and delete the ID')}.`,
  ] },
  { h2: '7.2 Verification stays with your account' },
  { p: 'Deleting the ID photo does not undo your verification. Only the fact that you were verified is kept, with no ID details. It is removed when you delete your account.' },
  { h2: '7.3 What others see' },
  { table: {
    head: ['Who', 'Sees'],
    widths: [2600, 6760],
    rows: [
      ['A driver offered or assigned your ride', 'Your name, photo (if you added one), mobile number, pickup and drop-off.'],
      ['A commuter on your ride', 'The driver’s first name, plate number and live location.'],
      ['TODA administrators', 'Driver details, ride records, feedback, and submitted IDs for review.'],
    ],
  } },

  { h1: '8. Troubleshooting' },
  { p: 'Messages are listed in Filipino, with the English wording in brackets.' },
  { h2: '8.1 Signing in' },
  { table: {
    head: ['Message', 'What to do'],
    widths: [4200, 5160],
    rows: [
      [`${L('Mali ang code. Tingnan ulit ang message.', 'Wrong code. Check the message again.')}`, 'Type the six digits from the latest SMS.'],
      [`${L('Nag-expire na ang code. Humingi ng bago.', 'That code expired. Ask for a new one.')}`, `Go back and tap ${L('Ipadala ang code', 'Send code')} again.`],
      [`${L('Masyadong maraming subok…', 'Too many tries…')}`, 'Wait a few minutes before trying again.'],
      [`${L('Walang connection. Tingnan ang signal mo.', 'No connection. Check your signal.')}`, 'Move to a place with signal, or switch between mobile data and Wi-Fi.'],
      [`${L('Mukhang hindi ito mobile number.', 'That does not look like a mobile number.')}`, 'Enter an 11-digit number starting with 09.'],
    ],
  } },
  { h2: '8.2 ID verification' },
  { table: {
    head: ['Message', 'What to do'],
    widths: [4200, 5160],
    rows: [
      [`${L('Kailangan ng litrato ng ID.', 'A photo of the ID is required.')}`, 'Add a photo of the card before sending.'],
      [`${L('Kailangan mong pumayag muna.', 'You need to agree first.')}`, 'Tick the agreement box.'],
      [`${L('Hindi tinanggap ng server ang litrato…', 'The server refused the photo…')}`, 'Your ID may already be approved. Go back; if the app still asks for an ID, contact your TODA officer.'],
    ],
  } },
  { h2: '8.3 Booking' },
  { table: {
    head: ['Problem or message', 'What to do'],
    widths: [4200, 5160],
    rows: [
      ['No driver accepts and the booking screen comes back', 'No driver was available nearby. Try again in a few minutes.'],
      [`${L('Walang nakitang … malapit dito', 'Nothing called … found near here')}`, 'Drag the map to the area first, or place the pin by hand.'],
      [`${L('Tinatantiya — hindi maabot ang route service', 'Approximate — could not reach the route service')}`, 'The distance is an estimate. You can still book.'],
      [`${L('Hindi mabuksan ang dialler…', 'Could not open the dialler…')}`, 'Dial the number shown in the message by hand.'],
    ],
  } },
  { h2: '8.4 Going online (drivers)' },
  { table: {
    head: ['Message', 'What to do'],
    widths: [4200, 5160],
    rows: [
      [`${L('Naka-off ang location ng phone…', 'Your phone’s location is off…')}`, 'Turn on Location in the phone’s quick settings.'],
      [`${L('Kailangan ng location permission para mag-online.', 'Location permission is needed to go online.')}`, 'Try again and allow location access.'],
      [`${L('Naka-block ang location permission…', 'Location permission is blocked…')}`, 'Open the phone’s Settings > Apps > TrikeKoTo > Permissions > Location, and allow it.'],
      [`${L('Hindi makakuha ng location…', 'Cannot get a location fix…')}`, 'Move outdoors or near a window, then try again.'],
      [`${L('Hindi pinayagan ng server na mag-online…', 'The server refused to put you online…')}`, 'Check that your ID and registration are approved. If they are, send a screenshot to your TODA officer.'],
      [`${L('Hindi naisave sa server ang location mo…', 'Your location could not be saved…')}`, 'Check your internet connection, then try again.'],
      ['No offers arrive while Online', 'Check that notifications are allowed for TrikeKoTo, and that a commuter is within the search radius.'],
    ],
  } },
  { h2: '8.5 Getting help' },
  { p: 'Use the flag icon (Section 4.9) to send a report to your TODA administrator. Include what you were doing, and the message on screen if there was one. If the app closes unexpectedly, the error is recorded automatically for the project team.' },
];

// ── Markdown ────────────────────────────────────────────────────────────

function toMarkdown(blocks) {
  const out = [
    '# TrikeKoTo — End-User Manual',
    '',
    `*Version ${VERSION} · ${DATE}*`,
    '',
    '> Generated by `scripts/build_user_manual.cjs`. Edit the script and rebuild; do not edit this file by hand.',
    '',
  ];
  for (const b of blocks) {
    if (b.h1) out.push(`## ${b.h1}`, '');
    else if (b.h2) out.push(`### ${b.h2}`, '');
    else if (b.h3) out.push(`#### ${b.h3}`, '');
    else if (b.p) out.push(b.p, '');
    else if (b.steps) { b.steps.forEach((s, i) => out.push(`${i + 1}. ${s}`)); out.push(''); }
    else if (b.bullets) { b.bullets.forEach((s) => out.push(`- ${s}`)); out.push(''); }
    else if (b.note) out.push(`> **Note:** ${b.note}`, '');
    else if (b.figure) out.push(`![${b.figure}](manual/${b.file})`, '', `*${b.figure}*`, '');
    else if (b.table) {
      const t = b.table;
      const cell = (c) => c.replace(/\|/g, '\\|');
      out.push(`| ${t.head.map(cell).join(' | ')} |`, `|${t.head.map(() => '---').join('|')}|`);
      t.rows.forEach((r) => out.push(`| ${r.map(cell).join(' | ')} |`));
      out.push('');
    }
  }
  return out.join('\n');
}

// ── Word ────────────────────────────────────────────────────────────────

const FONT = 'Calibri';

function runs(text, extra = {}) {
  // **bold** segments become bold runs.
  return text.split(/(\*\*[^*]+\*\*)/).filter(Boolean).map((part) =>
    part.startsWith('**')
      ? new TextRun({ text: part.slice(2, -2), bold: true, font: FONT, ...extra })
      : new TextRun({ text: part, font: FONT, ...extra }));
}

function toDocx(blocks) {
  const numberingConfigs = [{
    reference: 'bullets',
    levels: [{ level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT,
      style: { paragraph: { indent: { left: 720, hanging: 360 } } } }],
  }];
  let listId = 0;
  const body = [];
  const cellBorder = { style: BorderStyle.SINGLE, size: 4, color: 'BFBFBF' };
  // Schema order is top, left, bottom, right; the validator rejects any other.
  const borders = { top: cellBorder, left: cellBorder, bottom: cellBorder, right: cellBorder };

  for (const b of blocks) {
    if (b.h1) body.push(new Paragraph({ heading: HeadingLevel.HEADING_1, children: runs(b.h1) }));
    else if (b.h2) body.push(new Paragraph({ heading: HeadingLevel.HEADING_2, children: runs(b.h2) }));
    else if (b.h3) body.push(new Paragraph({ heading: HeadingLevel.HEADING_3, children: runs(b.h3) }));
    else if (b.p) body.push(new Paragraph({ children: runs(b.p) }));
    else if (b.pagebreak) body.push(new Paragraph({ children: [new PageBreak()] }));
    else if (b.bullets) b.bullets.forEach((s) =>
      body.push(new Paragraph({ numbering: { reference: 'bullets', level: 0 }, children: runs(s) })));
    else if (b.steps) {
      // A separate numbering definition per list, so each starts again at 1.
      const ref = `steps-${listId++}`;
      numberingConfigs.push({ reference: ref, levels: [{ level: 0, format: LevelFormat.DECIMAL,
        text: '%1.', alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] });
      b.steps.forEach((s) =>
        body.push(new Paragraph({ numbering: { reference: ref, level: 0 }, children: runs(s) })));
    } else if (b.note) {
      body.push(new Paragraph({
        shading: { type: ShadingType.CLEAR, fill: 'EEF3F8', color: 'auto' },
        border: { left: { style: BorderStyle.SINGLE, size: 18, color: '2E5A88', space: 8 } },
        indent: { left: 200 },
        spacing: { before: 120, after: 200 },
        children: [new TextRun({ text: 'Note: ', bold: true, font: FONT }), ...runs(b.note)],
      }));
    } else if (b.figure) {
      const data = fs.readFileSync(path.join(root, 'docs', 'manual', b.file));
      // PNG width and height sit at fixed offsets in the IHDR chunk.
      const w = data.readUInt32BE(16), h = data.readUInt32BE(20);
      // Phone screens, so bounded by height as much as width.
      const scale = Math.min(260 / w, 500 / h);
      body.push(new Paragraph({
        alignment: AlignmentType.CENTER,
        keepNext: true,
        spacing: { before: 160, after: 60 },
        children: [new ImageRun({ type: 'png', data,
          transformation: { width: Math.round(w * scale), height: Math.round(h * scale) },
          altText: { title: b.figure, description: b.figure, name: b.file } })],
      }));
      body.push(new Paragraph({
        alignment: AlignmentType.CENTER, spacing: { after: 240 },
        children: [new TextRun({ text: b.figure, italics: true, size: 20, font: FONT })],
      }));
    } else if (b.table) {
      const t = b.table;
      const total = t.widths.reduce((a, c) => a + c, 0);
      const mkCell = (text, i, header) => new TableCell({
        width: { size: t.widths[i], type: WidthType.DXA },
        borders,
        shading: header ? { type: ShadingType.CLEAR, fill: 'DCE6F1', color: 'auto' } : undefined,
        margins: { top: 60, bottom: 60, left: 100, right: 100 },
        children: [new Paragraph({ spacing: { after: 0, line: 276 },
          children: header ? [new TextRun({ text, bold: true, font: FONT })] : runs(text) })],
      });
      body.push(new Table({
        width: { size: total, type: WidthType.DXA },
        columnWidths: t.widths,
        rows: [
          new TableRow({ tableHeader: true, children: t.head.map((h, i) => mkCell(h, i, true)) }),
          ...t.rows.map((r) => new TableRow({ children: r.map((c, i) => mkCell(c, i, false)) })),
        ],
      }));
      body.push(new Paragraph({ spacing: { after: 120 }, children: [] }));
    }
  }

  const title = [
    new Paragraph({ spacing: { before: 3000 }, alignment: AlignmentType.CENTER,
      children: [new TextRun({ text: 'TrikeKoTo', bold: true, size: 72, font: FONT, color: '1F3864' })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 400 },
      children: [new TextRun({ text: 'A Tricycle Ride-Hailing System for TODA', size: 30, font: FONT })] }),
    new Paragraph({ alignment: AlignmentType.CENTER,
      children: [new TextRun({ text: 'END-USER MANUAL', bold: true, size: 40, font: FONT })] }),
    new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 1200 },
      children: [new TextRun({ text: `Version ${VERSION}`, size: 24, font: FONT })] }),
    new Paragraph({ alignment: AlignmentType.CENTER,
      children: [new TextRun({ text: DATE, size: 24, font: FONT })] }),
    new Paragraph({ children: [new PageBreak()] }),
    new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: 'Table of Contents', font: FONT })] }),
    new TableOfContents('Table of Contents', { hyperlink: true, headingStyleRange: '1-2' }),
    new Paragraph({ children: [new TextRun({
      text: 'If the table above is empty, right-click it in Word and choose Update Field.',
      italics: true, size: 18, color: '8C8C8C', font: FONT })] }),
    new Paragraph({ children: [new PageBreak()] }),
  ];

  return new Document({
    creator: 'TrikeKoTo project',
    title: 'TrikeKoTo End-User Manual',
    features: { updateFields: true },
    numbering: { config: numberingConfigs },
    styles: {
      default: { document: { run: { font: FONT, size: 22 }, paragraph: { spacing: { after: 140, line: 300 } } } },
      paragraphStyles: [
        { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { size: 34, bold: true, color: '1F3864', font: FONT },
          paragraph: { spacing: { before: 360, after: 180 }, outlineLevel: 0 } },
        { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { size: 27, bold: true, color: '2E5A88', font: FONT },
          paragraph: { spacing: { before: 280, after: 120 }, outlineLevel: 1 } },
        { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { size: 23, bold: true, font: FONT },
          paragraph: { spacing: { before: 200, after: 100 }, outlineLevel: 2 } },
      ],
    },
    sections: [{
      properties: { page: { size: { width: 12240, height: 15840 },
        margin: { top: 1440, bottom: 1440, left: 1440, right: 1440 } } },
      footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER,
        children: [new TextRun({ children: ['TrikeKoTo End-User Manual — page ', PageNumber.CURRENT], size: 18, color: '7F7F7F', font: FONT })] })] }) },
      children: [...title, ...body],
    }],
  });
}

// ── Write both ──────────────────────────────────────────────────────────

const root = path.resolve(__dirname, '..');
const mdPath = path.join(root, 'docs', 'user-manual.md');
const docxPath = path.join(root, 'docs', 'TrikeKoTo-User-Manual.docx');

fs.writeFileSync(mdPath, toMarkdown(content) + '\n', 'utf8');
Packer.toBuffer(toDocx(content)).then((buf) => {
  fs.writeFileSync(docxPath, buf);
  const sections = content.filter((b) => b.h1).length;
  console.log(`wrote ${path.relative(root, mdPath)} and ${path.relative(root, docxPath)} (${sections} sections, ${fig} figures)`);
});
