// ============================================================
// RideHistory.jsx — TrikeKoTo
// ============================================================
// Shows the logged-in driver's past rides (completed + cancelled).
// Fetches all rides where assignedDriver matches the current user.
// ============================================================

import { useState, useEffect, useMemo } from "react";
import {
  collection, query, where, onSnapshot,
} from "firebase/firestore";
import { db, auth } from "../firebase";
import { normalizeEmail } from "../utils/email";
import {
  ArrowLeft, CheckCircle, XCircle, Clock,
  MapPin, Navigation, Loader, Calendar,
  Filter,
} from "lucide-react";

const STATUS_MAP = {
  completed: { label: "Completed", color: "#4ade80", bg: "#052e16", border: "#14532d", Icon: CheckCircle },
  cancelled: { label: "Cancelled", color: "#fca5a5", bg: "#450a0a", border: "#7f1d1d", Icon: XCircle },
  accepted:  { label: "In Progress", color: "#60a5fa", bg: "#172554", border: "#1e3a8a", Icon: Clock },
  searching: { label: "Searching", color: "#fde68a", bg: "#1c1917", border: "#78350f", Icon: Clock },
};

const FILTER_OPTIONS = ["All", "Completed", "Cancelled"];

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
  statsRow: {
    display: "flex", gap: "0.75rem", marginBottom: "1.25rem", flexWrap: "wrap",
  },
  statCard: (color) => ({
    flex: "1 1 100px", backgroundColor: "#1e293b",
    borderRadius: "0.875rem", padding: "0.9rem 1.1rem",
    borderLeft: `3px solid ${color}`,
  }),
  statNum: { fontSize: "1.4rem", fontWeight: 800, margin: 0 },
  statLabel: { fontSize: "0.72rem", color: "#64748b", margin: "0.15rem 0 0" },
  filterRow: {
    display: "flex", gap: "0.5rem", marginBottom: "1.25rem", flexWrap: "wrap",
    alignItems: "center",
  },
  filterBtn: (active) => ({
    padding: "0.35rem 0.9rem", borderRadius: "9999px",
    border: active ? "1px solid #f59e0b" : "1px solid #334155",
    backgroundColor: active ? "#f59e0b22" : "transparent",
    color: active ? "#f59e0b" : "#64748b",
    cursor: "pointer", fontSize: "0.8rem", fontWeight: 600,
  }),
  card: {
    backgroundColor: "#1e293b",
    borderRadius: "1rem",
    padding: "1.1rem",
    marginBottom: "0.75rem",
    display: "flex",
    flexDirection: "column",
    gap: "0.6rem",
  },
  cardHeader: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
  },
  badge: (status) => {
    const s = STATUS_MAP[status] ?? STATUS_MAP.searching;
    return {
      display: "inline-flex", alignItems: "center", gap: "0.3rem",
      padding: "0.2rem 0.6rem", borderRadius: "9999px",
      fontSize: "0.72rem", fontWeight: 600,
      backgroundColor: s.bg, color: s.color, border: `1px solid ${s.border}`,
    };
  },
  routeRow: {
    display: "flex", alignItems: "flex-start", gap: "0.5rem",
    fontSize: "0.85rem", color: "#e2e8f0",
  },
  routeIcon: { flexShrink: 0, marginTop: "0.1rem" },
  dateText: { fontSize: "0.75rem", color: "#64748b" },
  commuterText: { fontSize: "0.78rem", color: "#94a3b8" },
  empty: {
    textAlign: "center", padding: "3rem 1rem",
    color: "#475569", fontSize: "0.9rem",
  },
  loading: {
    minHeight: "60vh", display: "flex", flexDirection: "column",
    alignItems: "center", justifyContent: "center", gap: "0.75rem",
  },
};

export default function RideHistory({ onBack }) {
  const driverEmail = normalizeEmail(auth.currentUser?.email) || "";
  const [rides, setRides] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState("All");

  useEffect(() => {
    if (!driverEmail) {
      const id = setTimeout(() => setLoading(false), 0);
      return () => clearTimeout(id);
    }

    const q = query(
      collection(db, "rides"),
      where("assignedDriver", "==", driverEmail),
    );

    const unsub = onSnapshot(q, (snap) => {
      const list = [];
      snap.forEach((d) => list.push({ id: d.id, ...d.data() }));
      // Sort by most recent first
      list.sort((a, b) => {
        const ta = a.createdAt?.toMillis?.() ?? 0;
        const tb = b.createdAt?.toMillis?.() ?? 0;
        return tb - ta;
      });
      setRides(list);
      setLoading(false);
    }, (err) => {
      console.error("Ride history listener error:", err);
      setLoading(false);
    });

    return unsub;
  }, [driverEmail]);

  const counts = useMemo(() => {
    const c = { total: rides.length, completed: 0, cancelled: 0 };
    for (const r of rides) {
      if (r.status === "completed") c.completed++;
      else if (r.status === "cancelled") c.cancelled++;
    }
    return c;
  }, [rides]);

  const filtered = useMemo(() => {
    if (filter === "All") return rides;
    const key = filter.toLowerCase();
    return rides.filter((r) => r.status === key);
  }, [rides, filter]);

  const formatDate = (ts) => {
    if (!ts?.toDate) return "—";
    return ts.toDate().toLocaleString("en-PH", {
      year: "numeric", month: "short", day: "numeric",
      hour: "2-digit", minute: "2-digit",
    });
  };

  if (loading) {
    return (
      <div style={{ ...S.page, ...S.loading }}>
        <Loader size={24} color="#64748b" className="animate-spin" />
        <p style={{ margin: 0, fontSize: "0.85rem", color: "#64748b" }}>Loading ride history...</p>
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
          <p style={S.title}>Ride History</p>
          <p style={S.subtitle}>{driverEmail}</p>
        </div>
      </div>

      {/* Stats */}
      <div style={S.statsRow}>
        <div style={S.statCard("#64748b")}>
          <p style={{ ...S.statNum, color: "#e2e8f0" }}>{counts.total}</p>
          <p style={S.statLabel}>Total Rides</p>
        </div>
        <div style={S.statCard("#22c55e")}>
          <p style={{ ...S.statNum, color: "#86efac" }}>{counts.completed}</p>
          <p style={S.statLabel}>Completed</p>
        </div>
        <div style={S.statCard("#ef4444")}>
          <p style={{ ...S.statNum, color: "#fca5a5" }}>{counts.cancelled}</p>
          <p style={S.statLabel}>Cancelled</p>
        </div>
      </div>

      {/* Filter */}
      <div style={S.filterRow}>
        <Filter size={14} color="#64748b" />
        {FILTER_OPTIONS.map((f) => (
          <button key={f} style={S.filterBtn(filter === f)} onClick={() => setFilter(f)}>
            {f}
          </button>
        ))}
      </div>

      {/* Ride cards */}
      {filtered.length === 0 ? (
        <div style={S.empty}>
          <p>No rides found.</p>
          <p style={{ fontSize: "0.8rem", marginTop: "0.5rem" }}>
            {rides.length === 0
              ? "Completed rides will appear here."
              : "No rides match the current filter."}
          </p>
        </div>
      ) : (
        filtered.map((ride) => {
          const info = STATUS_MAP[ride.status] ?? STATUS_MAP.searching;
          const StatusIcon = info.Icon;
          return (
            <div key={ride.id} style={S.card}>
              <div style={S.cardHeader}>
                <span style={S.badge(ride.status)}>
                  <StatusIcon size={11} />
                  {info.label}
                </span>
                <span style={S.dateText}>
                  <Calendar size={11} style={{ marginRight: "0.25rem", verticalAlign: "middle" }} />
                  {formatDate(ride.createdAt)}
                </span>
              </div>

              <div style={S.routeRow}>
                <MapPin size={14} color="#4ade80" style={S.routeIcon} />
                <span>{ride.pickup || "—"}</span>
              </div>
              <div style={S.routeRow}>
                <Navigation size={14} color="#f59e0b" style={S.routeIcon} />
                <span>{ride.dropoff || "—"}</span>
              </div>

              {(ride.commuter || ride.commuterPhone) && (
                <p style={S.commuterText}>
                  Commuter: {ride.commuter || "Anonymous"}
                  {ride.commuterPhone ? ` \u00b7 ${ride.commuterPhone}` : ""}
                </p>
              )}

              {ride.notes && (
                <p style={{ fontSize: "0.78rem", color: "#64748b", fontStyle: "italic", margin: 0 }}>
                  {ride.notes}
                </p>
              )}
            </div>
          );
        })
      )}
    </div>
  );
}
