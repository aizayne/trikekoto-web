// ============================================================
// FeedbackForm.jsx — TrikeKoTo
// ============================================================
// Public feedback / issue-report form. Anyone (authenticated
// or not) can submit a category-tagged message. Used by the
// capstone study to gather qualitative data about obstacles
// and improvement ideas from commuters and drivers.
//
// Writes to:   feedback/{autoId}
//   {
//     category:   'issue' | 'suggestion' | 'question' | 'other',
//     message:    string (1-2000 chars, enforced by rules),
//     contact:    optional email / phone for follow-up,
//     role:       'commuter' | 'driver' | 'anonymous',
//     createdAt:  serverTimestamp,
//     resolved:   false,
//   }
// ============================================================

import { useState } from "react";
import { collection, addDoc, serverTimestamp } from "firebase/firestore";
import { db } from "../firebase";
import {
  AlertTriangle, Lightbulb, HelpCircle, MessageCircle,
  Send, Loader, CheckCircle, ArrowLeft,
} from "lucide-react";

const CATEGORIES = [
  { value: "issue",      label: "Report an Issue",     Icon: AlertTriangle, color: "#ef4444" },
  { value: "suggestion", label: "Share a Suggestion",  Icon: Lightbulb,     color: "#f59e0b" },
  { value: "question",   label: "Ask a Question",      Icon: HelpCircle,    color: "#3b82f6" },
  { value: "other",      label: "Other",               Icon: MessageCircle, color: "#8b5cf6" },
];

const S = {
  page: {
    minHeight: "100vh",
    display: "flex",
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
    maxWidth: "460px",
    backgroundColor: "#1e293b",
    borderRadius: "1.25rem",
    padding: "2rem",
    boxShadow: "0 8px 32px rgba(0,0,0,0.4)",
    display: "flex",
    flexDirection: "column",
    gap: "1.25rem",
  },
  logo: { textAlign: "center" },
  appName: { fontSize: "1.9rem", fontWeight: 800, color: "#f59e0b", margin: 0 },
  tagline: { fontSize: "0.82rem", color: "#64748b", margin: "0.2rem 0 0" },
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
    resize: "vertical", minHeight: "120px", fontFamily: "inherit",
    lineHeight: 1.5,
  },
  categoryGrid: {
    display: "grid",
    gridTemplateColumns: "1fr 1fr",
    gap: "0.6rem",
  },
  catBtn: (active, color) => ({
    backgroundColor: active ? `${color}22` : "#0f172a",
    border: `1px solid ${active ? color : "#334155"}`,
    borderRadius: "0.75rem",
    padding: "0.8rem 0.6rem",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    justifyContent: "center",
    gap: "0.35rem",
    cursor: "pointer",
    color: active ? color : "#94a3b8",
    fontSize: "0.78rem",
    fontWeight: 600,
    transition: "background-color 0.2s, border-color 0.2s",
  }),
  roleGrid: {
    display: "flex",
    gap: "0.5rem",
  },
  roleBtn: (active) => ({
    flex: 1,
    backgroundColor: active ? "#f59e0b22" : "#0f172a",
    border: `1px solid ${active ? "#f59e0b" : "#334155"}`,
    borderRadius: "0.65rem",
    padding: "0.55rem",
    cursor: "pointer",
    color: active ? "#fde68a" : "#94a3b8",
    fontSize: "0.78rem",
    fontWeight: 600,
    transition: "background-color 0.2s, border-color 0.2s",
  }),
  btn: (variant, disabled) => ({
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
    gap: "0.55rem",
    transition: "opacity 0.2s",
    ...(variant === "primary" && {
      backgroundColor: disabled ? "#334155" : "#f59e0b",
      color: disabled ? "#64748b" : "#0f172a",
    }),
  }),
  error: {
    display: "flex", alignItems: "flex-start", gap: "0.6rem",
    backgroundColor: "#450a0a", border: "1px solid #7f1d1d",
    borderRadius: "0.75rem", padding: "0.85rem",
    fontSize: "0.82rem", color: "#fca5a5", lineHeight: 1.6,
  },
  divider: { borderColor: "#334155", margin: 0 },
  backLink: {
    background: "none", border: "none", color: "#64748b",
    cursor: "pointer", fontSize: "0.82rem",
    textDecoration: "underline", textAlign: "center",
    display: "inline-flex", alignItems: "center", gap: "0.3rem",
    margin: "0 auto",
  },
  counter: {
    fontSize: "0.72rem", color: "#64748b",
    textAlign: "right", margin: "0.25rem 0 0",
  },
  successWrap: {
    display: "flex", flexDirection: "column",
    alignItems: "center", gap: "1rem", textAlign: "center",
  },
  successIcon: {
    width: "72px", height: "72px", borderRadius: "50%",
    backgroundColor: "#052e16",
    display: "flex", alignItems: "center", justifyContent: "center",
  },
};

export default function FeedbackForm({ onBack }) {
  const [category, setCategory] = useState("issue");
  const [role, setRole]         = useState("commuter");
  const [message, setMessage]   = useState("");
  const [contact, setContact]   = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted]   = useState(false);
  const [error, setError]       = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError(null);
    if (!message.trim()) {
      setError("Please write a short message before submitting.");
      return;
    }
    if (message.trim().length > 2000) {
      setError("Message is too long. Please keep it under 2000 characters.");
      return;
    }
    setSubmitting(true);
    try {
      await addDoc(collection(db, "feedback"), {
        category,
        role,
        message: message.trim(),
        contact: contact.trim() || null,
        resolved: false,
        createdAt: serverTimestamp(),
      });
      setSubmitted(true);
    } catch (err) {
      console.error("Feedback submit error:", err);
      setError("Could not submit. Please check your connection and try again.");
    } finally {
      setSubmitting(false);
    }
  };

  if (submitted) {
    return (
      <div style={S.page}>
        <div style={S.card}>
          <div style={S.successWrap}>
            <div style={S.successIcon}>
              <CheckCircle size={36} color="#4ade80" />
            </div>
            <div>
              <p style={{ margin: 0, fontWeight: 700, fontSize: "1.2rem", color: "#86efac" }}>
                Thank you!
              </p>
              <p style={{ margin: "0.4rem 0 0", fontSize: "0.85rem", color: "#94a3b8", lineHeight: 1.6 }}>
                Your feedback has been received.
                <br />
                We review every message to improve TrikeKoTo.
              </p>
            </div>
          </div>
          <hr style={S.divider} />
          <button style={S.btn("primary", false)} onClick={onBack}>
            <ArrowLeft size={17} /> Back to Home
          </button>
        </div>
      </div>
    );
  }

  const remaining = 2000 - message.length;

  return (
    <div style={S.page}>
      <div style={S.card}>
        {/* Branding */}
        <div style={S.logo}>
          <p style={S.appName}>TrikeKoTo</p>
          <p style={S.tagline}>Feedback & Support</p>
        </div>

        <hr style={S.divider} />

        <form
          onSubmit={handleSubmit}
          style={{ display: "flex", flexDirection: "column", gap: "1.1rem" }}
        >
          {/* Category picker */}
          <div>
            <label style={S.label}>What would you like to tell us?</label>
            <div style={S.categoryGrid}>
              {CATEGORIES.map((c) => {
                const CatIcon = c.Icon;
                return (
                  <button
                    key={c.value}
                    type="button"
                    style={S.catBtn(category === c.value, c.color)}
                    onClick={() => setCategory(c.value)}
                  >
                    <CatIcon size={18} />
                    <span>{c.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Role picker */}
          <div>
            <label style={S.label}>I am a…</label>
            <div style={S.roleGrid}>
              {["commuter", "driver", "anonymous"].map((r) => (
                <button
                  key={r}
                  type="button"
                  style={S.roleBtn(role === r)}
                  onClick={() => setRole(r)}
                >
                  {r.charAt(0).toUpperCase() + r.slice(1)}
                </button>
              ))}
            </div>
          </div>

          {/* Message */}
          <div>
            <label style={S.label} htmlFor="feedback-message">
              Your Message
            </label>
            <textarea
              id="feedback-message"
              style={S.textarea}
              placeholder="Tell us what happened, what could be better, or ask a question…"
              value={message}
              onChange={(e) => setMessage(e.target.value)}
              maxLength={2000}
              required
            />
            <p style={S.counter}>
              {remaining.toLocaleString()} characters remaining
            </p>
          </div>

          {/* Optional contact */}
          <div>
            <label style={S.label} htmlFor="feedback-contact">
              Contact (optional)
            </label>
            <input
              id="feedback-contact"
              style={S.input}
              type="text"
              placeholder="Email or phone if you'd like a reply"
              value={contact}
              onChange={(e) => setContact(e.target.value)}
            />
          </div>

          {error && (
            <div style={S.error}>
              <AlertTriangle size={15} style={{ flexShrink: 0, marginTop: 2 }} />
              <span>{error}</span>
            </div>
          )}

          <button type="submit" style={S.btn("primary", submitting)} disabled={submitting}>
            {submitting ? <Loader size={17} /> : <Send size={17} />}
            {submitting ? "Sending…" : "Send Feedback"}
          </button>
        </form>

        <hr style={S.divider} />

        <button style={S.backLink} onClick={onBack}>
          <ArrowLeft size={12} /> Back
        </button>
      </div>
    </div>
  );
}
