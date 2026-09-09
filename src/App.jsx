// ============================================================
// App.jsx — TrikeKoTo
// ============================================================
// Top-level router (no react-router — simple state machine).
//
// Screens:
//   "landing"          → Role selector (Driver / Commuter)
//   "commuter"         → CommuterBooking
//   "driver-login"     → DriverLogin
//   "driver-register"  → DriverRegister
//   "driver-dashboard" → DriverDashboard (requires auth)
//
// Auth check: onAuthStateChanged — if a driver session already
// exists on load, go straight to the dashboard.
// ============================================================

import { useState, useEffect } from "react";
import { onAuthStateChanged } from "firebase/auth";
import { auth } from "./firebase";

import DriverDashboard  from "./components/DriverDashboard";
import DriverLogin      from "./pages/DriverLogin";
import DriverRegister   from "./pages/DriverRegister";
import CommuterBooking  from "./pages/CommuterBooking";
import AdminPanel       from "./pages/AdminPanel";
import AdminDashboard   from "./pages/AdminDashboard";
import RideHistory      from "./pages/RideHistory";
import DriverProfile    from "./pages/DriverProfile";
import FeedbackForm     from "./pages/FeedbackForm";

// ─── Landing / role-selector screen ──────────────────────────
function LandingScreen({ onSelectDriver, onSelectCommuter, onFeedback }) {
  return (
    <div
      style={{
        minHeight: "100vh",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: "#0f172a",
        padding: "2rem",
        fontFamily: "'Segoe UI', system-ui, sans-serif",
        gap: "2rem",
        boxSizing: "border-box",
      }}
    >
      {/* Branding */}
      <div style={{ textAlign: "center" }}>
        <p style={{ fontSize: "2.8rem", fontWeight: 900, color: "#f59e0b", margin: 0, letterSpacing: "-1px" }}>
          TrikeKoTo
        </p>
        <p style={{ fontSize: "0.95rem", color: "#475569", margin: "0.4rem 0 0" }}>
          Your local trike, on demand.
        </p>
      </div>

      {/* Role cards */}
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: "1rem",
          width: "100%",
          maxWidth: "360px",
        }}
      >
        <button
          onClick={onSelectCommuter}
          style={roleCardStyle("#1e3a5f", "#3b82f6")}
        >
          <span style={{ fontSize: "2rem" }}>🛺</span>
          <div>
            <p style={{ margin: 0, fontWeight: 700, color: "#eff6ff", fontSize: "1.05rem" }}>
              I need a ride
            </p>
            <p style={{ margin: "0.2rem 0 0", color: "#93c5fd", fontSize: "0.8rem" }}>
              Book a trike near you
            </p>
          </div>
        </button>

        <button
          onClick={onSelectDriver}
          style={roleCardStyle("#1a2e1a", "#22c55e")}
        >
          <span style={{ fontSize: "2rem" }}>🚗</span>
          <div>
            <p style={{ margin: 0, fontWeight: 700, color: "#f0fdf4", fontSize: "1.05rem" }}>
              I&apos;m a driver
            </p>
            <p style={{ margin: "0.2rem 0 0", color: "#86efac", fontSize: "0.8rem" }}>
              Go online and accept rides
            </p>
          </div>
        </button>
      </div>

      {/* Footer — feedback link */}
      {onFeedback && (
        <button
          onClick={onFeedback}
          style={{
            background: "none", border: "none", color: "#475569",
            cursor: "pointer", fontSize: "0.8rem", marginTop: "0.5rem",
            textDecoration: "underline",
          }}
        >
          Send feedback or report an issue
        </button>
      )}
    </div>
  );
}

function roleCardStyle(bg, border) {
  return {
    backgroundColor: bg,
    border: `1px solid ${border}22`,
    borderRadius: "1.1rem",
    padding: "1.25rem 1.5rem",
    display: "flex",
    alignItems: "center",
    gap: "1rem",
    cursor: "pointer",
    textAlign: "left",
    width: "100%",
    transition: "transform 0.15s, box-shadow 0.15s",
    boxShadow: "0 4px 16px rgba(0,0,0,0.3)",
  };
}

// ─── Loading splash ───────────────────────────────────────────
function LoadingSplash() {
  return (
    <div
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: "#0f172a",
        flexDirection: "column",
        gap: "0.75rem",
        fontFamily: "'Segoe UI', system-ui, sans-serif",
      }}
    >
      <p style={{ fontSize: "2rem", fontWeight: 800, color: "#f59e0b", margin: 0 }}>
        TrikeKoTo
      </p>
      <p style={{ fontSize: "0.82rem", color: "#334155", margin: 0 }}>Loading…</p>
    </div>
  );
}

// ─── Root app ─────────────────────────────────────────────────
export default function App() {
  const [screen, setScreen]       = useState("landing");
  const [authChecked, setAuthChecked] = useState(false);

  // Check if a driver is already logged in on app start
  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (user) => {
      if (user) {
        const hashRoutes = {
          "#/admin": "admin",
          "#/admin-dashboard": "admin-dashboard",
          "#/history": "driver-history",
          "#/profile": "driver-profile",
        };
        setScreen(hashRoutes[window.location.hash] || "driver-dashboard");
      } else {
        // Logged out — return to landing unless the user is mid-flow
        // (login/register screens should stay put).
        setScreen((prev) =>
          prev === "driver-dashboard" || prev === "admin" ? "landing" : prev
        );
      }
      setAuthChecked(true);
    });
    return unsub;
  }, []);

  // React to later hash changes (e.g., user pastes /#/admin while signed in)
  useEffect(() => {
    const HASH_ROUTES = {
      "#/admin": "admin",
      "#/admin-dashboard": "admin-dashboard",
      "#/history": "driver-history",
      "#/profile": "driver-profile",
    };
    const onHashChange = () => {
      const target = HASH_ROUTES[window.location.hash];
      if (target && auth.currentUser) setScreen(target);
    };
    window.addEventListener("hashchange", onHashChange);
    return () => window.removeEventListener("hashchange", onHashChange);
  }, []);

  if (!authChecked) return <LoadingSplash />;

  switch (screen) {
    case "landing":
      return (
        <LandingScreen
          onSelectDriver={() => setScreen("driver-login")}
          onSelectCommuter={() => setScreen("commuter")}
          onFeedback={() => setScreen("feedback")}
        />
      );

    case "commuter":
      return (
        <CommuterBooking
          onBack={() => setScreen("landing")}
          onFeedback={() => setScreen("feedback")}
        />
      );

    case "feedback":
      return (
        <FeedbackForm onBack={() => setScreen("landing")} />
      );

    case "driver-login":
      return (
        <DriverLogin
          onNavigateToRegister={() => setScreen("driver-register")}
          // After successful login, onAuthStateChanged fires and sets screen
        />
      );

    case "driver-register":
      return (
        <DriverRegister
          onNavigateToLogin={() => setScreen("driver-login")}
        />
      );

    case "driver-dashboard":
      return (
        <DriverDashboard
          onSignOut={() => setScreen("landing")}
          onHistory={() => setScreen("driver-history")}
          onProfile={() => setScreen("driver-profile")}
        />
      );

    case "admin":
      return (
        <AdminPanel
          onBack={() => setScreen("driver-dashboard")}
          onDashboard={() => setScreen("admin-dashboard")}
        />
      );

    case "admin-dashboard":
      return (
        <AdminDashboard onBack={() => setScreen("admin")} />
      );

    case "driver-history":
      return (
        <RideHistory onBack={() => setScreen("driver-dashboard")} />
      );

    case "driver-profile":
      return (
        <DriverProfile onBack={() => setScreen("driver-dashboard")} />
      );

    default:
      return <LoadingSplash />;
  }
}
