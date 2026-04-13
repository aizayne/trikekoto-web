// ============================================================
// AdminDashboard.jsx — TrikeKoTo
// ============================================================
// Analytics overview for admins. Shows ride statistics,
// driver activity, and trends. Accessible from AdminPanel
// via /#/admin-dashboard.
// ============================================================

import { useState, useEffect, useMemo } from "react";
import {
  collection, onSnapshot, doc, getDoc,
} from "firebase/firestore";
import { db, auth } from "../firebase";
import { normalizeEmail } from "../utils/email";
import {
  ArrowLeft, BarChart3, Users, Car, Clock,
  CheckCircle, XCircle, Loader, TrendingUp,
  Activity, MapPin,
} from "lucide-react";

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
    gap: "0.75rem",
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
  section: { marginBottom: "1.5rem" },
  sectionTitle: {
    fontSize: "0.85rem", fontWeight: 700, color: "#94a3b8",
    marginBottom: "0.75rem", display: "flex", alignItems: "center", gap: "0.4rem",
  },
  grid: {
    display: "grid",
    gridTemplateColumns: "repeat(auto-fill, minmax(140px, 1fr))",
    gap: "0.75rem",
  },
  statCard: (color) => ({
    backgroundColor: "#1e293b",
    borderRadius: "0.875rem",
    padding: "1rem 1.1rem",
    borderLeft: `3px solid ${color}`,
    display: "flex",
    flexDirection: "column",
    gap: "0.1rem",
  }),
  statNum: { fontSize: "1.6rem", fontWeight: 800, margin: 0 },
  statLabel: { fontSize: "0.72rem", color: "#64748b", margin: 0 },
  barChartWrap: {
    backgroundColor: "#1e293b",
    borderRadius: "1rem",
    padding: "1.25rem",
  },
  barRow: {
    display: "flex",
    alignItems: "center",
    gap: "0.6rem",
    marginBottom: "0.6rem",
  },
  barLabel: {
    fontSize: "0.75rem", color: "#94a3b8", width: "60px",
    textAlign: "right", flexShrink: 0,
  },
  barTrack: {
    flex: 1, height: "20px",
    backgroundColor: "#0f172a",
    borderRadius: "4px",
    overflow: "hidden",
  },
  barFill: (pct, color) => ({
    height: "100%",
    width: `${Math.max(pct, 2)}%`,
    backgroundColor: color,
    borderRadius: "4px",
    transition: "width 0.5s ease",
  }),
  barCount: {
    fontSize: "0.75rem", color: "#e2e8f0", fontWeight: 700,
    width: "30px", flexShrink: 0,
  },
  tableWrap: {
    backgroundColor: "#1e293b",
    borderRadius: "1rem",
    overflow: "hidden",
  },
  table: { width: "100%", borderCollapse: "collapse" },
  th: {
    padding: "0.65rem 0.9rem", textAlign: "left",
    fontSize: "0.72rem", fontWeight: 700,
    color: "#64748b", borderBottom: "1px solid #334155",
    textTransform: "uppercase", letterSpacing: "0.05em",
  },
  td: {
    padding: "0.7rem 0.9rem", fontSize: "0.82rem",
    color: "#e2e8f0", borderBottom: "1px solid #0f172a",
  },
  loading: {
    minHeight: "60vh", display: "flex", flexDirection: "column",
    alignItems: "center", justifyContent: "center", gap: "0.75rem",
  },
};

export default function AdminDashboard({ onBack }) {
  const currentEmail = normalizeEmail(auth.currentUser?.email);

  const [adminStatus, setAdminStatus] = useState("checking");
  const [rides, setRides] = useState([]);
  const [drivers, setDrivers] = useState([]);
  const [activeDrivers, setActiveDrivers] = useState([]);
  const [loading, setLoading] = useState(true);

  // Admin check
  useEffect(() => {
    if (!currentEmail) {
      // Defer to avoid synchronous setState inside effect body
      const id = setTimeout(() => setAdminStatus("no"), 0);
      return () => clearTimeout(id);
    }
    let cancelled = false;
    getDoc(doc(db, "admins", currentEmail))
      .then((snap) => {
        if (!cancelled) setAdminStatus(snap.exists() ? "yes" : "no");
      })
      .catch(() => {
        if (!cancelled) setAdminStatus("no");
      });
    return () => { cancelled = true; };
  }, [currentEmail]);

  const isAdmin = adminStatus === "yes";

  // Load all rides
  useEffect(() => {
    if (!isAdmin) return;
    const unsub = onSnapshot(collection(db, "rides"), (snap) => {
      const list = [];
      snap.forEach((d) => list.push({ id: d.id, ...d.data() }));
      setRides(list);
      setLoading(false);
    }, () => setLoading(false));
    return unsub;
  }, [isAdmin]);

  // Load drivers
  useEffect(() => {
    if (!isAdmin) return;
    const unsub = onSnapshot(collection(db, "drivers"), (snap) => {
      const list = [];
      snap.forEach((d) => list.push({ id: d.id, ...d.data() }));
      setDrivers(list);
    });
    return unsub;
  }, [isAdmin]);

  // Load active drivers
  useEffect(() => {
    if (!isAdmin) return;
    const unsub = onSnapshot(collection(db, "active_drivers"), (snap) => {
      const list = [];
      snap.forEach((d) => list.push({ id: d.id, ...d.data() }));
      setActiveDrivers(list);
    });
    return unsub;
  }, [isAdmin]);

  // ── Derived stats ──────────────────────────────────────────
  const rideStats = useMemo(() => {
    const s = { total: rides.length, searching: 0, accepted: 0, completed: 0, cancelled: 0 };
    for (const r of rides) {
      if (s[r.status] !== undefined) s[r.status]++;
    }
    s.completionRate = s.total > 0
      ? Math.round((s.completed / s.total) * 100)
      : 0;
    return s;
  }, [rides]);

  const driverStats = useMemo(() => {
    const s = { total: drivers.length, pending: 0, active: 0, suspended: 0 };
    for (const d of drivers) {
      if (d.status === "Pending Verification") s.pending++;
      else if (d.status === "Active") s.active++;
      else if (d.status === "Suspended") s.suspended++;
    }
    const online = activeDrivers.filter((d) => d.isOnline).length;
    return { ...s, online };
  }, [drivers, activeDrivers]);

  // Rides per day (last 7 days)
  const dailyRides = useMemo(() => {
    const days = [];
    const now = new Date();
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      const key = d.toISOString().slice(0, 10);
      const label = d.toLocaleDateString("en-PH", { weekday: "short" });
      days.push({ key, label, count: 0 });
    }
    for (const r of rides) {
      const ts = r.createdAt?.toDate?.();
      if (!ts) continue;
      const key = ts.toISOString().slice(0, 10);
      const day = days.find((d) => d.key === key);
      if (day) day.count++;
    }
    return days;
  }, [rides]);

  const maxDaily = Math.max(1, ...dailyRides.map((d) => d.count));

  // Top drivers by completed rides
  const topDrivers = useMemo(() => {
    const map = {};
    for (const r of rides) {
      if (r.status !== "completed" || !r.assignedDriver) continue;
      const email = normalizeEmail(r.assignedDriver);
      map[email] = (map[email] || 0) + 1;
    }
    return Object.entries(map)
      .map(([email, count]) => {
        const driver = drivers.find((d) => d.id === email || d.email === email);
        const name = driver
          ? `${driver.firstName ?? ""} ${driver.lastName ?? ""}`.trim()
          : email;
        return { email, name, count };
      })
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);
  }, [rides, drivers]);

  // ── Render ─────────────────────────────────────────────────
  if (adminStatus === "checking" || (isAdmin && loading)) {
    return (
      <div style={{ ...S.page, ...S.loading }}>
        <Loader size={24} color="#64748b" />
        <p style={{ margin: 0, fontSize: "0.85rem", color: "#64748b" }}>Loading dashboard...</p>
      </div>
    );
  }

  if (!isAdmin) {
    return (
      <div style={{ ...S.page, ...S.loading }}>
        <XCircle size={40} color="#7f1d1d" />
        <p style={{ margin: 0, fontSize: "1.1rem", color: "#fca5a5" }}>Access Denied</p>
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
          <p style={S.title}>Dashboard</p>
          <p style={S.subtitle}>TrikeKoTo Analytics Overview</p>
        </div>
      </div>

      {/* ── Ride stats ──────────────────────────────────────── */}
      <div style={S.section}>
        <p style={S.sectionTitle}><Car size={15} /> Ride Statistics</p>
        <div style={S.grid}>
          <div style={S.statCard("#64748b")}>
            <p style={{ ...S.statNum, color: "#e2e8f0" }}>{rideStats.total}</p>
            <p style={S.statLabel}>Total Rides</p>
          </div>
          <div style={S.statCard("#22c55e")}>
            <p style={{ ...S.statNum, color: "#86efac" }}>{rideStats.completed}</p>
            <p style={S.statLabel}>Completed</p>
          </div>
          <div style={S.statCard("#ef4444")}>
            <p style={{ ...S.statNum, color: "#fca5a5" }}>{rideStats.cancelled}</p>
            <p style={S.statLabel}>Cancelled</p>
          </div>
          <div style={S.statCard("#3b82f6")}>
            <p style={{ ...S.statNum, color: "#93c5fd" }}>{rideStats.accepted}</p>
            <p style={S.statLabel}>In Progress</p>
          </div>
          <div style={S.statCard("#f59e0b")}>
            <p style={{ ...S.statNum, color: "#fde68a" }}>{rideStats.searching}</p>
            <p style={S.statLabel}>Searching</p>
          </div>
          <div style={S.statCard("#8b5cf6")}>
            <p style={{ ...S.statNum, color: "#c4b5fd" }}>{rideStats.completionRate}%</p>
            <p style={S.statLabel}>Completion Rate</p>
          </div>
        </div>
      </div>

      {/* ── Driver stats ────────────────────────────────────── */}
      <div style={S.section}>
        <p style={S.sectionTitle}><Users size={15} /> Driver Overview</p>
        <div style={S.grid}>
          <div style={S.statCard("#64748b")}>
            <p style={{ ...S.statNum, color: "#e2e8f0" }}>{driverStats.total}</p>
            <p style={S.statLabel}>Total Drivers</p>
          </div>
          <div style={S.statCard("#22c55e")}>
            <p style={{ ...S.statNum, color: "#86efac" }}>{driverStats.active}</p>
            <p style={S.statLabel}>Approved</p>
          </div>
          <div style={S.statCard("#f59e0b")}>
            <p style={{ ...S.statNum, color: "#fde68a" }}>{driverStats.pending}</p>
            <p style={S.statLabel}>Pending</p>
          </div>
          <div style={S.statCard("#ef4444")}>
            <p style={{ ...S.statNum, color: "#fca5a5" }}>{driverStats.suspended}</p>
            <p style={S.statLabel}>Suspended</p>
          </div>
          <div style={S.statCard("#0ea5e9")}>
            <p style={{ ...S.statNum, color: "#7dd3fc" }}>{driverStats.online}</p>
            <p style={S.statLabel}>Online Now</p>
          </div>
        </div>
      </div>

      {/* ── Rides per day (last 7 days) ─────────────────────── */}
      <div style={S.section}>
        <p style={S.sectionTitle}><TrendingUp size={15} /> Rides — Last 7 Days</p>
        <div style={S.barChartWrap}>
          {dailyRides.map((d) => (
            <div key={d.key} style={S.barRow}>
              <span style={S.barLabel}>{d.label}</span>
              <div style={S.barTrack}>
                <div style={S.barFill((d.count / maxDaily) * 100, "#f59e0b")} />
              </div>
              <span style={S.barCount}>{d.count}</span>
            </div>
          ))}
        </div>
      </div>

      {/* ── Top drivers ─────────────────────────────────────── */}
      <div style={S.section}>
        <p style={S.sectionTitle}><Activity size={15} /> Top Drivers (Completed Rides)</p>
        {topDrivers.length === 0 ? (
          <p style={{ color: "#475569", fontSize: "0.85rem" }}>No completed rides yet.</p>
        ) : (
          <div style={{ overflowX: "auto", borderRadius: "1rem" }}>
            <table style={S.table}>
              <thead>
                <tr>
                  <th style={S.th}>#</th>
                  <th style={S.th}>Driver</th>
                  <th style={S.th}>Completed</th>
                </tr>
              </thead>
              <tbody>
                {topDrivers.map((d, i) => (
                  <tr key={d.email}>
                    <td style={S.td}>{i + 1}</td>
                    <td style={S.td}>
                      <div style={{ fontWeight: 600 }}>{d.name}</div>
                      <div style={{ fontSize: "0.72rem", color: "#64748b" }}>{d.email}</div>
                    </td>
                    <td style={{ ...S.td, fontWeight: 700, color: "#86efac" }}>{d.count}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
