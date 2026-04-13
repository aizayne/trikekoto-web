// ============================================================
// DriverProfile.jsx — TrikeKoTo
// ============================================================
// Lets the logged-in driver edit their profile fields:
//   firstName, lastName, phone, plateNumber
//
// Email and status are read-only (email is the identity key;
// status is admin-controlled).
//
// Firestore rules enforce driverFieldsOk() — only the four
// fields above are writable by the driver on their own doc.
// ============================================================

import { useState, useEffect } from "react";
import { doc, getDoc, updateDoc } from "firebase/firestore";
import { db, auth } from "../firebase";
import { normalizeEmail } from "../utils/email";
import { useNotify } from "../contexts/notify.js";
import {
  ArrowLeft, Save, User, Phone, Hash, Mail,
  Shield, Loader, AlertTriangle,
} from "lucide-react";

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
    boxSizing: "border-box",
  },
  header: {
    display: "flex",
    alignItems: "center",
    gap: "0.75rem",
    width: "100%",
    maxWidth: "440px",
    marginBottom: "1.5rem",
  },
  backBtn: {
    background: "none",
    border: "1px solid #334155",
    borderRadius: "0.5rem",
    color: "#94a3b8",
    cursor: "pointer",
    padding: "0.4rem 0.6rem",
    display: "flex",
    alignItems: "center",
  },
  title: { fontSize: "1.4rem", fontWeight: 800, color: "#f59e0b", margin: 0 },
  subtitle: { fontSize: "0.8rem", color: "#475569", margin: "0.15rem 0 0" },
  card: {
    width: "100%",
    maxWidth: "440px",
    backgroundColor: "#1e293b",
    borderRadius: "1.25rem",
    padding: "1.5rem",
    boxShadow: "0 8px 32px rgba(0,0,0,0.4)",
    display: "flex",
    flexDirection: "column",
    gap: "1.1rem",
  },
  avatarWrap: {
    display: "flex",
    justifyContent: "center",
    marginBottom: "0.5rem",
  },
  avatar: {
    width: "72px", height: "72px",
    borderRadius: "50%",
    backgroundColor: "#f59e0b22",
    border: "2px solid #f59e0b44",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
  },
  row: { display: "flex", gap: "0.75rem" },
  field: { display: "flex", flexDirection: "column", flex: 1 },
  label: {
    display: "flex", alignItems: "center", gap: "0.35rem",
    fontSize: "0.78rem", fontWeight: 600, color: "#94a3b8",
    marginBottom: "0.35rem",
  },
  input: {
    width: "100%", padding: "0.7rem 0.9rem",
    borderRadius: "0.75rem", border: "1px solid #334155",
    backgroundColor: "#0f172a", color: "#f1f5f9",
    fontSize: "0.9rem", outline: "none", boxSizing: "border-box",
  },
  inputDisabled: {
    width: "100%", padding: "0.7rem 0.9rem",
    borderRadius: "0.75rem", border: "1px solid #1e293b",
    backgroundColor: "#0f172a55", color: "#64748b",
    fontSize: "0.9rem", outline: "none", boxSizing: "border-box",
    cursor: "not-allowed",
  },
  statusBadge: (status) => {
    const map = {
      "Pending Verification": { color: "#fde68a", bg: "#1c1917", border: "#78350f" },
      "Active":               { color: "#86efac", bg: "#052e16", border: "#14532d" },
      "Suspended":            { color: "#fca5a5", bg: "#450a0a", border: "#7f1d1d" },
    };
    const c = map[status] ?? { color: "#94a3b8", bg: "#1e293b", border: "#334155" };
    return {
      display: "inline-flex", alignItems: "center", gap: "0.3rem",
      padding: "0.25rem 0.7rem", borderRadius: "9999px",
      fontSize: "0.78rem", fontWeight: 600,
      backgroundColor: c.bg, color: c.color, border: `1px solid ${c.border}`,
    };
  },
  saveBtn: (disabled) => ({
    width: "100%", padding: "0.8rem",
    borderRadius: "0.875rem", border: "none",
    cursor: disabled ? "not-allowed" : "pointer",
    fontSize: "0.95rem", fontWeight: 700,
    display: "flex", alignItems: "center",
    justifyContent: "center", gap: "0.5rem",
    backgroundColor: disabled ? "#334155" : "#f59e0b",
    color: disabled ? "#64748b" : "#0f172a",
    transition: "background-color 0.2s",
  }),
  divider: { borderColor: "#334155", margin: 0 },
  loading: {
    minHeight: "60vh", display: "flex", flexDirection: "column",
    alignItems: "center", justifyContent: "center", gap: "0.75rem",
  },
  hint: { fontSize: "0.72rem", color: "#475569", marginTop: "0.2rem" },
};

export default function DriverProfile({ onBack }) {
  const driverEmail = normalizeEmail(auth.currentUser?.email) || "";
  const { toast } = useNotify();

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [profile, setProfile] = useState(null);
  const [form, setForm] = useState({
    firstName: "", lastName: "", phone: "", plateNumber: "",
  });

  // Load the driver doc
  useEffect(() => {
    if (!driverEmail) { setLoading(false); return; }
    let cancelled = false;
    getDoc(doc(db, "drivers", driverEmail))
      .then((snap) => {
        if (cancelled) return;
        if (snap.exists()) {
          const data = snap.data();
          setProfile(data);
          setForm({
            firstName: data.firstName ?? "",
            lastName: data.lastName ?? "",
            phone: data.phone ?? "",
            plateNumber: data.plateNumber ?? "",
          });
        }
        setLoading(false);
      })
      .catch((err) => {
        if (cancelled) return;
        console.error("Profile load error:", err);
        setLoading(false);
      });
    return () => { cancelled = true; };
  }, [driverEmail]);

  const hasChanges = profile && (
    form.firstName !== (profile.firstName ?? "") ||
    form.lastName !== (profile.lastName ?? "") ||
    form.phone !== (profile.phone ?? "") ||
    form.plateNumber !== (profile.plateNumber ?? "")
  );

  const handleSave = async (e) => {
    e.preventDefault();
    if (!hasChanges || saving) return;
    setSaving(true);
    try {
      await updateDoc(doc(db, "drivers", driverEmail), {
        firstName: form.firstName.trim(),
        lastName: form.lastName.trim(),
        phone: form.phone.trim(),
        plateNumber: form.plateNumber.trim(),
      });
      // Update local profile so hasChanges resets
      setProfile((prev) => ({
        ...prev,
        firstName: form.firstName.trim(),
        lastName: form.lastName.trim(),
        phone: form.phone.trim(),
        plateNumber: form.plateNumber.trim(),
      }));
      toast("Profile updated successfully!", { variant: "success" });
    } catch (err) {
      console.error("Profile save error:", err);
      toast("Failed to update profile. Please try again.", { variant: "error" });
    } finally {
      setSaving(false);
    }
  };

  const update = (field) => (e) =>
    setForm((prev) => ({ ...prev, [field]: e.target.value }));

  if (loading) {
    return (
      <div style={{ ...S.page, ...S.loading }}>
        <Loader size={24} color="#64748b" />
        <p style={{ margin: 0, fontSize: "0.85rem", color: "#64748b" }}>Loading profile...</p>
      </div>
    );
  }

  if (!profile) {
    return (
      <div style={{ ...S.page, ...S.loading }}>
        <AlertTriangle size={32} color="#f59e0b" />
        <p style={{ margin: 0, fontSize: "0.9rem", color: "#fca5a5" }}>Profile not found</p>
        <button style={S.backBtn} onClick={onBack}>
          <ArrowLeft size={14} /> Back
        </button>
      </div>
    );
  }

  return (
    <div style={S.page}>
      {/* Header */}
      <div style={S.header}>
        <button style={S.backBtn} onClick={onBack}>
          <ArrowLeft size={16} />
        </button>
        <div>
          <p style={S.title}>My Profile</p>
          <p style={S.subtitle}>Edit your driver details</p>
        </div>
      </div>

      <form onSubmit={handleSave} style={S.card}>
        {/* Avatar + status */}
        <div style={S.avatarWrap}>
          <div style={S.avatar}>
            <User size={32} color="#f59e0b" />
          </div>
        </div>
        <div style={{ textAlign: "center" }}>
          <span style={S.statusBadge(profile.status)}>
            <Shield size={11} />
            {profile.status ?? "Unknown"}
          </span>
        </div>

        <hr style={S.divider} />

        {/* Email (read-only) */}
        <div style={S.field}>
          <label style={S.label}>
            <Mail size={13} /> Email
          </label>
          <input style={S.inputDisabled} value={driverEmail} disabled />
          <p style={S.hint}>Email cannot be changed</p>
        </div>

        {/* Name row */}
        <div style={S.row}>
          <div style={S.field}>
            <label style={S.label}>
              <User size={13} /> First Name
            </label>
            <input
              style={S.input}
              value={form.firstName}
              onChange={update("firstName")}
              placeholder="Juan"
              required
            />
          </div>
          <div style={S.field}>
            <label style={S.label}>Last Name</label>
            <input
              style={S.input}
              value={form.lastName}
              onChange={update("lastName")}
              placeholder="Dela Cruz"
              required
            />
          </div>
        </div>

        {/* Phone */}
        <div style={S.field}>
          <label style={S.label}>
            <Phone size={13} /> Phone Number
          </label>
          <input
            style={S.input}
            value={form.phone}
            onChange={update("phone")}
            placeholder="09XX-XXX-XXXX"
            type="tel"
          />
        </div>

        {/* Plate number */}
        <div style={S.field}>
          <label style={S.label}>
            <Hash size={13} /> Plate Number
          </label>
          <input
            style={S.input}
            value={form.plateNumber}
            onChange={update("plateNumber")}
            placeholder="ABC-1234"
          />
        </div>

        <hr style={S.divider} />

        {/* Save button */}
        <button
          type="submit"
          style={S.saveBtn(!hasChanges || saving)}
          disabled={!hasChanges || saving}
        >
          {saving ? <Loader size={16} /> : <Save size={16} />}
          {saving ? "Saving..." : hasChanges ? "Save Changes" : "No Changes"}
        </button>
      </form>
    </div>
  );
}
