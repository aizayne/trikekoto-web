# TrikeKoTo

Real-time trike ride-hailing for your community. A Progressive Web App built with React + Vite + Firebase.

## Features

- **Commuter booking** — Enter pickup / dropoff, get matched with a nearby driver, watch the trike approach on a live map.
- **Driver dashboard** — Toggle online, receive nearby ride requests (Haversine-filtered within 5 km), accept with an atomic Firestore transaction.
- **Admin panel** — Approve / suspend driver registrations. Admin membership is enforced server-side via Firestore rules.
- **PWA offline shell** — Service worker caches the app shell and OpenStreetMap tiles; Firebase API calls bypass the cache.
- **FCM push notifications** — Drivers are notified of new ride requests even when the tab is backgrounded.

## Tech stack

- React 19 + Vite 8
- Firebase 12 (Auth, Firestore, Cloud Messaging)
- Leaflet + react-leaflet (OpenStreetMap tiles)
- lucide-react (icons)
- nosleep.js (keeps the driver's screen awake while online)

## Getting started

### 1. Prerequisites

- Node.js 20+ and npm
- A Firebase project with Auth (Email/Password), Firestore, and Cloud Messaging enabled
- The Firebase CLI (`npm i -g firebase-tools`) for deploying rules and hosting

### 2. Configure environment variables

```sh
cp .env.example .env.local
```

Fill in `.env.local` with values from the Firebase Console:

- `VITE_FIREBASE_*` — found under **Project Settings → General → Your apps**
- `VITE_FIREBASE_VAPID_KEY` — found under **Project Settings → Cloud Messaging → Web Push certificates → Generate key pair**

### 3. Install and run

```sh
npm install
npm run dev
```

The first time you run `npm run dev` or `npm run build`, Vite generates `public/firebase-messaging-sw.js` from `firebase-messaging-sw.template.js` using your `.env.local` values. The generated file is git-ignored — edit the template instead.

### 4. Deploy Firestore rules (first time and any time `firestore.rules` changes)

```sh
firebase deploy --only firestore:rules
```

### 5. Build and deploy hosting

```sh
npm run build
firebase deploy --only hosting
```

## Admin setup

Admin access is gated by the existence of a document in the `admins/` Firestore collection — **not** by a list in client code. Doc IDs must be **lowercase** (the rules compare case-insensitively, but storing lowercased keeps everything consistent).

Two ways to grant admin rights:

**Script path (recommended for batch work)**
1. Firebase Console → Project Settings → Service Accounts → Generate new private key
2. Save the JSON as `service-account.json` in the repo root (already git-ignored)
3. `npm run seed-admin alice@example.com bob@example.com`

**Console path (quick one-off)**
1. Firebase Console → Firestore → Start collection `admins`
2. Doc ID: the admin's email in lowercase. Body can be empty (`{}`).
3. That user can now navigate to `https://your-site/#/admin` while signed in.

Admins can:

- View all driver registrations, filtered by status
- Approve drivers (`Pending Verification` → `Active`)
- Suspend drivers (`Active` → `Suspended`)

The rules in `firestore.rules` enforce that only admins can change `status`.

## Architecture notes

### Data model

```
drivers/{email}
  firstName, lastName, phone, plateNumber, email
  status: "Pending Verification" | "Active" | "Suspended"
  createdAt

active_drivers/{email}              # live presence
  isOnline, location: {lat, lng, accuracy}
  fcmToken, updatedAt

rides/{rideId}                      # commuter requests
  pickup, dropoff, commuter, commuterPhone, notes
  pickupCoords: {lat, lng}
  status: "searching" | "accepted" | "completed" | "cancelled"
  assignedDriver, driverLocation
  createdAt, acceptedAt, cancelledAt, completedAt

admins/{email}                      # presence = admin (empty doc)
```

### Ride matching — greedy nearest driver

New ride requests are not broadcast to every nearby driver at once. Instead, `DriverDashboard.jsx` runs a **time-expanding greedy algorithm**:

1. Every driver's browser subscribes to `active_drivers` (where `isOnline == true`) and to `rides` (where `status == "searching"`).
2. For each searching ride, the client computes a **deterministic ranking** of all online drivers by haversine distance to `pickupCoords`, using the driver's email as a tiebreaker so every client arrives at the same ordering independently.
3. Each ride's **offer depth** starts at 1 (only the closest driver sees it) and expands by one every `OFFER_EXPAND_MS` (15 seconds), capped at `MAX_OFFER_RANK` (10 drivers).
4. A driver's dashboard only shows a ride if their own rank is strictly less than the current offer depth — i.e., they're currently inside the "offered slice".
5. When a driver taps **Accept**, a Firestore transaction reads the ride doc and only proceeds if `status === "searching"`. If two drivers race, Firestore serializes them — the loser sees an "already taken" toast and the ride card vanishes.

Because ranking is deterministic and every client sees the same view of `active_drivers` via real-time listeners, **no central coordinator is needed**: each client independently and consistently computes whose turn it is.

The ride card UI shows a priority badge (`Closest · 1st offer`, `2nd closest`, etc.) so the driver knows why they're seeing the request.

Tunables live at the top of `DriverDashboard.jsx`:
- `PROXIMITY_KM` — drivers outside this radius never enter the ranking
- `OFFER_EXPAND_MS` — how long each driver gets exclusive right of refusal
- `MAX_OFFER_RANK` — hard cap so a stale ride doesn't broadcast forever
- `RIDE_MAX_AGE_MS` — rides older than this are hidden client-side

### Identity model — email as document ID

TrikeKoTo uses the driver's **email address** as the Firestore document ID
for `drivers/`, `active_drivers/`, and `admins/`. That means:

- Every driver document has exactly one row, and the row itself is findable
  the moment you know who the driver is — no extra index.
- Firestore rules can gate writes with a simple `isSelf(email)` check
  instead of an extra `uid → email` lookup.
- Debugging is trivial: copy a doc ID, paste it into auth logs, done.

The tradeoff is that emails are case-preserved in Firebase Auth (`Foo@Bar.com`
and `foo@bar.com` authenticate the same account but return the original
casing). To avoid case drift between Auth tokens and Firestore doc IDs,
**every email that becomes a doc ID passes through `src/utils/email.js`'s
`normalizeEmail()` helper** first, which lowercases and trims. The
Firestore rules compare with `.lower()` on both sides so existing pre-
normalization docs still work.

If you ever need to switch to UID-based IDs (for example, to support
email-change flows), the migration path is: store `uid` as a field on
each driver doc, add a new collection `uid_to_email`, dual-write during
a transition window, then flip reads over.

### Screen routing

No `react-router` — `App.jsx` uses a simple state machine (`landing` / `commuter` / `driver-login` / `driver-register` / `driver-dashboard` / `admin`). The admin panel is reachable via the URL hash `/#/admin`; a `hashchange` listener lets paste-navigation work after the app has loaded.

### Service workers

Two service workers live in `public/`:

- `sw.js` — App shell cache + OpenStreetMap tile cache. Firebase API calls are explicitly bypassed.
- `firebase-messaging-sw.js` — **Generated** from the template at build time. Handles background push notifications. Do not edit directly.

## Scripts

| Command | Purpose |
| --- | --- |
| `npm run dev` | Local dev server with HMR |
| `npm run build` | Production build to `dist/` |
| `npm run preview` | Preview the production build locally |
| `npm run lint` | Run ESLint |
| `npm run icons` | Regenerate PWA icons from `scripts/icon-source.svg` |
| `npm run seed-admin <email>` | Create an `admins/{email}` doc (needs `service-account.json`) |

## Project layout

```
src/
  App.jsx                          # top-level screen router
  main.jsx                         # entrypoint + NotifyProvider + SW registration
  firebase.js                      # Firebase SDK initialization
  index.css                        # global reset + shared animations
  components/
    DriverDashboard.jsx
  contexts/
    NotifyContext.jsx              # in-app toast + confirm modal
  pages/
    CommuterBooking.jsx
    DriverLogin.jsx
    DriverRegister.jsx
    AdminPanel.jsx
  hooks/
    usePushNotifications.js
  utils/
    email.js                       # normalizeEmail() for doc-ID safety
  assets/                          # (images referenced by components)

public/
  sw.js                            # PWA shell service worker
  manifest.json
  icons/                           # PWA + favicon PNGs (generated — see scripts/)

scripts/
  icon-source.svg                  # source of truth for the app icon
  generate-icons.mjs               # `npm run icons` rasterizes the SVG
  seed-admin.mjs                   # `npm run seed-admin` creates admins/{email} docs

firebase-messaging-sw.template.js  # source of truth for FCM SW
firestore.rules                    # Firestore security rules
firestore.indexes.json             # (empty — no composite indexes yet)
firebase.json                      # Firebase CLI config
vite.config.js                     # + inline plugin to generate FCM SW
TESTING.md                         # end-to-end test plan
```
