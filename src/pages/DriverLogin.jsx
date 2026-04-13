// ============================================================
// DriverLogin.jsx — TrikeKoTo
// ============================================================
// Authenticates an existing driver with email + password.
// After login, reads the driver's Firestore profile to check
// their approval status before granting dashboard access.
//   - "Active"               → proceeds to DriverDashboard
//   - "Pending Verification" → shown a waiting screen
//   - Missing profile doc    → treated as unregistered
// ============================================================

import { useState } from "react";
import { signInWithEmailAndPassword } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { auth, db } from "../firebase";
import { LogIn, AlertTriangle, Loader } from "lucide-react";
import { normalizeEmail } from "../utils/email";

const styles = {
  page: {
    minHeight: "100vh",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    padding: "1.5rem",
    backgroundColor: "#0f172a",
    fontFamily: "'Segoe UI', system-ui, sans-serif",
    boxSizing: "border-box",
  },
  card: {
    width: "100%",
    maxWidth: "400px",
    backgroundColor: "#1e293b",
    borderRadius: "1.25rem",
    padding: "2rem",
    boxShadow: "0 8px 32px rgba(0,0,0,0.4)",
    display: "flex",
    flexDirection: "column",
    gap: "1.25rem",
  },
  logo: {
    textAlign: "center",
  },
  appName: {
    fontSize: "2rem",
    fontWeight: 800,
    color: "#f59e0b",
    margin: 0,
  },
  tagline: {
    fontSize: "0.85rem",
    color: "#64748b",
    margin: "0.25rem 0 0",
  },
  label: {
    display: "block",
    fontSize: "0.8rem",
    fontWeight: 600,
    color: "#94a3b8",
    marginBottom: "0.4rem",
  },
  input: {
    width: "100%",
    padding: "0.75rem 1rem",
    borderRadius: "0.75rem",
    border: "1px solid #334155",
    backgroundColor: "#0f172a",
    color: "#f1f5f9",
    fontSize: "0.95rem",
    outline: "none",
    boxSizing: "border-box",
  },
  button: (disabled) => ({
    width: "100%",
    padding: "0.875rem",
    borderRadius: "0.875rem",
    border: "none",
    cursor: disabled ? "not-allowed" : "pointer",
    fontSize: "1rem",
    fontWeight: 700,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    gap: "0.6rem",
    backgroundColor: disabled ? "#334155" : "#f59e0b",
    color: disabled ? "#64748b" : "#0f172a",
    transition: "background-color 0.2s",
  }),
  errorBox: {
    display: "flex",
    alignItems: "flex-start",
    gap: "0.6rem",
    backgroundColor: "#450a0a",
    border: "1px solid #7f1d1d",
    borderRadius: "0.75rem",
    padding: "0.9rem",
    fontSize: "0.82rem",
    color: "#fca5a5",
    lineHeight: 1.6,
  },
  pendingBox: {
    backgroundColor: "#1c1917",
    border: "1px solid #78350f",
    borderRadius: "0.75rem",
    padding: "1rem",
    fontSize: "0.85rem",
    color: "#fde68a",
    lineHeight: 1.7,
    textAlign: "center",
  },
  divider: {
    borderColor: "#334155",
    margin: 0,
  },
  registerLink: {
    textAlign: "center",
    fontSize: "0.85rem",
    color: "#64748b",
  },
  link: {
    color: "#f59e0b",
    fontWeight: 600,
    cursor: "pointer",
    background: "none",
    border: "none",
    fontSize: "inherit",
    padding: 0,
    textDecoration: "underline",
  },
};

export default function DriverLogin({ onNavigateToRegister }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState(null);
  const [isPending, setIsPending] = useState(false); // "Pending Verification" state
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e) => {
    e.preventDefault();
    setError(null);
    setIsPending(false);
    setLoading(true);

    try {
      // Normalize up front so Auth and Firestore agree on casing.
      const normalizedEmail = normalizeEmail(email);

      // Step 1: Authenticate with Firebase Auth
      await signInWithEmailAndPassword(auth, normalizedEmail, password);

      // Step 2: Check approval status in Firestore drivers collection
      const driverDoc = await getDoc(doc(db, "drivers", normalizedEmail));

      if (!driverDoc.exists()) {
        // Auth account exists but no Firestore profile — edge case
        setError("No driver profile found. Please register first.");
        await auth.signOut();
        return;
      }

      const { status } = driverDoc.data();

      if (status !== "Active") {
        // Account exists but not yet approved by admin
        setIsPending(true);
        await auth.signOut();
        return;
      }

      // Status is "Active" — App.jsx onAuthStateChanged will handle the redirect
    } catch (err) {
      setError(friendlyAuthError(err.code));
    } finally {
      setLoading(false);
    }
  };

  if (isPending) {
    return (
      <div style={styles.page}>
        <div style={styles.card}>
          <div style={styles.logo}>
            <p style={styles.appName}>TrikeKoTo</p>
          </div>
          <div style={styles.pendingBox}>
            <div style={{ fontSize: "2rem", marginBottom: "0.5rem" }}>⏳</div>
            <strong>Account Under Review</strong>
            <br />
            Your registration is pending admin verification.
            <br />
            You will be notified once your account is activated.
          </div>
          <button
            style={styles.button(false)}
            onClick={() => setIsPending(false)}
          >
            Back to Login
          </button>
        </div>
      </div>
    );
  }

  return (
    <div style={styles.page}>
      <div style={styles.card}>
        {/* Logo */}
        <div style={styles.logo}>
          <p style={styles.appName}>TrikeKoTo</p>
          <p style={styles.tagline}>Driver Portal</p>
        </div>

        <hr style={styles.divider} />

        {/* Form */}
        <form onSubmit={handleLogin} style={{ display: "flex", flexDirection: "column", gap: "1rem" }}>
          <div>
            <label style={styles.label} htmlFor="email">Email Address</label>
            <input
              id="email"
              style={styles.input}
              type="email"
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoComplete="email"
            />
          </div>

          <div>
            <label style={styles.label} htmlFor="password">Password</label>
            <input
              id="password"
              style={styles.input}
              type="password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              autoComplete="current-password"
            />
          </div>

          {error && (
            <div style={styles.errorBox}>
              <AlertTriangle size={16} style={{ flexShrink: 0, marginTop: "2px" }} />
              <span>{error}</span>
            </div>
          )}

          <button type="submit" style={styles.button(loading)} disabled={loading}>
            {loading ? <Loader size={18} className="spin" /> : <LogIn size={18} />}
            {loading ? "Signing in…" : "Sign In"}
          </button>
        </form>

        <hr style={styles.divider} />

        {/* Register link */}
        <p style={styles.registerLink}>
          New driver?{" "}
          <button style={styles.link} onClick={onNavigateToRegister}>
            Create an account
          </button>
        </p>
      </div>
    </div>
  );
}

// ── Map Firebase error codes to human-readable messages ──────
function friendlyAuthError(code) {
  switch (code) {
    case "auth/user-not-found":
    case "auth/wrong-password":
    case "auth/invalid-credential":
      return "Incorrect email or password. Please try again.";
    case "auth/too-many-requests":
      return "Too many failed attempts. Please wait a moment and try again.";
    case "auth/user-disabled":
      return "This account has been disabled. Contact support.";
    case "auth/network-request-failed":
      return "Network error. Check your internet connection.";
    default:
      return "Login failed. Please try again.";
  }
}
