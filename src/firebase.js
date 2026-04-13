// ============================================================
// FIREBASE CONFIGURATION — TrikeKoTo
// ============================================================
// Values are injected at build time by Vite from .env.local.
// See .env.example for the full list of required variables and
// vite.config.js for how the FCM service worker gets its copy.
// ============================================================

import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";
import { getMessaging, isSupported as messagingIsSupported } from "firebase/messaging";

const firebaseConfig = {
  apiKey:            import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain:        import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  databaseURL:       import.meta.env.VITE_FIREBASE_DATABASE_URL,
  projectId:         import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket:     import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId:             import.meta.env.VITE_FIREBASE_APP_ID,
  measurementId:     import.meta.env.VITE_FIREBASE_MEASUREMENT_ID,
};

if (!firebaseConfig.apiKey) {
  // Helpful error at app-startup rather than obscure Firebase failures later.
  // Seeing this means .env.local is missing or incomplete — copy .env.example.
  console.error(
    "Firebase config is missing. Copy .env.example to .env.local and fill in the values."
  );
}

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Firestore database instance — used for all real-time read/write operations
export const db = getFirestore(app);

// Firebase Auth instance — used to identify the current driver
export const auth = getAuth(app);

// Firebase Cloud Messaging — only initialised if the browser supports it.
// Safari < 16 and some older Android browsers do not support FCM.
// We export a promise so callers can await it safely.
export const messagingPromise = messagingIsSupported().then((supported) =>
  supported ? getMessaging(app) : null
);

export default app;
