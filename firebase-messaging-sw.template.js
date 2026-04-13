// ============================================================
// firebase-messaging-sw.template.js — TrikeKoTo FCM Service Worker
// ============================================================
// THIS FILE IS A TEMPLATE. Do not edit the generated
// `public/firebase-messaging-sw.js` directly — edit this file,
// then restart `npm run dev` or re-run `npm run build`.
//
// Placeholders are substituted from `.env.local` by vite.config.js
// at config-load time.
// ============================================================

// Must match the Firebase JS SDK major version declared in package.json.
importScripts("https://www.gstatic.com/firebasejs/12.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/12.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey:            "__VITE_FIREBASE_API_KEY__",
  authDomain:        "__VITE_FIREBASE_AUTH_DOMAIN__",
  projectId:         "__VITE_FIREBASE_PROJECT_ID__",
  storageBucket:     "__VITE_FIREBASE_STORAGE_BUCKET__",
  messagingSenderId: "__VITE_FIREBASE_MESSAGING_SENDER_ID__",
  appId:             "__VITE_FIREBASE_APP_ID__",
});

const messaging = firebase.messaging();

// Handle background push messages
messaging.onBackgroundMessage((payload) => {
  const { title, body, icon } = payload.notification ?? {};
  self.registration.showNotification(title ?? "TrikeKoTo", {
    body:  body  ?? "You have a new ride request.",
    icon:  icon  ?? "/icons/icon-192.png",
    badge: "/icons/favicon-32.png",
    tag:   "trikekoto-ride",        // replaces previous notification instead of stacking
    renotify: true,
    data:  payload.data ?? {},
  });
});

// Clicking the notification focuses the app tab (or opens a new one)
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && "focus" in client) {
          return client.focus();
        }
      }
      return clients.openWindow("/");
    })
  );
});
