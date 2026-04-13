// ============================================================
// usePushNotifications.js — TrikeKoTo
// ============================================================
// Handles the full FCM registration flow for a driver:
//
//   1. Requests Notification permission from the browser
//   2. Gets the FCM registration token
//   3. Stores the token in active_drivers/{email}.fcmToken
//      so a Cloud Function can target this specific driver
//   4. Listens for foreground messages and shows a browser
//      Notification manually (FCM only auto-shows when app
//      is in the background)
//
// The VAPID (Web Push) key comes from .env.local. Get it from:
//   Firebase Console → Project Settings → Cloud Messaging
//   → Web Push certificates → Generate key pair
// ============================================================

import { useEffect, useState } from "react";
import { getToken, onMessage } from "firebase/messaging";
import { doc, setDoc, serverTimestamp } from "firebase/firestore";
import { messagingPromise, db } from "../firebase";

const VAPID_KEY = import.meta.env.VITE_FIREBASE_VAPID_KEY;

export default function usePushNotifications(driverEmail) {
  const [notifPermission, setNotifPermission] = useState(
    typeof Notification !== "undefined" ? Notification.permission : "default"
  );
  const [fcmReady, setFcmReady] = useState(false);

  useEffect(() => {
    if (!driverEmail || driverEmail === "unknown") return;
    if (typeof Notification === "undefined") return;       // browser doesn't support it
    if (Notification.permission === "denied") return;      // user already blocked it
    if (!VAPID_KEY) return;                                // not configured yet

    let unsubForeground = null;

    const setup = async () => {
      try {
        const messaging = await messagingPromise;
        if (!messaging) return; // browser doesn't support FCM

        // Request permission if not yet granted
        const permission = await Notification.requestPermission();
        setNotifPermission(permission);
        if (permission !== "granted") return;

        // Get the FCM token (requires the service worker to be registered)
        const token = await getToken(messaging, {
          vapidKey: VAPID_KEY,
          serviceWorkerRegistration: await navigator.serviceWorker.ready,
        });

        if (token) {
          // Store token so Cloud Functions can send targeted notifications
          await setDoc(
            doc(db, "active_drivers", driverEmail),
            { fcmToken: token, fcmTokenUpdatedAt: serverTimestamp() },
            { merge: true }
          );
          setFcmReady(true);
        }

        // Handle foreground messages (app is open and focused)
        unsubForeground = onMessage(messaging, (payload) => {
          const title = payload.notification?.title ?? "TrikeKoTo";
          const body  = payload.notification?.body  ?? "New ride request nearby!";

          // Show a manual notification since FCM suppresses auto-display
          // when the app tab is active
          if (Notification.permission === "granted") {
            new Notification(title, {
              body,
              icon: "/icons/icon-192.png",
              tag: "trikekoto-ride",
              renotify: true,
            });
          }
        });
      } catch (err) {
        // Non-fatal — app still works without push notifications
        console.warn("Push notification setup failed:", err.message);
      }
    };

    setup();

    return () => {
      if (unsubForeground) unsubForeground();
    };
  }, [driverEmail]);

  return { notifPermission, fcmReady };
}
