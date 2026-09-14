// Builds the thesis proposal defense deck:
//
//   docs/TrikeKoTo-Proposal-Defense.pptx
//
// Run from trikekoto_app/ with pptxgenjs on the module path, e.g.
//   NODE_PATH=<folder containing node_modules/pptxgenjs> node scripts/build_defense_slides.cjs
//
// Screenshots come from docs/manual/, which test/manual/manual_screenshots_test.dart
// renders from the shipped screens over made-up data. Speaker notes carry the
// talking points for each slide.
'use strict';

const path = require('path');
const pptxgen = require('pptxgenjs');

const root = path.resolve(__dirname, '..');
const shot = (f) => path.join(root, 'docs', 'manual', f);

// ── Palette: the app's own navy and amber ───────────────────────────────
const NAVY = '14213D';
const AMBER = 'F5A524';
const INK = '1B2433';
const MUTED = '5B6472';
const LIGHT = 'F2F4F8';
const LINE = 'D3D9E2';
const WHITE = 'FFFFFF';
const PALE = 'D6DEEA';
const FONT = 'Calibri';

const PHONE = 780 / 1688; // width / height of a phone screenshot

const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE'; // 13.333 x 7.5 in
pres.title = 'TrikeKoTo — Thesis Proposal Defense';
pres.author = 'Jelo Jian Sabroso';

// ── Helpers ─────────────────────────────────────────────────────────────
function text(slide, str, opts) {
  slide.addText(str, { fontFace: FONT, color: INK, margin: 0, isTextBox: true, ...opts });
}

function heading(slide, kicker, title) {
  text(slide, kicker.toUpperCase(), { x: 0.6, y: 0.35, w: 12.1, h: 0.3, fontSize: 12, bold: true, color: 'B7780A', charSpacing: 2 });
  text(slide, title, { x: 0.6, y: 0.7, w: 12.1, h: 0.8, fontSize: 34, bold: true, valign: 'top' });
}

function badge(slide, label, x, y, d = 0.6, fill = AMBER, color = NAVY) {
  slide.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color: fill }, line: { color: fill } });
  text(slide, label, { x, y, w: d, h: d, fontSize: d * 26, bold: true, color, align: 'center', valign: 'middle' });
}

function card(slide, x, y, w, h, fill = LIGHT, line = fill) {
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, fill: { color: fill }, line: { color: line, width: 1 }, rectRadius: 0.12 });
}

function phone(slide, file, x, y, h, ratio = PHONE) {
  const w = h * ratio;
  slide.addShape(pres.shapes.ROUNDED_RECTANGLE, {
    x: x - 0.09, y: y - 0.09, w: w + 0.18, h: h + 0.18,
    fill: { color: WHITE }, line: { color: LINE, width: 1 }, rectRadius: 0.14,
    shadow: { type: 'outer', color: '000000', opacity: 0.18, blur: 8, offset: 2, angle: 90 },
  });
  slide.addImage({ path: shot(file), x, y, w, h });
  return w;
}

function arrow(slide, x, y, w, h = 0) {
  slide.addShape(pres.shapes.LINE, { x, y, w, h, line: { color: MUTED, width: 1.5, endArrowType: 'triangle' } });
}

// ── 1. Title ────────────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: NAVY };
  text(s, 'THESIS PROPOSAL DEFENSE', { x: 0.8, y: 1.2, w: 7.6, h: 0.35, fontSize: 14, bold: true, color: AMBER, charSpacing: 3 });
  text(s, 'TrikeKoTo', { x: 0.8, y: 1.65, w: 7.6, h: 1.2, fontSize: 64, bold: true, color: WHITE });
  text(s, 'A Tricycle Ride-Hailing and Dispatch System\nfor TODA Chapters', { x: 0.8, y: 2.9, w: 8.3, h: 1.1, fontSize: 26, color: PALE, valign: 'top' });
  text(s, 'Jelo Jian Sabroso', { x: 0.8, y: 4.55, w: 7.6, h: 0.45, fontSize: 20, bold: true, color: WHITE });
  text(s, 'President Ramon Magsaysay State University – San Marcelino', { x: 0.8, y: 5.0, w: 7.6, h: 0.4, fontSize: 16, color: PALE });
  text(s, 'September 2026', { x: 0.8, y: 5.4, w: 7.6, h: 0.4, fontSize: 16, color: PALE });
  phone(s, 'fig-3-booking.png', 9.55, 0.6, 6.3);
  s.addNotes(
    'Good day, panel. I am Jelo Jian Sabroso, and this is my proposal: TrikeKoTo, a tricycle ride-hailing and dispatch system built for TODA chapters.\n' +
    'In one sentence: a commuter books the nearest available TODA tricycle from a phone, while the chapter stays in control of who drives, what the fare is, and who can use the system.');
}

// ── 2. Problem ──────────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  heading(s, 'Background', 'The problem');
  const items = [
    ['Commuters wait', 'Passengers walk to a terminal or wait by the road without knowing whether a tricycle is coming — worst at night and in the rain.'],
    ['Drivers roam empty', 'Drivers circle for passengers or queue at the terminal, spending fuel and hours without a fare.'],
    ['No trust, no record', 'Bookings by text or call leave no record of who rode with whom, and nothing a TODA chapter can check.'],
  ];
  items.forEach(([h, b], i) => {
    const x = 0.6 + i * 4.14;
    card(s, x, 1.85, 3.9, 3.55);
    badge(s, String(i + 1), x + 0.35, 2.2);
    text(s, h, { x: x + 0.35, y: 3.05, w: 3.2, h: 0.5, fontSize: 22, bold: true });
    text(s, b, { x: x + 0.35, y: 3.6, w: 3.2, h: 1.65, fontSize: 16, color: MUTED, valign: 'top', lineSpacingMultiple: 1.1 });
  });
  card(s, 0.6, 5.75, 12.1, 1.1, NAVY);
  text(s, 'The gap: general ride-hailing apps either leave TODA tricycles out, or go around the chapter that already decides who drives and what they charge.',
    { x: 0.95, y: 5.75, w: 11.4, h: 1.1, fontSize: 18, color: WHITE, valign: 'middle' });
  s.addNotes(
    'Three sides of one problem. Commuters wait blind. Drivers waste fuel looking for passengers. And informal bookings leave no record, which matters for safety and for the chapter.\n' +
    'Close with the gap: existing apps do not serve TODA tricycles, or they bypass the TODA structure that already governs who may drive and what they may charge.');
}

// ── 3. Why TrikeKoTo ────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  heading(s, 'Proposed solution', 'Built with the TODA, not around it');
  const colA = 3.05, colB = 7.95, wA = 4.7, wB = 4.75;
  text(s, 'General ride-hailing apps', { x: colA, y: 1.75, w: wA, h: 0.5, fontSize: 18, bold: true, color: MUTED, align: 'center' });
  text(s, 'TrikeKoTo', { x: colB, y: 1.75, w: wB, h: 0.5, fontSize: 18, bold: true, color: NAVY, align: 'center' });
  const rows = [
    ['Who drives', 'Anyone who signs up', 'TODA members approved by their chapter'],
    ['Fare', 'Set by the app', 'The posted TODA tariff, paid in cash'],
    ['Chapter control', 'None', 'Officers approve, suspend, and can stop all bookings at once'],
    ['Identity', 'Varies by app', 'Every driver and commuter ID-verified by the chapter'],
  ];
  rows.forEach(([label, a, b], i) => {
    const y = 2.4 + i * 1.12;
    text(s, label, { x: 0.6, y, w: 2.3, h: 0.95, fontSize: 18, bold: true, valign: 'middle' });
    card(s, colA, y, wA, 0.95, LIGHT);
    text(s, a, { x: colA + 0.3, y, w: wA - 0.6, h: 0.95, fontSize: 16, color: MUTED, valign: 'middle' });
    card(s, colB, y, wB, 0.95, NAVY);
    text(s, b, { x: colB + 0.3, y, w: wB - 0.6, h: 0.95, fontSize: 16, color: WHITE, bold: true, valign: 'middle' });
  });
  s.addNotes(
    'This is the question the panel will ask first: why not Grab or Move It?\n' +
    'The answer is the right column. The chapter decides who drives. The fare is the ordinance tariff, so the app shows no price that could disagree with the posted one. Officers can approve, suspend, and stop bookings instantly. And every account is verified by the chapter.');
}

// ── 4. Objectives ───────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  heading(s, 'Objectives', 'What this study will do');
  card(s, 0.6, 1.8, 4.5, 5.1, NAVY);
  text(s, 'GENERAL OBJECTIVE', { x: 0.95, y: 2.15, w: 3.8, h: 0.35, fontSize: 13, bold: true, color: AMBER, charSpacing: 2 });
  text(s, 'To design and develop TrikeKoTo, a mobile and web ride-hailing system that connects commuters with the nearest available TODA tricycle while keeping dispatch, driver verification and records under the chapter\'s control.',
    { x: 0.95, y: 2.6, w: 3.8, h: 4.0, fontSize: 18, color: WHITE, valign: 'top', lineSpacingMultiple: 1.15 });
  const objs = [
    ['Book and dispatch', 'Let commuters book a ride that is offered automatically to the nearest available driver, with live tracking.'],
    ['Verify and administer', 'Let the TODA chapter approve drivers, verify government IDs, and monitor rides and feedback.'],
    ['Protect personal data', 'Secure personal information in line with the Data Privacy Act of 2012 (RA 10173).'],
    ['Evaluate', 'Assess usability and acceptance with TODA drivers and commuters, using task testing and the System Usability Scale.'],
  ];
  objs.forEach(([h, b], i) => {
    const y = 1.8 + i * 1.3;
    badge(s, String(i + 1), 5.6, y + 0.05);
    text(s, h, { x: 6.45, y, w: 6.3, h: 0.42, fontSize: 19, bold: true });
    text(s, b, { x: 6.45, y: y + 0.42, w: 6.3, h: 0.8, fontSize: 15, color: MUTED, valign: 'top' });
  });
  s.addNotes(
    'Match these to the exact wording in your manuscript before presenting — edit this slide if your chapter 1 phrases them differently.\n' +
    'Specific objectives: one, booking and automatic nearest-driver dispatch; two, chapter administration and ID verification; three, data privacy under RA 10173; four, evaluation with real drivers and commuters.');
}

// ── 5. Scope and limitations ────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  heading(s, 'Scope and limitations', 'What is in, and what is not');
  const cols = [
    ['Scope', NAVY, [
      'Commuter: mobile-number sign-in, booking, live tracking, cancelling, rating, feedback',
      'Driver: registration, online/offline, ride offers, trip controls, navigation',
      'TODA officer: driver approval, ID review, ride figures, feedback, dispatch settings',
      'Android app and web version, in Filipino and English',
      'One TODA chapter in San Marcelino, Zambales',
    ]],
    ['Limitations', 'B7780A', [
      'Booking needs mobile data or Wi-Fi',
      'Rides go only to online drivers within the search radius',
      'No in-app payment — the posted fare is paid in cash',
      'A new user can book or drive only after an officer approves their ID',
      'Maps and routing use free public OpenStreetMap services',
    ]],
  ];
  cols.forEach(([title, color, items], i) => {
    const x = 0.6 + i * 6.2;
    card(s, x, 1.8, 5.9, 5.1);
    text(s, title, { x: x + 0.4, y: 2.05, w: 5.1, h: 0.5, fontSize: 22, bold: true, color });
    s.addText(items.map((t, k) => ({ text: t, options: { bullet: true, breakLine: k < items.length - 1 } })),
      { x: x + 0.4, y: 2.7, w: 5.1, h: 4.0, fontFace: FONT, fontSize: 16, color: INK, paraSpaceAfter: 10, valign: 'top', margin: 0, isTextBox: true });
  });
  s.addNotes(
    'Say the limitations before the panel does — it reads as understanding, not weakness.\n' +
    'The biggest practical limit: it only works where drivers are online, so adoption by the chapter is what makes it useful.');
}

// ── 6. Architecture ─────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  heading(s, 'System architecture', 'One app, one secure backend');
  const users = [['Commuter', 'Android · Web'], ['Driver', 'Android'], ['TODA officer', 'Android · Web']];
  users.forEach(([h, b], i) => {
    const y = 2.0 + i * 1.3;
    card(s, 0.6, y, 2.8, 1.05, LIGHT);
    text(s, h, { x: 0.85, y: y + 0.15, w: 2.4, h: 0.4, fontSize: 17, bold: true });
    text(s, b, { x: 0.85, y: y + 0.55, w: 2.4, h: 0.35, fontSize: 13, color: MUTED });
    arrow(s, 3.45, y + 0.52, 0.7);
  });
  card(s, 4.2, 2.0, 2.6, 3.65, NAVY);
  text(s, 'TrikeKoTo app', { x: 4.4, y: 2.5, w: 2.2, h: 0.5, fontSize: 20, bold: true, color: WHITE, align: 'center' });
  text(s, 'Flutter · Dart', { x: 4.4, y: 3.05, w: 2.2, h: 0.4, fontSize: 15, color: AMBER, bold: true, align: 'center' });
  text(s, 'One codebase for Android and the web', { x: 4.4, y: 3.6, w: 2.2, h: 1.2, fontSize: 14, color: PALE, align: 'center', valign: 'top' });
  arrow(s, 6.85, 3.82, 0.7);
  card(s, 7.6, 2.0, 5.15, 3.65, LIGHT);
  text(s, 'Firebase (Google Cloud)', { x: 7.85, y: 2.1, w: 4.6, h: 0.45, fontSize: 17, bold: true });
  const services = [
    ['Authentication', 'Phone and email sign-in'],
    ['Cloud Firestore', 'Rides, drivers, security rules'],
    ['Cloud Functions', 'Dispatch, ratings, ID retention'],
    ['Cloud Storage', 'ID photos, profile photos'],
    ['Cloud Messaging', 'Ride offer notifications'],
    ['App Check', 'Only the genuine app gets in'],
  ];
  services.forEach(([h, b], i) => {
    const x = 7.8 + (i % 2) * 2.45, y = 2.62 + Math.floor(i / 3 * 0) + Math.floor(i / 2) * 0.98;
    card(s, x, y, 2.3, 0.85, WHITE, LINE);
    text(s, h, { x: x + 0.15, y: y + 0.08, w: 2.0, h: 0.35, fontSize: 14, bold: true });
    text(s, b, { x: x + 0.15, y: y + 0.43, w: 2.0, h: 0.35, fontSize: 11, color: MUTED });
  });
  arrow(s, 5.5, 5.7, 0, 0.45);
  card(s, 4.2, 6.2, 8.55, 0.65, WHITE, LINE);
  text(s, 'Maps: OpenStreetMap tiles · OSRM road routing · Nominatim place search',
    { x: 4.45, y: 6.2, w: 8.1, h: 0.65, fontSize: 14, color: INK, valign: 'middle' });
  s.addNotes(
    'Three users, one Flutter codebase, and Firebase as the backend.\n' +
    'Key design point: the phone is never trusted. Every read and write is checked by server-side security rules, and the nearest-driver search runs in Cloud Functions, so no commuter app can see where every driver is.');
}

// ── 7. Dispatch ─────────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  heading(s, 'How a booking works', 'Nearest available driver, one at a time');
  const steps = [
    ['Commuter books', 'Pickup and drop-off set on the map'],
    ['Server searches', 'Approved drivers within 5 km, ranked by road distance'],
    ['Offer to nearest', 'That driver has 15 seconds to accept'],
    ['Next if no answer', 'Up to 10 drivers, for up to 5 minutes'],
    ['Ride accepted', 'Live tracking to the drop-off, then a rating'],
  ];
  steps.forEach(([h, b], i) => {
    const x = 0.6 + i * 2.5;
    badge(s, String(i + 1), x, 1.85, 0.7);
    if (i < steps.length - 1) arrow(s, x + 0.85, 2.2, 1.5);
    text(s, h, { x, y: 2.75, w: 2.3, h: 0.45, fontSize: 17, bold: true });
    text(s, b, { x, y: 3.2, w: 2.2, h: 1.1, fontSize: 14, color: MUTED, valign: 'top' });
  });
  const stats = [
    ['5 km', 'Search radius, set by the chapter'],
    ['15 s', 'For each driver to answer an offer'],
    ['1 winner', 'If two drivers tap Accept at once, a database transaction lets exactly one claim the ride'],
  ];
  stats.forEach(([big, label], i) => {
    const x = 0.6 + i * 4.14;
    card(s, x, 4.65, 3.9, 2.25);
    text(s, big, { x: x + 0.35, y: 4.85, w: 3.2, h: 0.95, fontSize: 44, bold: true, color: NAVY });
    text(s, label, { x: x + 0.35, y: 5.8, w: 3.2, h: 0.95, fontSize: 14, color: MUTED, valign: 'top' });
  });
  s.addNotes(
    'This is a greedy nearest-first search. Straight-line distance shortlists drivers inside the radius, then road distance picks the nearest. One driver is offered the ride at a time; if they decline or do not answer in 15 seconds, the next is asked.\n' +
    'If the commuter closes the app, a scheduled server job keeps the search going every minute.\n' +
    'Double booking is prevented by a transaction plus a security rule — tested with simultaneous accepts.');
}

// ── 8. Commuter screens ─────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: LIGHT };
  heading(s, 'Prototype', 'The commuter experience');
  const shots = [
    ['fig-2-sign-in.png', 'Sign in with a mobile number'],
    ['fig-3-booking.png', 'Set pickup and drop-off'],
    ['fig-4-tracking.png', 'Track the tricycle live'],
  ];
  const h = 4.55, w = h * PHONE;
  shots.forEach(([f, cap], i) => {
    const cx = 2.4 + i * 4.27;
    phone(s, f, cx - w / 2, 1.75, h);
    text(s, `${i + 1}. ${cap}`, { x: cx - 1.9, y: 6.45, w: 3.8, h: 0.45, fontSize: 16, bold: true, align: 'center' });
  });
  s.addNotes(
    'These are the actual screens of the working prototype, in Filipino, which is the app\'s default language; English is one tap away.\n' +
    'Sign in with an SMS code, set pickup and drop-off — pickup fills in from GPS — then follow the tricycle on the map with the driver\'s name, plate and a call button.\n' +
    'If you do a live demo, do it here, and keep it to two minutes.');
}

// ── 9. Driver and chapter ───────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  heading(s, 'Prototype', 'Tools for drivers and the chapter');
  phone(s, 'fig-5-driver-online.png', 0.7, 1.75, 4.7);
  const rw = 3.05, rh = rw / (780 / 960);
  phone(s, 'fig-7-id-review.png', 3.35, 1.75, rh, 780 / 960);
  text(s, 'Driver screen', { x: 0.55, y: 6.55, w: 2.5, h: 0.4, fontSize: 13, color: MUTED, align: 'center' });
  text(s, 'ID review by an officer', { x: 3.35, y: 1.75 + rh + 0.2, w: rw, h: 0.4, fontSize: 13, color: MUTED, align: 'center' });
  const rows = [
    ['Drivers', 'Go online with one switch, get offers by notification, and run each trip: start, complete, call, navigate.'],
    ['Chapter officers', 'Approve or suspend drivers, review IDs — the photo must be opened before Approve works — and see daily ride figures.'],
    ['Stop switch', 'One switch halts new bookings on every phone within seconds, with no app update. Rides in progress still finish.'],
  ];
  rows.forEach(([h, b], i) => {
    const y = 1.8 + i * 1.7;
    badge(s, String.fromCharCode(65 + i), 6.85, y);
    text(s, h, { x: 7.7, y, w: 5.05, h: 0.45, fontSize: 20, bold: true });
    text(s, b, { x: 7.7, y: y + 0.45, w: 5.05, h: 1.1, fontSize: 15, color: MUTED, valign: 'top' });
  });
  s.addNotes(
    'Drivers need very little: one switch to go online, and big buttons for each step of the trip.\n' +
    'The chapter officer is the control point. They approve drivers and IDs, and the Approve button stays off until the ID photo has actually been opened — approval has to mean somebody looked.\n' +
    'The stop switch is the rollback for a pilot: it stops new bookings everywhere without reinstalling anything.');
}

// ── 10. Security and privacy ────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  heading(s, 'Security and data privacy', 'Designed for RA 10173 from the start');
  const stats = [
    ['216', 'automated security-rule tests, including attack scenarios'],
    ['90 days', 'after sending, ID photos and numbers are deleted automatically'],
    ['0', 'open findings after the September 2026 security review'],
  ];
  stats.forEach(([big, label], i) => {
    const y = 1.8 + i * 1.72;
    card(s, 0.6, y, 4.6, 1.55, NAVY);
    text(s, big, { x: 0.9, y: y + 0.12, w: 4.0, h: 0.8, fontSize: 40, bold: true, color: AMBER });
    text(s, label, { x: 0.9, y: y + 0.9, w: 4.0, h: 0.55, fontSize: 14, color: WHITE, valign: 'top' });
  });
  const rows = [
    ['Chapter-only access', 'Only TODA officers can see a submitted ID. Other passengers and drivers never can.'],
    ['Consent on record', 'Users read how their ID is used and tick consent; the time is stored with it.'],
    ['Right to withdraw', 'Commuters can delete their ID and their account from inside the app.'],
    ['Genuine app only', 'App Check refuses scripts and modified apps at the database and at dispatch.'],
  ];
  rows.forEach(([h, b], i) => {
    const y = 1.8 + i * 1.18;
    badge(s, String(i + 1), 5.7, y + 0.05, 0.55);
    text(s, h, { x: 6.5, y, w: 6.25, h: 0.42, fontSize: 18, bold: true });
    text(s, b, { x: 6.5, y: y + 0.42, w: 6.25, h: 0.7, fontSize: 14, color: MUTED, valign: 'top' });
  });
  text(s, 'An ethics and data-privacy review will be completed before any real ID is collected.',
    { x: 5.7, y: 6.5, w: 7.05, h: 0.45, fontSize: 15, italic: true, color: INK });
  s.addNotes(
    'Government IDs are sensitive personal information under RA 10173, so this was designed in, not added later.\n' +
    'Access is limited to chapter officers, consent is recorded, retention is enforced by a scheduled job at 90 days, and users can withdraw.\n' +
    'Say the last line yourself: real IDs will not be collected until the university ethics review is done. The panel will respect that you raised it.');
}

// ── 11. Methodology ─────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  heading(s, 'Methodology', 'How it is built and how it will be evaluated');
  text(s, 'Development — iterative, in phases', { x: 0.6, y: 1.8, w: 5.8, h: 0.45, fontSize: 20, bold: true });
  const phases = ['Requirements and design', 'Backend and security rules', 'Commuter, driver and admin features', 'Maps and notifications', 'Testing and security review', 'Deployment: Android app and web'];
  phases.forEach((p, i) => {
    const y = 2.4 + i * 0.75;
    badge(s, String(i + 1), 0.6, y, 0.5);
    text(s, p, { x: 1.3, y, w: 5.1, h: 0.5, fontSize: 16, valign: 'middle' });
  });
  card(s, 6.9, 1.8, 5.85, 5.1, LIGHT);
  text(s, 'Evaluation — user acceptance testing', { x: 7.25, y: 2.05, w: 5.2, h: 0.45, fontSize: 20, bold: true });
  const evalItems = [
    'Participants: 5 TODA drivers and 5 commuters, on their own phones, in Filipino',
    'Tasks: sign up, send an ID, book, track, cancel, rate; drivers go online and complete a trip',
    'Measures: task completion, time on task, errors, and the System Usability Scale (SUS)',
    'Debrief: would drivers use it for real work?',
    'Then a small pilot with the chapter, with daily monitoring and stop thresholds',
  ];
  s.addText(evalItems.map((t, k) => ({ text: t, options: { bullet: true, breakLine: k < evalItems.length - 1 } })),
    { x: 7.25, y: 2.65, w: 5.2, h: 4.1, fontFace: FONT, fontSize: 15, color: INK, paraSpaceAfter: 9, valign: 'top', margin: 0, isTextBox: true });
  s.addNotes(
    'Use the development model name your manuscript uses (for example Agile or Rapid Application Development) — these six phases map onto either.\n' +
    'Evaluation: five and five is the usability-testing norm for finding most problems; SUS gives a standard score, reported with n = 10 so it is not overclaimed. The debrief question for drivers is the real acceptance test.');
}

// ── 12. Progress ────────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: WHITE };
  heading(s, 'Current status', 'A working prototype, ready for testing');
  card(s, 0.6, 1.8, 4.3, 5.1, NAVY);
  text(s, '89 / 93', { x: 0.9, y: 2.3, w: 3.7, h: 1.2, fontSize: 60, bold: true, color: WHITE });
  text(s, 'build steps complete', { x: 0.9, y: 3.5, w: 3.7, h: 0.45, fontSize: 18, color: PALE });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.9, y: 4.3, w: 3.7, h: 0.3, fill: { color: '2C3A58' }, line: { color: '2C3A58' }, rectRadius: 0.15 });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.9, y: 4.3, w: 3.7 * 89 / 93, h: 0.3, fill: { color: AMBER }, line: { color: AMBER }, rectRadius: 0.15 });
  text(s, 'The four remaining steps depend on others: testing with the chapter, a language review, the pilot, and moving old records from the earlier web app.',
    { x: 0.9, y: 4.9, w: 3.7, h: 1.7, fontSize: 14, color: PALE, valign: 'top' });
  const cols = [
    ['Done', [
      'Android app and web version, deployed',
      'Nearest-driver dispatch on the server',
      'ID verification with automatic deletion',
      '216 security tests and a security review',
      'User manual and testing kit',
    ]],
    ['Next', [
      'User acceptance testing with the chapter',
      'Native Filipino language review',
      'Ethics and data-privacy clearance',
      'Pilot rollout with the chapter',
    ]],
  ];
  cols.forEach(([title, items], i) => {
    const x = 5.3 + i * 3.8;
    text(s, title, { x, y: 1.85, w: 3.5, h: 0.5, fontSize: 22, bold: true, color: i === 0 ? NAVY : 'B7780A' });
    s.addText(items.map((t, k) => ({ text: t, options: { bullet: true, breakLine: k < items.length - 1 } })),
      { x, y: 2.5, w: 3.5, h: 4.3, fontFace: FONT, fontSize: 16, color: INK, paraSpaceAfter: 12, valign: 'top', margin: 0, isTextBox: true });
  });
  s.addNotes(
    'Be exact about status. The prototype is built, deployed and tested; it is not yet cleared for real users.\n' +
    'What remains all needs people: the chapter for testing, a native speaker for the Filipino, the ethics committee, and then the pilot.');
}

// ── 13. Closing ─────────────────────────────────────────────────────────
{
  const s = pres.addSlide();
  s.background = { color: NAVY };
  text(s, 'Salamat po.', { x: 0.8, y: 2.1, w: 7.8, h: 1.3, fontSize: 60, bold: true, color: WHITE });
  text(s, 'Questions and live demo', { x: 0.8, y: 3.45, w: 7.8, h: 0.6, fontSize: 28, color: AMBER, bold: true });
  text(s, 'TrikeKoTo — a tricycle ride-hailing and dispatch system for TODA', { x: 0.8, y: 4.5, w: 7.8, h: 0.5, fontSize: 18, color: PALE });
  text(s, 'Jelo Jian Sabroso · PRMSU – San Marcelino', { x: 0.8, y: 5.0, w: 7.8, h: 0.5, fontSize: 18, color: PALE });
  phone(s, 'fig-4-tracking.png', 9.55, 0.6, 6.3);
  s.addNotes(
    'Thank the panel and invite questions.\n' +
    'If a question has no ready answer: "Thank you, I will include that in the revision." Do not guess.\n' +
    'Demo only if the signal in the room is good; otherwise use the screenshots on slides 8 and 9.');
}

const out = path.join(root, 'docs', 'TrikeKoTo-Proposal-Defense.pptx');
pres.writeFile({ fileName: out }).then(() => console.log('wrote ' + path.relative(root, out)));
