// ============================================================
// AdminPanel.jsx — TrikeKoTo
// ============================================================
// Simple driver management dashboard for admins.
//
// Access: navigate to /#/admin while logged in as an admin.
//
// Admin gate:
//   Admin status is determined by the existence of an
//   `admins/{email}` document in Firestore. Admins are created
//   from the Firebase Console — no client can write to that
//   collection (see firestore.rules).
//
// How it works:
//   - Reads the full `drivers` collection (public read in rules)
//   - Probes for `admins/{currentEmail}` to confirm admin access
//   - Allows updating driver `status` field via the "Approve"
//     and "Suspend" buttons (Firestore rules enforce this)
// ============================================================

import { useState, useEffect, useMemo } from "react";
import {
  collection, onSnapshot, doc, updateDoc, getDoc, serverTimestamp,
} from "firebase/firestore";
import { db, auth } from "../firebase";
import { CheckCircle, XCircle, LogOut, Loader } from "lucide-react";
import { signOut } from "firebase/auth";
import { useNotify } from "../contexts/notify.js";
import { normalizeEmail } from "../utils/email";

const STATUS_COLORS = {
  "Pending Verification": { bg: "#1c1917", text: "#fde68a", border: "#78350f" },
  "Active":               { bg: "#052e16", text: "#86efac", border: "#14532d" },
  "Suspended":            { bg: "#450a0a", text: "#fca5a5", border: "#7f1d1d" },
};

const FILTER_OPTIONS = ["All", "Pending Verification", "Active", "Suspended"];

const S = {
  page: {
    minHeight: "100vh",
    backgroundColor: "#0f172a",
    color: "#f8fafc",
    fontFamily: "'Segoe UI', system-ui, sans-serif",
    padding: "1.5rem",
    boxSizing: "border-box",
  },
  header: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: "1.5rem",
    flexWrap: "wrap",
    gap: "1rem",
  },
  title: { fontSize: "1.5rem", fontWeight: 800, color: "#f59e0b", margin: 0 },
  subtitle: { fontSize: "0.8rem", color: "#475569", margin: "0.2rem 0 0" },
  filterRow: {
    display: "flex", gap: "0.5rem", flexWrap: "wrap", marginBottom: "1.25rem",
  },
  filterBtn: (active) => ({
    padding: "0.4rem 1rem", borderRadius: "9999px",
    border: active ? "1px solid #f59e0b" : "1px solid #334155",
    backgroundColor: active ? "#f59e0b22" : "transparent",
    color: active ? "#f59e0b" : "#64748b",
    cursor: "pointer", fontSize: "0.82rem", fontWeight: 600,
  }),
  table: {
    width: "100%", borderCollapse: "collapse",
    backgroundColor: "#1e293b", borderRadius: "1rem",
    overflow: "hidden",
  },
  th: {
    padding: "0.75rem 1rem", textAlign: "left",
    fontSize: "0.72rem", fontWeight: 700,
    color: "#64748b", borderBottom: "1px solid #334155",
    textTransform: "uppercase", letterSpacing: "0.05em",
  },
  td: {
    padding: "0.85rem 1rem", fontSize: "0.85rem",
    color: "#e2e8f0", borderBottom: "1px solid #1e293b",
    verticalAlign: "middle",
  },
  tdAlt: {
    padding: "0.85rem 1rem", fontSize: "0.85rem",
    color: "#e2e8f0", borderBottom: "1px solid #1e293b",
    verticalAlign: "middle", backgroundColor: "#172033",
  },
  statusBadge: (status) => {
    const c = STATUS_COLORS[status] ?? { bg: "#1e293b", text: "#94a3b8", border: "#334155" };
    return {
      display: "inline-block", padding: "0.2rem 0.65rem",
      borderRadius: "9999px", fontSize: "0.75rem", fontWeight: 600,
      backgroundColor: c.bg, color: c.text, border: `1px solid ${c.border}`,
    };
  },
  actionBtn: (variant) => ({
    padding: "0.3rem 0.75rem", borderRadius: "0.5rem", border: "none",
    cursor: "pointer", fontSize: "0.78rem", fontWeight: 600,
    marginRight: "0.4rem",
    ...(variant === "approve"  && { backgroundColor: "#14532d", color: "#4ade80" }),
    ...(variant === "suspend"  && { backgroundColor: "#450a0a", color: "#fca5a5" }),
    ...(variant === "disabled" && { backgroundColor: "#1e293b", color: "#334155", cursor: "not-allowed" }),
  }),
  accessDenied: {
    minHeight: "100vh", display: "flex", flexDirection: "column",
    alignItems: "center", justifyContent: "center",
    backgroundColor: "#0f172a", color: "#64748b",
    fontFamily: "'Segoe UI', system-ui, sans-serif", gap: "0.75rem",
  },
  signOutBtn: {
    background: "none", border: "1px solid #334155",
    borderRadius: "0.5rem", color: "#94a3b8", cursor: "pointer",
    padding: "0.4rem 0.85rem", display: "flex",
    alignItems: "center", gap: "0.4rem", fontSize: "0.82rem",
  },
  emptyRow: {
    textAlign: "center", padding: "2.5rem",
    color: "#475569", fontSize: "0.85rem",
  },
  statsRow: {
    display: "flex", gap: "0.75rem", marginBottom: "1.25rem", flexWrap: "wrap",
  },
  statCard: (color) => ({
    flex: "1 1 120px", backgroundColor: "#1e293b",
    borderRadius: "0.875rem", padding: "0.9rem 1.1rem",
    borderLeft: `3px solid ${color}`,
  }),
  statNum:  { fontSize: "1.5rem", fontWeight: 800, margin: 0 },
  statLabel:{ fontSize: "0.72rem", color: "#64748b", margin: "0.15rem 0 0" },
};

export default function AdminPanel({ onBack, onDashboard }) {
  const currentEmail = normalizeEmail(auth.currentUser?.email);
  const { toast } = useNotify();

  // Admin check is async — probe for admins/{currentEmail} existence.
  // While this is pending we show a loader (not "access denied") so
  // the real admin isn't briefly told they're not an admin.
  const [adminStatus, setAdminStatus] = useState("checking"); // checking | yes | no
  const isAdmin = adminStatus === "yes";

  const [drivers, setDrivers]     = useState([]);
  const [filter, setFilter]       = useState("All");
  const [updating, setUpdating]   = useState(null); // email being updated

  // ── Check admin membership ────────────────────────────────
  useEffect(() => {
    if (!currentEmail) { setAdminStatus("no"); return; }
    let cancelled = false;
    getDoc(doc(db, "admins", currentEmail))
      .then((snap) => {
        if (cancelled) return;
        setAdminStatus(snap.exists() ? "yes" : "no");
      })
      .catch((err) => {
        if (cancelled) return;
        // Firestore rules block non-admins from reading the admins
        // collection — a "permission-denied" error is the expected
        // path for non-admins.
        console.warn("Admin check failed:", err.code ?? err.message);
        setAdminStatus("no");
      });
    return () => { cancelled = true; };
  }, [currentEmail]);

  // ── Load all drivers in real-time ─────────────────────────
  useEffect(() => {
    if (!isAdmin) return;
    const unsub = onSnapshot(
      collection(db, "drivers"),
      (snap) => {
        const list = [];
        snap.forEach((d) => list.push({ id: d.id, ...d.data() }));
        // Sort: pending first, then by registration date
        list.sort((a, b) => {
          const order = { "Pending Verification": 0, "Active": 1, "Suspended": 2 };
          const sa = order[a.status] ?? 3;
          const sb = order[b.status] ?? 3;
          if (sa !== sb) return sa - sb;
          return (a.createdAt?.toMillis?.() ?? 0) - (b.createdAt?.toMillis?.() ?? 0);
        });
        setDrivers(list);
      },
      (err) => console.error("Admin driver listener error:", err)
    );
    return unsub;
  }, [isAdmin]);

  const handleStatusChange = async (driverEmail, newStatus) => {
    // Normalize defensively so an old pre-normalization doc in
    // Firestore can still be updated via its normalized key.
    const id = normalizeEmail(driverEmail) || driverEmail;
    setUpdating(id);
    try {
      await updateDoc(doc(db, "drivers", id), {
        status: newStatus,
        statusUpdatedAt: serverTimestamp(),
        statusUpdatedBy: currentEmail,
      });
      toast(`${id} → ${newStatus}`, { variant: "success" });
    } catch (err) {
      console.error("Status update error:", err);
      toast("Failed to update driver status. Please try again.", { variant: "error" });
    } finally {
      setUpdating(null);
    }
  };

  // Compute counts once per driver-list change, then derive everything
  // else (filtered list, filter-button counts) from the same object.
  // NOTE: these hooks must run on every render, so they live above the
  // `isAdmin` early-return (Rules of Hooks).
  const counts = useMemo(() => {
    const c = {
      total: drivers.length,
      "Pending Verification": 0,
      "Active": 0,
      "Suspended": 0,
    };
    for (const d of drivers) {
      if (c[d.status] !== undefined) c[d.status]++;
    }
    return c;
  }, [drivers]);

  const filtered = useMemo(
    () => (filter === "All" ? drivers : drivers.filter((d) => d.status === filter)),
    [drivers, filter]
  );

  // ── Still resolving admin status ───────────────────────────
  if (adminStatus === "checking") {
    return (
      <div style={S.accessDenied}>
        <Loader size={24} color="#64748b" />
        <p style={{ margin: 0, fontSize: "0.85rem" }}>Verifying admin access…</p>
      </div>
    );
  }

  // ── Access denied ──────────────────────────────────────────
  if (!isAdmin) {
    return (
      <div style={S.accessDenied}>
        <XCircle size={40} color="#7f1d1d" />
        <p style={{ margin: 0, fontSize: "1.1rem", color: "#fca5a5" }}>Access Denied</p>
        <p style={{ margin: 0, fontSize: "0.82rem" }}>
          Your account ({currentEmail}) is not in the admin list.
        </p>
        <div style={{ display: "flex", gap: "0.6rem", marginTop: "0.5rem" }}>
          <button style={S.signOutBtn} onClick={onBack}>← Go Back</button>
          <button
            style={S.signOutBtn}
            onClick={async () => { await signOut(auth); onBack(); }}
          >
            <LogOut size={13} /> Sign Out
          </button>
        </div>
      </div>
    );
  }

  return (
    <div style={S.page}>
      {/* Header */}
      <div style={S.header}>
        <div>
          <p style={S.title}>TrikeKoTo Admin</p>
          <p style={S.subtitle}>Driver Management · {currentEmail}</p>
        </div>
        <div style={{ display: "flex", gap: "0.6rem" }}>
          {onDashboard && (
            <button style={S.signOutBtn} onClick={onDashboard}>
              Dashboard
            </button>
          )}
          <button style={S.signOutBtn} onClick={onBack}>← Back</button>
          <button
            style={S.signOutBtn}
            onClick={async () => { await signOut(auth); onBack(); }}
          >
            <LogOut size={13} /> Sign Out
          </button>
        </div>
      </div>

      {/* Stats */}
      <div style={S.statsRow}>
        <div style={S.statCard("#64748b")}>
          <p style={{ ...S.statNum, color: "#e2e8f0" }}>{counts.total}</p>
          <p style={S.statLabel}>Total Drivers</p>
        </div>
        <div style={S.statCard("#f59e0b")}>
          <p style={{ ...S.statNum, color: "#fde68a" }}>{counts["Pending Verification"]}</p>
          <p style={S.statLabel}>Pending Review</p>
        </div>
        <div style={S.statCard("#22c55e")}>
          <p style={{ ...S.statNum, color: "#86efac" }}>{counts["Active"]}</p>
          <p style={S.statLabel}>Active</p>
        </div>
        <div style={S.statCard("#ef4444")}>
          <p style={{ ...S.statNum, color: "#fca5a5" }}>{counts["Suspended"]}</p>
          <p style={S.statLabel}>Suspended</p>
        </div>
      </div>

      {/* Filters */}
      <div style={S.filterRow}>
        {FILTER_OPTIONS.map((f) => (
          <button key={f} style={S.filterBtn(filter === f)} onClick={() => setFilter(f)}>
            {f} {f !== "All" && `(${counts[f] ?? 0})`}
          </button>
        ))}
      </div>

      {/* Table — scrolls horizontally on small screens */}
      <div style={{ overflowX: "auto", borderRadius: "1rem" }}>
        <table style={S.table}>
          <thead>
            <tr>
              <th style={S.th}>Name</th>
              <th style={S.th}>Email</th>
              <th style={S.th}>Phone</th>
              <th style={S.th}>Plate No.</th>
              <th style={S.th}>Status</th>
              <th style={S.th}>Registered</th>
              <th style={S.th}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={7} style={S.emptyRow}>No drivers found.</td>
              </tr>
            ) : (
              filtered.map((driver, i) => {
                const tdStyle = i % 2 === 0 ? S.td : S.tdAlt;
                const isUpdating = updating === driver.email;
                const registeredDate = driver.createdAt?.toDate?.()
                  ? driver.createdAt.toDate().toLocaleDateString("en-PH", {
                      year: "numeric", month: "short", day: "numeric",
                    })
                  : "—";

                return (
                  <tr key={driver.id}>
                    <td style={tdStyle}>
                      {driver.firstName} {driver.lastName}
                    </td>
                    <td style={{ ...tdStyle, fontSize: "0.78rem", color: "#94a3b8" }}>
                      {driver.email}
                    </td>
                    <td style={tdStyle}>{driver.phone ?? "—"}</td>
                    <td style={{ ...tdStyle, fontWeight: 700, letterSpacing: "0.05em" }}>
                      {driver.plateNumber ?? "—"}
                    </td>
                    <td style={tdStyle}>
                      <span style={S.statusBadge(driver.status)}>
                        {driver.status ?? "Unknown"}
                      </span>
                    </td>
                    <td style={{ ...tdStyle, fontSize: "0.78rem", color: "#64748b" }}>
                      {registeredDate}
                    </td>
                    <td style={tdStyle}>
                      {driver.status !== "Active" && (
                        <button
                          style={S.actionBtn(isUpdating ? "disabled" : "approve")}
                          onClick={() => handleStatusChange(driver.email, "Active")}
                          disabled={isUpdating}
                        >
                          <CheckCircle size={12} style={{ marginRight: "0.3rem", verticalAlign: "middle" }} />
                          Approve
                        </button>
                      )}
                      {driver.status !== "Suspended" && (
                        <button
                          style={S.actionBtn(isUpdating ? "disabled" : "suspend")}
                          onClick={() => handleStatusChange(driver.email, "Suspended")}
                          disabled={isUpdating}
                        >
                          <XCircle size={12} style={{ marginRight: "0.3rem", verticalAlign: "middle" }} />
                          Suspend
                        </button>
                      )}
                      {isUpdating && (
                        <span style={{ fontSize: "0.75rem", color: "#64748b" }}>Saving…</span>
                      )}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
