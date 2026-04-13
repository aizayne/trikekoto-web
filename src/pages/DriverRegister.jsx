// ============================================================
// DriverRegister.jsx — TrikeKoTo
// ============================================================
// Two-step registration:
//   Step 1 — Creates a Firebase Auth account (email + password)
//   Step 2 — Writes the driver profile to Firestore drivers/{email}
//             with status: "Pending Verification"
//
// Firestore rule enforced: doc ID must equal the authenticated
// user's email (request.auth.token.email == driverId).
// ============================================================

import { useState } from "react";
import { createUserWithEmailAndPassword, signOut } from "firebase/auth";
import { doc, setDoc, serverTimestamp } from "firebase/firestore";
import { auth, db } from "../firebase";
import { UserPlus, AlertTriangle, CheckCircle, Loader } from "lucide-react";
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
    maxWidth: "420px",
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
  row: {
    display: "flex",
    gap: "0.75rem",
  },
  field: {
    display: "flex",
    flexDirection: "column",
    flex: 1,
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
  hint: {
    fontSize: "0.73rem",
    color: "#475569",
    marginTop: "0.3rem",
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
  successBox: {
    backgroundColor: "#052e16",
    border: "1px solid #14532d",
    borderRadius: "0.75rem",
    padding: "1.25rem",
    fontSize: "0.85rem",
    color: "#86efac",
    lineHeight: 1.7,
    textAlign: "center",
  },
  divider: {
    borderColor: "#334155",
    margin: 0,
  },
  loginLink: {
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
  passwordStrength: (strength) => ({
    height: "4px",
    borderRadius: "2px",
    marginTop: "0.4rem",
    backgroundColor:
      strength === 0 ? "#334155" :
      strength === 1 ? "#dc2626" :
      strength === 2 ? "#f59e0b" :
      "#16a34a",
    width:
      strength === 0 ? "0%" :
      strength === 1 ? "33%" :
      strength === 2 ? "66%" :
      "100%",
    transition: "width 0.3s, background-color 0.3s",
  }),
};

function getPasswordStrength(pw) {
  if (!pw) return 0;
  let score = 0;
  if (pw.length >= 8) score++;
  if (/[A-Z]/.test(pw) || /[0-9]/.test(pw)) score++;
  if (pw.length >= 12) score++;
  return score;
}

export default function DriverRegister({ onNavigateToLogin }) {
  const [form, setForm] = useState({
    firstName: "",
    lastName: "",
    email: "",
    phone: "",
    plateNumber: "",
    password: "",
    confirmPassword: "",
  });
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);
  const [registered, setRegistered] = useState(false);

  const pwStrength = getPasswordStrength(form.password);

  const update = (field) => (e) =>
    setForm((prev) => ({ ...prev, [field]: e.target.value }));

  const handleRegister = async (e) => {
    e.preventDefault();
    setError(null);

    // Client-side validation
    if (form.password !== form.confirmPassword) {
      setError("Passwords do not match.");
      return;
    }
    if (form.password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }
    if (!/[0-9]/.test(form.password) || !/[A-Za-z]/.test(form.password)) {
      setError("Password must contain at least one letter and one number.");
      return;
    }

    setLoading(true);
    let userCredential = null;

    try {
      // Normalize once up front so Auth and Firestore agree on casing.
      const normalizedEmail = normalizeEmail(form.email);

      // Step 1: Create Firebase Auth account
      userCredential = await createUserWithEmailAndPassword(
        auth,
        normalizedEmail,
        form.password
      );

      // Step 2: Write driver profile to Firestore
      // Rule: doc ID must match the authenticated user's email (case-insensitive)
      await setDoc(doc(db, "drivers", normalizedEmail), {
        email: normalizedEmail,
        firstName: form.firstName.trim(),
        lastName: form.lastName.trim(),
        phone: form.phone.trim(),
        plateNumber: form.plateNumber.trim().toUpperCase(),
        status: "Pending Verification",
        createdAt: serverTimestamp(),
      });

      // Sign out immediately — they cannot use the app until admin approves
      await signOut(auth);
      setRegistered(true);
    } catch (err) {
      // If Firestore write failed but Auth succeeded, clean up the Auth account
      // so the user can retry cleanly (avoids orphaned Auth accounts)
      if (userCredential && err.code !== "auth/email-already-in-use") {
        try {
          await userCredential.user.delete();
        } catch {
          // Best-effort cleanup — swallow
        }
      }
      setError(friendlyAuthError(err.code));
    } finally {
      setLoading(false);
    }
  };

  // ── Success screen ───────────────────────────────────────────
  if (registered) {
    return (
      <div style={styles.page}>
        <div style={styles.card}>
          <div style={styles.logo}>
            <p style={styles.appName}>TrikeKoTo</p>
          </div>
          <div style={styles.successBox}>
            <CheckCircle size={32} style={{ marginBottom: "0.5rem", color: "#4ade80" }} />
            <br />
            <strong>Registration Submitted!</strong>
            <br /><br />
            Your application has been received. An admin will review your
            details and activate your account. You will be able to log in
            once your account is approved.
          </div>
          <button style={styles.button(false)} onClick={onNavigateToLogin}>
            Back to Login
          </button>
        </div>
      </div>
    );
  }

  // ── Registration form ────────────────────────────────────────
  return (
    <div style={styles.page}>
      <div style={styles.card}>
        {/* Logo */}
        <div style={styles.logo}>
          <p style={styles.appName}>TrikeKoTo</p>
          <p style={styles.tagline}>Driver Registration</p>
        </div>

        <hr style={styles.divider} />

        <form
          onSubmit={handleRegister}
          style={{ display: "flex", flexDirection: "column", gap: "1rem" }}
        >
          {/* Name row */}
          <div style={styles.row}>
            <div style={styles.field}>
              <label style={styles.label} htmlFor="firstName">First Name</label>
              <input
                id="firstName"
                style={styles.input}
                type="text"
                placeholder="Juan"
                value={form.firstName}
                onChange={update("firstName")}
                required
              />
            </div>
            <div style={styles.field}>
              <label style={styles.label} htmlFor="lastName">Last Name</label>
              <input
                id="lastName"
                style={styles.input}
                type="text"
                placeholder="dela Cruz"
                value={form.lastName}
                onChange={update("lastName")}
                required
              />
            </div>
          </div>

          {/* Email */}
          <div>
            <label style={styles.label} htmlFor="reg-email">Email Address</label>
            <input
              id="reg-email"
              style={styles.input}
              type="email"
              placeholder="you@example.com"
              value={form.email}
              onChange={update("email")}
              required
              autoComplete="email"
            />
          </div>

          {/* Phone */}
          <div>
            <label style={styles.label} htmlFor="phone">Phone Number</label>
            <input
              id="phone"
              style={styles.input}
              type="tel"
              placeholder="09XX XXX XXXX"
              value={form.phone}
              onChange={update("phone")}
              required
            />
          </div>

          {/* Plate number */}
          <div>
            <label style={styles.label} htmlFor="plate">Trike Plate Number</label>
            <input
              id="plate"
              style={{ ...styles.input, textTransform: "uppercase" }}
              type="text"
              placeholder="ABC 1234"
              value={form.plateNumber}
              onChange={update("plateNumber")}
              required
            />
            <p style={styles.hint}>Enter your vehicle's official plate number.</p>
          </div>

          {/* Password */}
          <div>
            <label style={styles.label} htmlFor="reg-password">Password</label>
            <input
              id="reg-password"
              style={styles.input}
              type="password"
              placeholder="Min 8 characters, letters + numbers"
              value={form.password}
              onChange={update("password")}
              required
              autoComplete="new-password"
            />
            {/* Password strength bar */}
            <div style={styles.passwordStrength(pwStrength)} />
          </div>

          {/* Confirm password */}
          <div>
            <label style={styles.label} htmlFor="confirmPassword">Confirm Password</label>
            <input
              id="confirmPassword"
              style={styles.input}
              type="password"
              placeholder="Re-enter your password"
              value={form.confirmPassword}
              onChange={update("confirmPassword")}
              required
              autoComplete="new-password"
            />
          </div>

          {error && (
            <div style={styles.errorBox}>
              <AlertTriangle size={16} style={{ flexShrink: 0, marginTop: "2px" }} />
              <span>{error}</span>
            </div>
          )}

          <button type="submit" style={styles.button(loading)} disabled={loading}>
            {loading ? <Loader size={18} /> : <UserPlus size={18} />}
            {loading ? "Creating Account…" : "Create Account"}
          </button>
        </form>

        <hr style={styles.divider} />

        <p style={styles.loginLink}>
          Already have an account?{" "}
          <button style={styles.link} onClick={onNavigateToLogin}>
            Sign in
          </button>
        </p>
      </div>
    </div>
  );
}

// ── Map Firebase error codes to human-readable messages ──────
function friendlyAuthError(code) {
  switch (code) {
    case "auth/email-already-in-use":
      return "An account with this email already exists. Please sign in instead.";
    case "auth/invalid-email":
      return "That email address is not valid.";
    case "auth/weak-password":
      return "Password is too weak. Use at least 8 characters with letters and numbers.";
    case "auth/network-request-failed":
      return "Network error. Check your internet connection.";
    default:
      return "Registration failed. Please try again.";
  }
}
