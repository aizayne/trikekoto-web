// ============================================================
// CommuterBooking.jsx — TrikeKoTo
// ============================================================
// Three-phase UI for the commuter:
//
//   PHASE 1 — "form"
//     Pickup + dropoff text inputs, optional notes.
//     On submit → writes to Firestore rides collection.
//
//   PHASE 2 — "searching"
//     Real-time listener on the created ride document.
//     Shows animated waiting screen until a driver accepts.
//     Cancel button → marks ride "cancelled", returns to form.
//
//   PHASE 3 — "accepted"
//     Live map showing the driver's current GPS position,
//     updated in real-time from active_drivers/{driverEmail}.
//     Driver name, plate, and phone shown below the map.
// ============================================================

import { useState, useEffect, useRef } from "react";
import {
  collection, addDoc, doc, onSnapshot,
  updateDoc, getDoc, serverTimestamp,
} from "firebase/firestore";
import { db } from "../firebase";
import { normalizeEmail } from "../utils/email";
import {
  MapPin, Navigation, X, Loader,
  CheckCircle, User, Car, AlertTriangle,
} from "lucide-react";

// Leaflet map imports
import "leaflet/dist/leaflet.css";
import L from "leaflet";
import { MapContainer, TileLayer, Marker, Popup, useMap } from "react-leaflet";

// ── Fix Leaflet's broken default icons under Vite ────────────
// Vite hashes asset filenames; Leaflet's built-in icon path
// detection fails. We import the PNGs directly so Vite resolves
// them properly, then override the default icon.
import markerIconPng   from "leaflet/dist/images/marker-icon.png";
import markerIcon2x    from "leaflet/dist/images/marker-icon-2x.png";
import markerShadowPng from "leaflet/dist/images/marker-shadow.png";

delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconUrl:       markerIconPng,
  iconRetinaUrl: markerIcon2x,
  shadowUrl:     markerShadowPng,
});

// Custom trike icon for the driver marker
const trikeIcon = L.divIcon({
  className: "",
  html: `<div style="
    width:36px; height:36px; border-radius:50%;
    background:#f59e0b; display:flex;
    align-items:center; justify-content:center;
    font-size:18px; box-shadow:0 2px 8px rgba(0,0,0,0.4);
    border:2px solid #fff;">🛺</div>`,
  iconSize:   [36, 36],
  iconAnchor: [18, 18],
  popupAnchor:[0, -20],
});

// ─── RecenterMap ─────────────────────────────────────────────
// Sub-component that smoothly pans the Leaflet map whenever
// the driver's coordinates change. Must live inside MapContainer.
function RecenterMap({ coords }) {
  const map = useMap();
  useEffect(() => {
    if (coords) {
      map.panTo([coords.lat, coords.lng], { animate: true, duration: 0.8 });
    }
  }, [coords, map]);
  return null;
}

// ─── Styles ──────────────────────────────────────────────────
const S = {
  page: {
    minHeight: "100vh",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    padding: "1.5rem",
    backgroundColor: "#0f172a",
    color: "#f8fafc",
    fontFamily: "'Segoe UI', system-ui, sans-serif",
    boxSizing: "border-box",
  },
  card: {
    width: "100%",
    maxWidth: "420px",
    backgroundColor: "#1e293b",
    borderRadius: "1.25rem",
    padding: "2rem",
    boxShadow: "0 8px 32px rgba(0,0,0,0.4)",
    display: "flex",
    flexDirection: "column",
    gap: "1.25rem",
  },
  // Accepted phase card — wider to give map room
  acceptedCard: {
    width: "100%",
    maxWidth: "480px",
    backgroundColor: "#1e293b",
    borderRadius: "1.25rem",
    overflow: "hidden",           // map bleeds to card edges
    boxShadow: "0 8px 32px rgba(0,0,0,0.4)",
    display: "flex",
    flexDirection: "column",
  },
  logo: { textAlign: "center" },
  appName: { fontSize: "1.9rem", fontWeight: 800, color: "#f59e0b", margin: 0 },
  tagline:  { fontSize: "0.82rem", color: "#64748b", margin: "0.2rem 0 0" },
  label: {
    display: "block", fontSize: "0.8rem",
    fontWeight: 600, color: "#94a3b8", marginBottom: "0.4rem",
  },
  input: {
    width: "100%", padding: "0.75rem 1rem",
    borderRadius: "0.75rem", border: "1px solid #334155",
    backgroundColor: "#0f172a", color: "#f1f5f9",
    fontSize: "0.95rem", outline: "none", boxSizing: "border-box",
  },
  textarea: {
    width: "100%", padding: "0.75rem 1rem",
    borderRadius: "0.75rem", border: "1px solid #334155",
    backgroundColor: "#0f172a", color: "#f1f5f9",
    fontSize: "0.9rem", outline: "none", boxSizing: "border-box",
    resize: "vertical", minHeight: "72px", fontFamily: "inherit",
  },
  btn: (v, disabled) => ({
    width: "100%", padding: "0.875rem",
    borderRadius: "0.875rem", border: "none",
    cursor: disabled ? "not-allowed" : "pointer",
    fontSize: "1rem", fontWeight: 700,
    display: "flex", alignItems: "center",
    justifyContent: "center", gap: "0.55rem",
    transition: "opacity 0.2s",
    ...(v === "primary" && {
      backgroundColor: disabled ? "#334155" : "#f59e0b",
      color: disabled ? "#64748b" : "#0f172a",
    }),
    ...(v === "danger" && {
      backgroundColor: "transparent",
      border: "1px solid #7f1d1d", color: "#fca5a5",
    }),
    ...(v === "success" && { backgroundColor: "#0ea5e9", color: "#fff" }),
  }),
  divider: { borderColor: "#334155", margin: 0 },
  error: {
    display: "flex", alignItems: "flex-start", gap: "0.6rem",
    backgroundColor: "#450a0a", border: "1px solid #7f1d1d",
    borderRadius: "0.75rem", padding: "0.85rem",
    fontSize: "0.82rem", color: "#fca5a5", lineHeight: 1.6,
  },
  searchingWrap: {
    display: "flex", flexDirection: "column",
    alignItems: "center", gap: "1.25rem", textAlign: "center",
  },
  pulse: {
    width: "72px", height: "72px", borderRadius: "50%",
    backgroundColor: "#1e3a5f",
    display: "flex", alignItems: "center", justifyContent: "center",
    animation: "tkt-pulse 1.8s ease-in-out infinite",
  },
  routeBox: {
    width: "100%", backgroundColor: "#0f172a",
    borderRadius: "0.75rem", padding: "1rem",
    fontSize: "0.82rem", lineHeight: 2,
  },
  driverInfoWrap: { padding: "1.25rem", display: "flex", flexDirection: "column", gap: "1rem" },
  driverCard: {
    backgroundColor: "#0f172a", borderRadius: "0.875rem",
    padding: "1.1rem", display: "flex", flexDirection: "column", gap: "0.75rem",
  },
  driverRow:  { display: "flex", gap: "1rem" },
  driverCol:  { flex: 1 },
  driverLabel:{ fontSize: "0.72rem", color: "#64748b", marginBottom: "0.15rem", margin: 0 },
  driverValue:{ fontSize: "0.95rem", color: "#e2e8f0", fontWeight: 600, margin: "0.1rem 0 0" },
  liveBadge: {
    display: "inline-flex", alignItems: "center", gap: "0.35rem",
    backgroundColor: "#14532d", color: "#4ade80",
    borderRadius: "9999px", padding: "0.2rem 0.65rem",
    fontSize: "0.72rem", fontWeight: 700,
  },
  backLink: {
    background: "none", border: "none", color: "#64748b",
    cursor: "pointer", fontSize: "0.82rem",
    textDecoration: "underline", textAlign: "center",
  },
  mapPlaceholder: {
    height: "260px", backgroundColor: "#0f172a",
    display: "flex", alignItems: "center", justifyContent: "center",
    color: "#475569", fontSize: "0.82rem",
  },
};

// Wrap navigator.geolocation.getCurrentPosition in a Promise with a
// 6-second timeout. Defined at module scope so it isn't re-created on
// every render.
function getPositionAsync() {
  return new Promise((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error("unavailable"));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => resolve({ lat: pos.coords.latitude, lng: pos.coords.longitude }),
      (err) => reject(err),
      { enableHighAccuracy: true, timeout: 6000, maximumAge: 10000 }
    );
  });
}

// ─── Component ───────────────────────────────────────────────
export default function CommuterBooking({ onBack }) {
  const [phase, setPhase]           = useState("form");
  const [form, setForm]             = useState({ pickup: "", dropoff: "", notes: "", name: "", phone: "" });
  const [submitting, setSubmitting] = useState(false);
  const [error, setError]           = useState(null);
  const [activeRide, setActiveRide] = useState(null);
  const [driverInfo, setDriverInfo] = useState(null);
  const [elapsedSec, setElapsedSec] = useState(0);

  // Live driver position for the map
  const [driverMapCoords, setDriverMapCoords] = useState(null); // { lat, lng }

  const rideListenerRef   = useRef(null);
  const driverLocRef      = useRef(null); // listener for active_drivers doc
  const timerRef          = useRef(null);

  // ── Elapsed timer ──────────────────────────────────────────
  useEffect(() => {
    if (phase === "searching") {
      timerRef.current = setInterval(() => setElapsedSec((s) => s + 1), 1000);
    } else {
      clearInterval(timerRef.current);
      setElapsedSec(0);
    }
    return () => clearInterval(timerRef.current);
  }, [phase]);

  // ── Global cleanup on unmount ──────────────────────────────
  useEffect(() => {
    return () => {
      if (rideListenerRef.current) rideListenerRef.current();
      if (driverLocRef.current)    driverLocRef.current();
    };
  }, []);

  // ── Start driver location listener once we know the driver ─
  // Depends on the assigned driver email only, so the ride doc's
  // unrelated fields (status timestamps etc.) don't retrigger it.
  // Normalize defensively in case an older ride doc stored the
  // driver email with non-lowercase casing.
  const assignedDriver = normalizeEmail(activeRide?.assignedDriver) || null;
  useEffect(() => {
    if (!assignedDriver) return;

    // Clean up any previous listener
    if (driverLocRef.current) driverLocRef.current();

    driverLocRef.current = onSnapshot(
      doc(db, "active_drivers", assignedDriver),
      (snap) => {
        if (!snap.exists()) return;
        const { location } = snap.data();
        if (location?.lat != null && location?.lng != null) {
          setDriverMapCoords({ lat: location.lat, lng: location.lng });
        }
      },
      (err) => console.error("Driver location listener error:", err)
    );

    return () => {
      if (driverLocRef.current) { driverLocRef.current(); driverLocRef.current = null; }
    };
  }, [assignedDriver]);

  // ── Submit booking ──────────────────────────────────────────
  const handleBook = async (e) => {
    e.preventDefault();
    setError(null);
    if (!form.pickup.trim() || !form.dropoff.trim()) {
      setError("Please enter both a pickup and dropoff location.");
      return;
    }
    setSubmitting(true);
    try {
      // Silently try to get the commuter's GPS position.
      // This is used to match them with nearby drivers.
      // If the browser denies or times out, we still book — the
      // ride will simply be visible to all online drivers as fallback.
      const pickupCoords = await getPositionAsync().catch(() => null);

      const rideRef = await addDoc(collection(db, "rides"), {
        pickup:         form.pickup.trim(),
        dropoff:        form.dropoff.trim(),
        notes:          form.notes.trim() || null,
        commuter:       form.name.trim(),
        commuterPhone:  form.phone.trim(),
        status:         "searching",
        assignedDriver: null,
        driverLocation: null,
        acceptedAt:     null,
        pickupCoords,
        createdAt:      serverTimestamp(),
      });
      startRideListener(rideRef.id);
      setActiveRide({ id: rideRef.id, pickup: form.pickup, dropoff: form.dropoff });
      setPhase("searching");
    } catch (err) {
      console.error("Booking error:", err);
      setError("Failed to book a ride. Please check your connection and try again.");
    } finally {
      setSubmitting(false);
    }
  };

  // ── Listen to the ride doc for status changes ──────────────
  const startRideListener = (rideId) => {
    if (rideListenerRef.current) rideListenerRef.current();

    rideListenerRef.current = onSnapshot(
      doc(db, "rides", rideId),
      async (snap) => {
        if (!snap.exists()) return;
        const data = snap.data();

        if (data.status === "accepted" && data.assignedDriver) {
          // Stop listening to the ride doc now — we have what we need
          if (rideListenerRef.current) { rideListenerRef.current(); rideListenerRef.current = null; }

          const driverId = normalizeEmail(data.assignedDriver);

          // Fetch driver profile
          try {
            const driverSnap = await getDoc(doc(db, "drivers", driverId));
            setDriverInfo(
              driverSnap.exists()
                ? driverSnap.data()
                : { email: driverId, firstName: "Your Driver", lastName: "" }
            );
          } catch {
            setDriverInfo({ email: driverId, firstName: "Your Driver", lastName: "" });
          }

          // Seed the map with the location snapshot stored at accept time
          if (data.driverLocation?.lat && data.driverLocation?.lng) {
            setDriverMapCoords({ lat: data.driverLocation.lat, lng: data.driverLocation.lng });
          }

          setActiveRide((prev) => ({ ...prev, ...data, id: rideId }));
          setPhase("accepted");
        }

        if (data.status === "cancelled") {
          resetToForm();
        }
      },
      (err) => console.error("Ride listener error:", err)
    );
  };

  // ── Cancel ─────────────────────────────────────────────────
  const handleCancel = async () => {
    if (!activeRide?.id) { resetToForm(); return; }
    try {
      await updateDoc(doc(db, "rides", activeRide.id), {
        status: "cancelled",
        cancelledAt: serverTimestamp(),
      });
    } catch (err) {
      console.error("Cancel error:", err);
    }
    resetToForm();
  };

  // ── Reset to booking form ───────────────────────────────────
  const resetToForm = () => {
    if (rideListenerRef.current) { rideListenerRef.current(); rideListenerRef.current = null; }
    if (driverLocRef.current)    { driverLocRef.current();    driverLocRef.current    = null; }
    setActiveRide(null);
    setDriverInfo(null);
    setDriverMapCoords(null);
    setPhase("form");
    setForm({ pickup: "", dropoff: "", notes: "", name: "", phone: "" });
    setError(null);
  };

  const fmt = (s) => {
    const m = Math.floor(s / 60), sec = s % 60;
    return m > 0 ? `${m}m ${sec}s` : `${sec}s`;
  };

  // ─── PHASE: form ─────────────────────────────────────────────
  if (phase === "form") {
    return (
      <div style={S.page}>
        <div style={S.card}>
          <div style={S.logo}>
            <p style={S.appName}>TrikeKoTo</p>
            <p style={S.tagline}>Book a Ride</p>
          </div>
          <hr style={S.divider} />
          <form onSubmit={handleBook} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
            <div>
              <label style={S.label} htmlFor="pickup">
                <MapPin size={13} style={{ marginRight: "0.3rem", verticalAlign: "middle" }} />
                Pickup Location
              </label>
              <input
                id="pickup" style={S.input} type="text"
                placeholder="e.g. Brgy. San Jose, near the sari-sari store"
                value={form.pickup}
                onChange={(e) => setForm((f) => ({ ...f, pickup: e.target.value }))}
                required
              />
            </div>
            <div>
              <label style={S.label} htmlFor="dropoff">
                <Navigation size={13} style={{ marginRight: "0.3rem", verticalAlign: "middle" }} />
                Dropoff Location
              </label>
              <input
                id="dropoff" style={S.input} type="text"
                placeholder="e.g. TrikeKoTo Terminal, Public Market"
                value={form.dropoff}
                onChange={(e) => setForm((f) => ({ ...f, dropoff: e.target.value }))}
                required
              />
            </div>
            <div style={{ display: "flex", gap: "0.75rem" }}>
              <div style={{ flex: 1 }}>
                <label style={S.label} htmlFor="commuter-name">Your Name</label>
                <input
                  id="commuter-name" style={S.input} type="text"
                  placeholder="e.g. Maria"
                  value={form.name}
                  onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                  required
                />
              </div>
              <div style={{ flex: 1 }}>
                <label style={S.label} htmlFor="commuter-phone">Phone</label>
                <input
                  id="commuter-phone" style={S.input} type="tel"
                  placeholder="09XX XXX XXXX"
                  value={form.phone}
                  onChange={(e) => setForm((f) => ({ ...f, phone: e.target.value }))}
                  required
                />
              </div>
            </div>

            <div>
              <label style={S.label} htmlFor="notes">Notes (optional)</label>
              <textarea
                id="notes" style={S.textarea}
                placeholder="e.g. I have luggage, please hurry"
                value={form.notes}
                onChange={(e) => setForm((f) => ({ ...f, notes: e.target.value }))}
              />
            </div>
            {error && (
              <div style={S.error}>
                <AlertTriangle size={15} style={{ flexShrink: 0, marginTop: 2 }} />
                <span>{error}</span>
              </div>
            )}
            <button type="submit" style={S.btn("primary", submitting)} disabled={submitting}>
              {submitting ? <Loader size={17} /> : <Navigation size={17} />}
              {submitting ? "Booking…" : "Find a Trike"}
            </button>
          </form>
          <hr style={S.divider} />
          <button style={S.backLink} onClick={onBack}>← Back to home</button>
        </div>
      </div>
    );
  }

  // ─── PHASE: searching ────────────────────────────────────────
  if (phase === "searching") {
    return (
      <div style={S.page}>
        <div style={S.card}>
          <div style={S.searchingWrap}>
            <div style={S.pulse}>
              <Navigation size={28} color="#60a5fa" />
            </div>
            <div>
              <p style={{ margin: 0, fontWeight: 700, fontSize: "1.1rem" }}>Looking for a driver…</p>
              <p style={{ margin: "0.3rem 0 0", fontSize: "0.82rem", color: "#64748b" }}>
                {fmt(elapsedSec)} elapsed
              </p>
            </div>
          </div>
          <div style={S.routeBox}>
            <div>
              <span style={{ color: "#64748b", fontSize: "0.72rem" }}>Pickup&nbsp;&nbsp;</span>
              <span style={{ color: "#e2e8f0", fontWeight: 600 }}>{activeRide?.pickup}</span>
            </div>
            <div>
              <span style={{ color: "#64748b", fontSize: "0.72rem" }}>Dropoff&nbsp;</span>
              <span style={{ color: "#e2e8f0", fontWeight: 600 }}>{activeRide?.dropoff}</span>
            </div>
          </div>
          <button style={S.btn("danger", false)} onClick={handleCancel}>
            <X size={16} /> Cancel Ride
          </button>
        </div>
      </div>
    );
  }

  // ─── PHASE: accepted ─────────────────────────────────────────
  // Default map center — Philippines (fallback until GPS arrives)
  const mapCenter = driverMapCoords
    ? [driverMapCoords.lat, driverMapCoords.lng]
    : [12.8797, 121.7740]; // geographic center of the Philippines

  return (
    <div style={{ ...S.page, paddingTop: "2rem", paddingBottom: "2rem" }}>
      <div style={S.acceptedCard}>

        {/* ── Live map ── */}
        {driverMapCoords ? (
          <MapContainer
            center={mapCenter}
            zoom={16}
            style={{ height: "280px", width: "100%" }}
            zoomControl={true}
            scrollWheelZoom={false}
          >
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            <Marker position={mapCenter} icon={trikeIcon}>
              <Popup>
                {driverInfo
                  ? `${driverInfo.firstName} ${driverInfo.lastName} — ${driverInfo.plateNumber ?? ""}`
                  : "Your driver"}
              </Popup>
            </Marker>
            {/* Smoothly pans map as driver moves */}
            <RecenterMap coords={driverMapCoords} />
          </MapContainer>
        ) : (
          // Waiting for first GPS ping from driver
          <div style={S.mapPlaceholder}>
            <Loader size={18} style={{ marginRight: "0.5rem" }} />
            Waiting for driver GPS…
          </div>
        )}

        {/* ── Info section below map ── */}
        <div style={S.driverInfoWrap}>

          {/* Header */}
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <div>
              <p style={{ margin: 0, fontWeight: 700, fontSize: "1.05rem" }}>Driver is on the way!</p>
              <p style={{ margin: "0.2rem 0 0", fontSize: "0.78rem", color: "#64748b" }}>
                Your trike is heading to your pickup point.
              </p>
            </div>
            <span style={S.liveBadge}>● Live</span>
          </div>

          {/* Driver details card */}
          <div style={S.driverCard}>
            <div style={{ fontSize: "0.75rem", color: "#64748b", fontWeight: 600 }}>YOUR DRIVER</div>
            {driverInfo ? (
              <>
                <div style={S.driverRow}>
                  <div style={S.driverCol}>
                    <p style={S.driverLabel}><User size={11} /> Name</p>
                    <p style={S.driverValue}>{driverInfo.firstName} {driverInfo.lastName}</p>
                  </div>
                  <div style={S.driverCol}>
                    <p style={S.driverLabel}><Car size={11} /> Plate No.</p>
                    <p style={S.driverValue}>{driverInfo.plateNumber ?? "—"}</p>
                  </div>
                </div>
                {driverInfo.phone && (
                  <div>
                    <p style={S.driverLabel}>Phone</p>
                    <p style={S.driverValue}>{driverInfo.phone}</p>
                  </div>
                )}
              </>
            ) : (
              <p style={{ color: "#64748b", fontSize: "0.82rem", margin: 0 }}>
                Loading driver details…
              </p>
            )}
          </div>

          {/* Route summary */}
          <div style={S.routeBox}>
            <div>
              <span style={{ color: "#64748b", fontSize: "0.72rem" }}>Pickup&nbsp;&nbsp;</span>
              <span style={{ color: "#e2e8f0", fontWeight: 600 }}>{activeRide?.pickup}</span>
            </div>
            <div>
              <span style={{ color: "#64748b", fontSize: "0.72rem" }}>Dropoff&nbsp;</span>
              <span style={{ color: "#e2e8f0", fontWeight: 600 }}>{activeRide?.dropoff}</span>
            </div>
          </div>

          <button style={S.btn("danger", false)} onClick={handleCancel}>
            <X size={16} /> Cancel Ride
          </button>
          <button style={S.btn("success", false)} onClick={resetToForm}>
            <CheckCircle size={17} /> Ride Complete — Book Again
          </button>
        </div>
      </div>
    </div>
  );
}
