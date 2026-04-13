// ============================================================
// sw.js — TrikeKoTo Service Worker
// ============================================================
// Strategy:
//   - App shell (JS/CSS/HTML) → Cache-first after first load
//   - Tile images (OpenStreetMap) → Cache-first (offline maps)
//   - Firebase API calls → Network-only (never cache auth/db)
//   - Everything else → Network with cache fallback
// ============================================================

const CACHE_NAME = "trikekoto-v1";
const OFFLINE_PAGE = "/index.html";

// Files to pre-cache on install (app shell)
const PRECACHE_URLS = [
  "/",
  "/index.html",
];

// ── Install: pre-cache the app shell ──────────────────────────
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_URLS))
  );
  self.skipWaiting();
});

// ── Activate: delete old caches ───────────────────────────────
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

// ── Fetch: routing strategy ───────────────────────────────────
self.addEventListener("fetch", (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // 1. Never intercept Firebase / Google API calls
  if (
    url.hostname.includes("firestore.googleapis.com") ||
    url.hostname.includes("firebase.googleapis.com") ||
    url.hostname.includes("identitytoolkit.googleapis.com") ||
    url.hostname.includes("securetoken.googleapis.com")
  ) {
    return; // fall through to browser
  }

  // 2. Map tiles — cache-first (enables offline map viewing)
  if (url.hostname.includes("tile.openstreetmap.org")) {
    event.respondWith(
      caches.match(request).then(
        (cached) => cached || fetch(request).then((res) => {
          const clone = res.clone();
          caches.open(CACHE_NAME).then((c) => c.put(request, clone));
          return res;
        })
      )
    );
    return;
  }

  // 3. App shell assets — cache-first
  if (
    url.origin === self.location.origin &&
    (request.destination === "script" ||
     request.destination === "style"  ||
     request.destination === "image"  ||
     url.pathname === "/" ||
     url.pathname === "/index.html")
  ) {
    event.respondWith(
      caches.match(request).then(
        (cached) => cached || fetch(request).then((res) => {
          const clone = res.clone();
          caches.open(CACHE_NAME).then((c) => c.put(request, clone));
          return res;
        }).catch(() => caches.match(OFFLINE_PAGE))
      )
    );
    return;
  }

  // 4. Everything else — network with cache fallback
  event.respondWith(
    fetch(request).catch(async () => {
      const cached = await caches.match(request);
      return cached || caches.match(OFFLINE_PAGE);
    })
  );
});
