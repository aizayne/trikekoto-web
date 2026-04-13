// ============================================================
// DriverDashboard.jsx — TrikeKoTo
// ============================================================
// Driver session lifecycle:
//   1. Soft-ask for location permission
//   2. Online / Offline toggle  →  live GPS → Firestore active_drivers
//   3. While online: real-time listener on rides (status=="searching")
//      - Accept  → updates ride doc, locks in active ride
//      - Ignore  → hides card locally for this session
//   4. Active ride card with "Complete Ride" action
// ============================================================

import { useState, useEffect, useRef, useCallback, useMemo } from "react";
import usePushNotifications from "../hooks/usePushNotifications";
import { useNotify } from "../contexts/notify.js";
import {
  doc, setDoc, updateDoc, runTransaction, onSnapshot,
  query, collection, where, serverTimestamp,
} from "firebase/firestore";
import { signOut } from "firebase/auth";
import { db, auth } from "../firebase";
import { normalizeEmail } from "../utils/email";
import NoSleep from "nosleep.js";
import {
  MapPin, WifiOff, Wifi, AlertTriangle,
  Navigation, CheckCircle, LogOut,
  User, Flag, Loader,
} from "lucide-react";

// ─── Geolocation config ──────────────────────────────────────
const GEO_OPTS = {
  enableHighAccuracy: true,
  maximumAge: 5000,
  timeout: 15000,
};

// ─── Proximity filter ────────────────────────────────────────
// Only show ride requests within this radius of the driver.
const PROXIMITY_KM = 5;

// Hide ride requests older than this (client-side sliding window).
const RIDE_MAX_AGE_MS = 10 * 60 * 1000;

// ─── Greedy nearest-driver matching ──────────────────────────
// Each ride is offered to the closest driver first. Every
// OFFER_EXPAND_MS milliseconds, the offer widens to include the
// next-closest driver, until either someone accepts or the ride
// ages out. Ranking is deterministic (distance, then email
// tiebreaker) so every client arrives at the same ordering
// without a central coordinator.
const OFFER_EXPAND_MS = 15_000;  // 15s per rank expansion
const MAX_OFFER_RANK  = 10;      // cap so a stale ride doesn't broadcast forever

// Haversine formula — returns distance in kilometres between
// two lat/lng coordinates.
function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
    Math.cos((lat2 * Math.PI) / 180) *
    Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Deterministic driver ranking for a given ride. Returns driver
// emails sorted by haversine distance from the ride's pickup,
// with email as the tiebreaker so every client produces the
// same ordering independently. Drivers outside PROXIMITY_KM are
// excluded from the ranking entirely.
function rankDriversForRide(ride, onlineDrivers) {
  if (!ride?.pickupCoords?.lat || !ride?.pickupCoords?.lng) return [];
  return onlineDrivers
    .filter((d) =>
      d.email &&
      d.location?.lat != null &&
      d.location?.lng != null
    )
    .map((d) => ({
      email: d.email,
      distanceKm: haversineKm(
        d.location.lat, d.location.lng,
        ride.pickupCoords.lat, ride.pickupCoords.lng
      ),
    }))
    .filter((d) => d.distanceKm <= PROXIMITY_KM)
    .sort((a, b) =>
      a.distanceKm - b.distanceKm ||
      a.email.localeCompare(b.email)
    )
    .map((d) => d.email);
}

// How many drivers the ride has been offered to so far, based
// on its age: 0–15s = 1 driver, 15–30s = 2, etc., capped at
// MAX_OFFER_RANK.
function currentOfferDepth(ride, nowMs) {
  const createdMs = ride.createdAt?.toMillis?.() ?? nowMs;
  const ageMs = Math.max(0, nowMs - createdMs);
  return Math.min(MAX_OFFER_RANK, Math.floor(ageMs / OFFER_EXPAND_MS) + 1);
}

// ─── Styles ──────────────────────────────────────────────────
const S = {
  page: {
    minHeight: "100vh",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    padding: "1.5rem",
    backgroundColor: "#0f172a",
    color: "#f8fafc",
    fontFamily: "'Segoe UI', system-ui, sans-serif",
    gap: "1rem",
    boxSizing: "border-box",
  },
  card: {
    width: "100%",
    maxWidth: "440px",
    backgroundColor: "#1e293b",
    borderRadius: "1.25rem",
    padding: "1.5rem",
    boxShadow: "0 8px 32px rgba(0,0,0,0.4)",
    display: "flex",
    flexDirection: "column",
    gap: "1rem",
  },
  rideCard: (active) => ({
    width: "100%",
    maxWidth: "440px",
    backgroundColor: active ? "#1a2e1a" : "#1e293b",
    border: `1px solid ${active ? "#166534" : "#334155"}`,
    borderRadius: "1.25rem",
    padding: "1.25rem",
    display: "flex",
    flexDirection: "column",
    gap: "0.75rem",
  }),
  header: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
  },
  appTitle: { fontSize: "1.4rem", fontWeight: 700, color: "#f59e0b", margin: 0 },
  appSubtitle: { fontSize: "0.8rem", color: "#94a3b8", margin: 0 },
  badge: (online) => ({
    display: "inline-flex",
    alignItems: "center",
    gap: "0.35rem",
    padding: "0.3rem 0.75rem",
    borderRadius: "9999px",
    fontSize: "0.78rem",
    fontWeight: 600,
    backgroundColor: online ? "#14532d" : "#1e3a5f",
    color: online ? "#4ade80" : "#60a5fa",
  }),
  locationBox: {
    backgroundColor: "#0f172a",
    borderRadius: "0.75rem",
    padding: "0.9rem",
    fontSize: "0.78rem",
    color: "#94a3b8",
    lineHeight: 1.75,
  },
  btn: (v) => ({
    width: "100%",
    padding: "0.85rem",
    borderRadius: "0.875rem",
    border: "none",
    cursor: v === "disabled" ? "not-allowed" : "pointer",
    fontSize: "0.95rem",
    fontWeight: 700,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    gap: "0.5rem",
    transition: "opacity 0.2s",
    ...(v === "allow"      && { backgroundColor: "#2563eb", color: "#fff" }),
    ...(v === "online"     && { backgroundColor: "#16a34a", color: "#fff" }),
    ...(v === "offline"    && { backgroundColor: "#dc2626", color: "#fff" }),
    ...(v === "accept"     && { backgroundColor: "#f59e0b", color: "#0f172a" }),
    ...(v === "complete"   && { backgroundColor: "#0ea5e9", color: "#fff" }),
    ...(v === "ignore"     && { backgroundColor: "transparent", color: "#64748b", border: "1px solid #334155" }),
    ...(v === "disabled"   && { backgroundColor: "#334155", color: "#64748b" }),
  }),
  error: {
    display: "flex", alignItems: "flex-start", gap: "0.6rem",
    backgroundColor: "#450a0a", border: "1px solid #7f1d1d",
    borderRadius: "0.75rem", padding: "0.85rem",
    fontSize: "0.8rem", color: "#fca5a5", lineHeight: 1.6,
  },
  info: {
    display: "flex", alignItems: "flex-start", gap: "0.6rem",
    backgroundColor: "#172554", border: "1px solid #1e3a8a",
    borderRadius: "0.75rem", padding: "0.85rem",
    fontSize: "0.8rem", color: "#bfdbfe", lineHeight: 1.6,
  },
  divider: { borderColor: "#334155", margin: 0 },
  label: { fontSize: "0.72rem", color: "#64748b", marginBottom: "0.1rem" },
  value: { fontSize: "0.9rem", color: "#e2e8f0", fontWeight: 600 },
  row: { display: "flex", gap: "1rem" },
  col: { flex: 1 },
};

// ─── Component ───────────────────────────────────────────────
export default function DriverDashboard({ onSignOut, onHistory, onProfile }) {
  // Normalize once so every Firestore doc ID derived from
  // this driver's email is consistent with what the rules and
  // other clients expect.
  const driverEmail = normalizeEmail(auth.currentUser?.email) || "unknown";
  const { toast, confirm } = useNotify();

  // Register for push notifications. Non-blocking — if the VAPID key
  // hasn't been set yet, the hook silently skips.
  const { notifPermission, fcmReady } = usePushNotifications(driverEmail);

  // Location / online state
  const [permission, setPermission]       = useState("unknown"); // unknown|asking|granted|denied
  const [isOnline, setIsOnline]           = useState(false);
  const [coords, setCoords]               = useState(null);
  const [locationError, setLocationError] = useState(null);
  const [syncStatus, setSyncStatus]       = useState("idle");   // idle|syncing|synced|error

  // Ride state
  const [rawRides, setRawRides]           = useState([]);       // unfiltered searching rides
  const [onlineDrivers, setOnlineDrivers] = useState([]);       // peer drivers for greedy ranking
  const [activeRide, setActiveRide]       = useState(null);     // ride the driver accepted
  const [rideLoading, setRideLoading]     = useState(null);     // rideId being accepted
  const [filterTick, setFilterTick]       = useState(0);        // forces re-filter every 5s

  const watchIdRef      = useRef(null);
  const noSleepRef      = useRef(null);
  const ignoredIdsRef   = useRef(new Set());      // ride IDs ignored this session
  const coordsRef       = useRef(null);           // mirror of coords for use inside callbacks
  const activeRideUnsub = useRef(null);           // listener for the driver's active ride doc

  // Lazy-init NoSleep once (avoids re-construction on every render)
  if (noSleepRef.current === null) {
    noSleepRef.current = new NoSleep();
  }

  // keep coordsRef in sync
  useEffect(() => { coordsRef.current = coords; }, [coords]);

  // ── Check existing browser permission on mount ─────────────
  useEffect(() => {
    if (!navigator.permissions) return;
    navigator.permissions.query({ name: "geolocation" }).then((res) => {
      if (res.state !== "prompt") setPermission(res.state);
      res.onchange = () => setPermission(res.state);
    }).catch(() => {});
  }, []);

  // ── Clean up on unmount ────────────────────────────────────
  useEffect(() => {
    return () => {
      if (watchIdRef.current !== null)
        navigator.geolocation.clearWatch(watchIdRef.current);
      noSleepRef.current?.disable();
      if (activeRideUnsub.current) activeRideUnsub.current();
    };
  }, []);

  // ── Ride request listener (active only while online) ───────
  // Pulls the raw list of "searching" rides. Filtering by distance
  // and age happens client-side in a useMemo below so the display
  // stays in sync with GPS movement without re-subscribing.
  useEffect(() => {
    if (!isOnline || activeRide) {
      setRawRides([]);
      return;
    }

    const q = query(
      collection(db, "rides"),
      where("status", "==", "searching")
    );

    const unsub = onSnapshot(q, (snap) => {
      const list = [];
      snap.forEach((d) => list.push({ id: d.id, ...d.data() }));
      setRawRides(list);
    }, (err) => {
      console.error("Ride listener error:", err);
    });

    return unsub;
  }, [isOnline, activeRide]);

  // ── Peer driver listener (active only while online) ────────
  // The greedy matching algorithm needs to know about every
  // other online driver so this client can compute whether it
  // is currently among the top-K closest candidates for each
  // ride. Ranking is deterministic, so every driver's browser
  // independently reaches the same conclusion.
  useEffect(() => {
    if (!isOnline || activeRide) {
      setOnlineDrivers([]);
      return;
    }

    const q = query(
      collection(db, "active_drivers"),
      where("isOnline", "==", true)
    );

    const unsub = onSnapshot(q, (snap) => {
      const list = [];
      snap.forEach((d) => list.push({ id: d.id, ...d.data() }));
      setOnlineDrivers(list);
    }, (err) => {
      console.error("Online drivers listener error:", err);
    });

    return unsub;
  }, [isOnline, activeRide]);

  // ── Tick every 5s so the greedy offer window expands on
  //    schedule even when no new Firestore snapshots arrive.
  //    Each tick re-evaluates currentOfferDepth for every ride.
  useEffect(() => {
    if (!isOnline || activeRide) return;
    const id = setInterval(() => setFilterTick((t) => t + 1), 5_000);
    return () => clearInterval(id);
  }, [isOnline, activeRide]);

  // ── Derived: rides actually shown to the driver ────────────
  // Greedy nearest-driver matching:
  //   1. Discard ignored and aged-out rides.
  //   2. For each ride, rank ALL online drivers by distance to
  //      the ride's pickup (deterministic: distance, then email).
  //   3. Compute currentOfferDepth(ride) from its age — the ride
  //      is currently offered to the top-K drivers in the ranking.
  //   4. Only show the ride to this driver if this driver's rank
  //      is strictly less than K (i.e., they're currently in the
  //      offered slice).
  // Because ranking is deterministic, every driver's client
  // arrives at the same ordering independently — no central
  // coordinator needed.
  const incomingRides = useMemo(() => {
    // Read filterTick so this memo recomputes on the tick schedule.
    void filterTick;

    const nowMs = Date.now();

    // Synthesize an updated entry for this driver using the
    // live `coords` from GPS — the Firestore record from
    // active_drivers may be a few seconds stale.
    const peersWithSelf = (() => {
      if (!coords) return onlineDrivers;
      const others = onlineDrivers.filter((d) => d.email !== driverEmail);
      return [
        ...others,
        {
          email: driverEmail,
          location: { lat: coords.lat, lng: coords.lng },
          isOnline: true,
        },
      ];
    })();

    return rawRides
      .filter((r) => !ignoredIdsRef.current.has(r.id))
      .filter((r) => {
        const createdMs = r.createdAt?.toMillis?.() ?? 0;
        return nowMs - createdMs <= RIDE_MAX_AGE_MS;
      })
      .map((r) => {
        let distanceKm = null;
        if (coords && r.pickupCoords?.lat && r.pickupCoords?.lng) {
          distanceKm = haversineKm(
            coords.lat, coords.lng,
            r.pickupCoords.lat, r.pickupCoords.lng
          );
        }

        // Greedy offer computation
        const ranking = rankDriversForRide(r, peersWithSelf);
        const myRank  = ranking.indexOf(driverEmail); // -1 if out of range
        const depth   = currentOfferDepth(r, nowMs);
        const offered = myRank >= 0 && myRank < depth;
        const isSolo  = ranking.length <= 1;

        return {
          ...r,
          distanceKm,
          myRank,              // 0-based; -1 means out of proximity or no pickup coords
          offerDepth: depth,   // how many drivers have been notified so far
          totalRanked: ranking.length,
          offered,
          isSolo,
        };
      })
      // Enforce proximity fallback: if we couldn't compute distance
      // at all (missing coords on either side) fall back to the old
      // behavior and just show the ride.
      .filter((r) => {
        if (r.distanceKm === null) return true;            // degrade gracefully
        if (r.distanceKm > PROXIMITY_KM) return false;     // outside radius
        return r.offered;                                  // greedy slice
      })
      .sort((a, b) => {
        // Rides where this driver is the top offer come first
        if (a.myRank !== b.myRank) {
          // Lower rank = higher priority; -1 sorts last
          const ra = a.myRank < 0 ? Infinity : a.myRank;
          const rb = b.myRank < 0 ? Infinity : b.myRank;
          return ra - rb;
        }
        if (a.distanceKm !== null && b.distanceKm !== null)
          return a.distanceKm - b.distanceKm;
        const ta = a.createdAt?.toMillis?.() ?? 0;
        const tb = b.createdAt?.toMillis?.() ?? 0;
        return tb - ta;
      });
  }, [rawRides, coords, onlineDrivers, driverEmail, filterTick]);

  // ── Firestore: write live location ─────────────────────────
  // NOTE: use { lat, lng } to match the shape stored on the ride
  // document's driverLocation field (see handleAcceptRide below).
  const syncLocation = useCallback(async (lat, lng, accuracy, online) => {
    setSyncStatus("syncing");
    try {
      await setDoc(
        doc(db, "active_drivers", driverEmail),
        {
          email: driverEmail,
          isOnline: online,
          location: { lat, lng, accuracy },
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );
      setSyncStatus("synced");
    } catch (err) {
      console.error("Location sync error:", err);
      setSyncStatus("error");
    }
  }, [driverEmail]);

  // ── Firestore: mark offline ─────────────────────────────────
  const markOffline = useCallback(async () => {
    try {
      await setDoc(
        doc(db, "active_drivers", driverEmail),
        { isOnline: false, updatedAt: serverTimestamp() },
        { merge: true }
      );
    } catch (err) {
      console.error("Mark offline error:", err);
    }
  }, [driverEmail]);

  // ── Soft-ask for location ───────────────────────────────────
  const handleAllowLocation = useCallback(() => {
    setPermission("asking");
    setLocationError(null);
    navigator.geolocation.getCurrentPosition(
      () => setPermission("granted"),
      (err) => {
        setPermission("denied");
        setLocationError(
          err.code === 1
            ? "Location access was denied. Please allow it in your browser settings and refresh."
            : "Could not get your location. Check your device GPS."
        );
      },
      GEO_OPTS
    );
  }, []);

  // ── Go Online ───────────────────────────────────────────────
  const handleGoOnline = useCallback(() => {
    if (!("geolocation" in navigator)) {
      setLocationError("Geolocation is not supported by this browser.");
      return;
    }
    setLocationError(null);
    noSleepRef.current?.enable();
    setIsOnline(true);

    watchIdRef.current = navigator.geolocation.watchPosition(
      ({ coords: c }) => {
        setCoords({ lat: c.latitude, lng: c.longitude, accuracy: c.accuracy });
        syncLocation(c.latitude, c.longitude, c.accuracy, true);
      },
      (err) => {
        setLocationError(
          err.code === 1
            ? "Location permission was revoked."
            : `GPS error (${err.code}): ${err.message}`
        );
      },
      GEO_OPTS
    );
  }, [syncLocation]);

  // ── Go Offline ──────────────────────────────────────────────
  // Returns a promise so callers can await the Firestore write
  // completing before doing anything else (e.g. signing out).
  const handleGoOffline = useCallback(async (activeRideToCancel = null) => {
    if (watchIdRef.current !== null) {
      navigator.geolocation.clearWatch(watchIdRef.current);
      watchIdRef.current = null;
    }
    noSleepRef.current?.disable();
    setIsOnline(false);
    setCoords(null);
    setSyncStatus("idle");
    setRawRides([]);

    // If the driver has an active ride when going offline, cancel it
    // so the commuter is not left waiting indefinitely.
    if (activeRideToCancel?.id) {
      try {
        await updateDoc(doc(db, "rides", activeRideToCancel.id), {
          status: "cancelled",
          cancelledAt: serverTimestamp(),
          cancelledBy: "driver_went_offline",
        });
      } catch (err) {
        console.error("Failed to cancel ride on going offline:", err);
      }
      setActiveRide(null);
    }

    await markOffline();
  }, [markOffline]);

  // ── Watch the active ride for commuter cancellation ────────
  // If the commuter cancels after the driver has accepted, clear
  // the active ride state so the driver returns to "waiting" mode.
  useEffect(() => {
    if (!activeRide?.id) {
      // No active ride — stop any existing listener
      if (activeRideUnsub.current) { activeRideUnsub.current(); activeRideUnsub.current = null; }
      return;
    }

    if (activeRideUnsub.current) activeRideUnsub.current();

    activeRideUnsub.current = onSnapshot(
      doc(db, "rides", activeRide.id),
      (snap) => {
        if (!snap.exists()) return;
        const { status } = snap.data();
        if (status === "cancelled") {
          setActiveRide(null);
          toast("The commuter cancelled the ride.", { variant: "info" });
        }
        if (status === "completed") {
          // Completed externally (e.g., admin action) — clear local state
          setActiveRide(null);
        }
      },
      (err) => console.error("Active ride watcher error:", err)
    );

    return () => {
      if (activeRideUnsub.current) { activeRideUnsub.current(); activeRideUnsub.current = null; }
    };
  }, [activeRide?.id, toast]);

  // ── Accept a ride (atomic transaction) ─────────────────────
  // runTransaction gives us a read-then-write lock on the ride doc.
  // If two drivers tap Accept at the same time, Firestore serializes
  // them: whichever runs second will read status="accepted" and abort.
  const handleAcceptRide = useCallback(async (ride) => {
    setRideLoading(ride.id);
    try {
      const rideRef = doc(db, "rides", ride.id);
      const loc = coordsRef.current;

      await runTransaction(db, async (transaction) => {
        const snap = await transaction.get(rideRef);

        if (!snap.exists()) {
          throw new Error("GONE"); // ride was deleted
        }
        if (snap.data().status !== "searching") {
          throw new Error("ALREADY_TAKEN"); // another driver got there first
        }

        transaction.update(rideRef, {
          status: "accepted",
          assignedDriver: driverEmail,
          driverLocation: loc ? { lat: loc.lat, lng: loc.lng } : null,
          acceptedAt: serverTimestamp(),
        });
      });

      // Transaction succeeded — this driver owns the ride
      setActiveRide(ride);
      setRawRides([]);
    } catch (err) {
      if (err.message === "ALREADY_TAKEN" || err.message === "GONE") {
        // Quietly hide the card — another driver accepted faster
        ignoredIdsRef.current.add(ride.id);
        setRawRides((prev) => prev.filter((r) => r.id !== ride.id));
      } else {
        console.error("Accept ride error:", err);
        toast("Could not accept ride. Please check your connection and try again.", { variant: "error" });
      }
    } finally {
      setRideLoading(null);
    }
  }, [driverEmail, toast]);

  // ── Ignore a ride ───────────────────────────────────────────
  const handleIgnoreRide = useCallback((rideId) => {
    ignoredIdsRef.current.add(rideId);
    setRawRides((prev) => prev.filter((r) => r.id !== rideId));
  }, []);

  // ── Complete ride ───────────────────────────────────────────
  const handleCompleteRide = useCallback(async () => {
    if (!activeRide) return;
    try {
      await updateDoc(doc(db, "rides", activeRide.id), {
        status: "completed",
        completedAt: serverTimestamp(),
      });
      setActiveRide(null);
      toast("Ride completed. Nice work.", { variant: "success" });
    } catch (err) {
      console.error("Complete ride error:", err);
      toast("Could not mark ride as complete. Please try again.", { variant: "error" });
    }
  }, [activeRide, toast]);

  // ── Cancel active ride (driver side) ───────────────────────
  const handleCancelActiveRide = useCallback(async () => {
    if (!activeRide) return;
    const ok = await confirm("Are you sure you want to cancel this ride?", {
      title: "Cancel ride",
      okLabel: "Yes, cancel",
      cancelLabel: "Keep ride",
    });
    if (!ok) return;
    try {
      await updateDoc(doc(db, "rides", activeRide.id), {
        status: "cancelled",
        cancelledAt: serverTimestamp(),
        cancelledBy: "driver",
      });
      setActiveRide(null);
      toast("Ride cancelled.", { variant: "info" });
    } catch (err) {
      console.error("Cancel ride error:", err);
      toast("Could not cancel the ride. Please try again.", { variant: "error" });
    }
  }, [activeRide, confirm, toast]);

  // ── Sign out ────────────────────────────────────────────────
  const handleSignOut = useCallback(async () => {
    // Await offline transition (writes to Firestore + cancels active ride)
    // before signing out so the writes aren't dropped mid-flight.
    if (isOnline) await handleGoOffline(activeRide);
    await signOut(auth);
    if (onSignOut) onSignOut();
  }, [isOnline, activeRide, handleGoOffline, onSignOut]);

  // ─── Render: GPS location box ────────────────────────────────
  const renderLocation = () => {
    if (!isOnline) return null;
    if (!coords) {
      return (
        <div style={S.locationBox}>
          <span style={{ color: "#64748b" }}>⟳ Acquiring GPS signal…</span>
        </div>
      );
    }
    return (
      <div style={S.locationBox}>
        <div>Lat: <strong style={{ color: "#e2e8f0" }}>{coords.lat.toFixed(6)}</strong></div>
        <div>Lng: <strong style={{ color: "#e2e8f0" }}>{coords.lng.toFixed(6)}</strong></div>
        <div>Accuracy: <strong style={{ color: "#e2e8f0" }}>±{Math.round(coords.accuracy)} m</strong></div>
        <div style={{ marginTop: "0.3rem", fontSize: "0.72rem", color: "#475569" }}>
          {syncStatus === "synced"  && "✓ Location synced"}
          {syncStatus === "syncing" && "⟳ Syncing…"}
          {syncStatus === "error"   && "✗ Sync failed — check connection"}
        </div>
      </div>
    );
  };

  // ─── Render: active ride card ────────────────────────────────
  const renderActiveRide = () => {
    if (!activeRide) return null;
    return (
      <div style={S.rideCard(true)}>
        <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
          <Flag size={16} color="#4ade80" />
          <span style={{ fontWeight: 700, color: "#4ade80", fontSize: "0.9rem" }}>
            Active Ride
          </span>
        </div>
        <hr style={S.divider} />
        <div style={S.row}>
          <div style={S.col}>
            <p style={S.label}>Pickup</p>
            <p style={S.value}>{activeRide.pickup ?? "—"}</p>
          </div>
          <div style={S.col}>
            <p style={S.label}>Dropoff</p>
            <p style={S.value}>{activeRide.dropoff ?? "—"}</p>
          </div>
        </div>
        {(activeRide.commuter || activeRide.commuterPhone) && (
          <div style={S.row}>
            {activeRide.commuter && (
              <div style={S.col}>
                <p style={S.label}>Commuter</p>
                <p style={S.value}>{activeRide.commuter}</p>
              </div>
            )}
            {activeRide.commuterPhone && (
              <div style={S.col}>
                <p style={S.label}>Phone</p>
                <p style={S.value}>{activeRide.commuterPhone}</p>
              </div>
            )}
          </div>
        )}
        <div style={{ display: "flex", gap: "0.6rem" }}>
          <button style={{ ...S.btn("complete"), flex: 1 }} onClick={handleCompleteRide}>
            <CheckCircle size={17} /> Complete Ride
          </button>
          <button
            style={{ ...S.btn("ignore"), flex: "0 0 auto", padding: "0.85rem 1rem" }}
            onClick={handleCancelActiveRide}
            title="Cancel this ride"
          >
            Cancel
          </button>
        </div>
      </div>
    );
  };

  // ─── Render: incoming ride cards ────────────────────────────
  const renderIncomingRides = () => {
    if (!isOnline || activeRide || incomingRides.length === 0) return null;
    return incomingRides.map((ride) => {
      // Priority badge — driver's current rank in the greedy offer
      // slice. Rank 0 means "you are the closest driver right now".
      const priorityLabel = (() => {
        if (ride.myRank < 0) return null;
        if (ride.isSolo)     return "Only driver";
        if (ride.myRank === 0) return "Closest · 1st offer";
        const ordinals = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th"];
        return `${ordinals[ride.myRank] ?? `#${ride.myRank + 1}`} closest`;
      })();
      const priorityColor = ride.myRank === 0 || ride.isSolo ? "#4ade80" : "#fbbf24";

      return (
      <div key={ride.id} style={S.rideCard(false)}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "0.4rem" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <User size={15} color="#f59e0b" />
            <span style={{ fontWeight: 700, color: "#f59e0b", fontSize: "0.85rem" }}>
              New Ride Request
            </span>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: "0.35rem" }}>
            {priorityLabel && (
              <span style={{
                fontSize: "0.7rem", fontWeight: 700, color: priorityColor,
                backgroundColor: "#0f172a",
                border: `1px solid ${priorityColor}`,
                borderRadius: "9999px",
                padding: "0.2rem 0.55rem",
              }}>
                ★ {priorityLabel}
              </span>
            )}
            {ride.distanceKm !== null && (
              <span style={{
                fontSize: "0.72rem", fontWeight: 600, color: "#94a3b8",
                backgroundColor: "#0f172a", borderRadius: "9999px",
                padding: "0.2rem 0.6rem",
              }}>
                📍 {ride.distanceKm < 1
                  ? `${Math.round(ride.distanceKm * 1000)} m`
                  : `${ride.distanceKm.toFixed(1)} km`} away
              </span>
            )}
          </div>
        </div>
        <hr style={S.divider} />
        <div style={S.row}>
          <div style={S.col}>
            <p style={S.label}>Pickup</p>
            <p style={S.value}>{ride.pickup ?? "—"}</p>
          </div>
          <div style={S.col}>
            <p style={S.label}>Dropoff</p>
            <p style={S.value}>{ride.dropoff ?? "—"}</p>
          </div>
        </div>
        {ride.notes && (
          <div>
            <p style={S.label}>Notes</p>
            <p style={{ ...S.value, fontWeight: 400, fontSize: "0.82rem", color: "#94a3b8" }}>
              {ride.notes}
            </p>
          </div>
        )}
        <div style={{ display: "flex", gap: "0.6rem" }}>
          <button
            style={{ ...S.btn("accept"), flex: 1 }}
            onClick={() => handleAcceptRide(ride)}
            disabled={rideLoading === ride.id}
          >
            {rideLoading === ride.id
              ? <Loader size={16} />
              : <CheckCircle size={16} />}
            {rideLoading === ride.id ? "Accepting…" : "Accept"}
          </button>
          <button
            style={{ ...S.btn("ignore"), flex: 1 }}
            onClick={() => handleIgnoreRide(ride.id)}
            disabled={!!rideLoading}
          >
            Ignore
          </button>
        </div>
      </div>
      );
    });
  };

  // ─── Render: main action button ─────────────────────────────
  const renderAction = () => {
    if (!("geolocation" in navigator)) {
      return (
        <button style={S.btn("disabled")} disabled>
          <AlertTriangle size={17} /> GPS Not Supported
        </button>
      );
    }
    if (permission === "denied") {
      return (
        <div style={S.error}>
          <AlertTriangle size={15} style={{ flexShrink: 0, marginTop: 2 }} />
          <span>Location blocked. Allow it in your browser site settings, then refresh.</span>
        </div>
      );
    }
    if (permission === "unknown" || permission === "asking") {
      return (
        <>
          <div style={S.info}>
            <Navigation size={15} style={{ flexShrink: 0, marginTop: 2 }} />
            <span>
              TrikeKoTo needs your location to show you to nearby commuters.
              Your position is only shared while you are online.
            </span>
          </div>
          <button
            style={S.btn("allow")}
            onClick={handleAllowLocation}
            disabled={permission === "asking"}
          >
            <MapPin size={17} />
            {permission === "asking" ? "Requesting…" : "Allow Location Access"}
          </button>
        </>
      );
    }
    if (isOnline) {
      return (
        <button style={S.btn("offline")} onClick={() => handleGoOffline(activeRide)}>
          <WifiOff size={17} /> Go Offline
        </button>
      );
    }
    return (
      <button style={S.btn("online")} onClick={handleGoOnline}>
        <Wifi size={17} /> Go Online
      </button>
    );
  };

  // ─── Main render ─────────────────────────────────────────────
  return (
    <div style={S.page}>

      {/* Main info card */}
      <div style={{ ...S.card, marginTop: "1.5rem" }}>

        {/* Header */}
        <div style={S.header}>
          <div>
            <p style={S.appTitle}>TrikeKoTo</p>
            <p style={S.appSubtitle}>Driver Dashboard</p>
          </div>
          <span style={S.badge(isOnline)}>
            {isOnline
              ? <><CheckCircle size={11} /> Online</>
              : <><WifiOff size={11} /> Offline</>}
          </span>
        </div>

        <hr style={S.divider} />

        {/* Driver identity + sign out */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div>
            <div style={{ fontSize: "0.78rem", color: "#64748b" }}>{driverEmail}</div>
            {/* Notification status — only shown when relevant */}
            {notifPermission === "denied" && (
              <div style={{ fontSize: "0.68rem", color: "#f59e0b", marginTop: "0.15rem" }}>
                🔕 Notifications blocked — you may miss rides
              </div>
            )}
            {fcmReady && (
              <div style={{ fontSize: "0.68rem", color: "#4ade80", marginTop: "0.15rem" }}>
                🔔 Push notifications active
              </div>
            )}
          </div>
          <button
            onClick={handleSignOut}
            style={{
              background: "none", border: "1px solid #334155",
              borderRadius: "0.5rem", color: "#94a3b8", cursor: "pointer",
              padding: "0.3rem 0.6rem", display: "flex",
              alignItems: "center", gap: "0.3rem", fontSize: "0.75rem",
            }}
          >
            <LogOut size={12} /> Sign Out
          </button>
        </div>

        {/* Quick nav */}
        <div style={{ display: "flex", gap: "0.5rem" }}>
          {onProfile && (
            <button
              onClick={onProfile}
              style={{
                flex: 1, background: "none", border: "1px solid #334155",
                borderRadius: "0.625rem", color: "#94a3b8", cursor: "pointer",
                padding: "0.5rem", display: "flex", alignItems: "center",
                justifyContent: "center", gap: "0.35rem", fontSize: "0.78rem",
              }}
            >
              <User size={13} /> My Profile
            </button>
          )}
          {onHistory && (
            <button
              onClick={onHistory}
              style={{
                flex: 1, background: "none", border: "1px solid #334155",
                borderRadius: "0.625rem", color: "#94a3b8", cursor: "pointer",
                padding: "0.5rem", display: "flex", alignItems: "center",
                justifyContent: "center", gap: "0.35rem", fontSize: "0.78rem",
              }}
            >
              <Flag size={13} /> Ride History
            </button>
          )}
        </div>

        {/* Live GPS */}
        {renderLocation()}

        {/* GPS / location errors */}
        {locationError && (
          <div style={S.error}>
            <AlertTriangle size={15} style={{ flexShrink: 0, marginTop: 2 }} />
            <span>{locationError}</span>
          </div>
        )}

        {/* Online / Offline button + soft-ask */}
        {renderAction()}

        {/* Idle hint when online and no rides yet */}
        {isOnline && !activeRide && incomingRides.length === 0 && (
          <div style={{ textAlign: "center", fontSize: "0.8rem", color: "#475569" }}>
            Waiting for ride requests…
          </div>
        )}
      </div>

      {/* Active ride */}
      {renderActiveRide()}

      {/* Incoming ride cards */}
      {renderIncomingRides()}

    </div>
  );
}
