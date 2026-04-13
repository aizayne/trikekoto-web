// ============================================================
// NotifyContext.jsx — in-app toast + confirm replacement for
// window.alert / window.confirm.
// ============================================================
// Exposes two stable methods:
//
//   const { toast, confirm } = useNotify();
//
//   toast("Saved.",                           { variant: "success" });
//   toast("Could not accept ride.",           { variant: "error"   });
//   toast("The commuter cancelled the ride.", { variant: "info"    });
//
//   const ok = await confirm("Cancel this ride?", {
//     title: "Cancel ride",
//     okLabel: "Yes, cancel",
//     cancelLabel: "Keep ride",
//   });
//   if (!ok) return;
//
// Mount <NotifyProvider> once near the root of the app — see
// src/main.jsx. Rendering is portal-less and uses inline styles
// to match the rest of the codebase's style conventions.
// ============================================================

import {
  useCallback, useEffect, useMemo, useRef, useState,
} from "react";
import { CheckCircle, AlertTriangle, Info, X } from "lucide-react";
import { NotifyContext } from "./notify.js";

// ─── Styles ──────────────────────────────────────────────────
const S = {
  toastStack: {
    position: "fixed",
    top: "1rem",
    left: "50%",
    transform: "translateX(-50%)",
    display: "flex",
    flexDirection: "column",
    alignItems: "center",
    gap: "0.6rem",
    zIndex: 10000,
    pointerEvents: "none",
    maxWidth: "calc(100% - 2rem)",
    width: "440px",
  },
  toast: (variant) => ({
    pointerEvents: "auto",
    display: "flex",
    alignItems: "flex-start",
    gap: "0.65rem",
    width: "100%",
    padding: "0.85rem 1rem",
    borderRadius: "0.875rem",
    fontSize: "0.85rem",
    fontWeight: 500,
    lineHeight: 1.45,
    boxShadow: "0 10px 32px rgba(0,0,0,0.35)",
    border: `1px solid ${variantColors[variant].border}`,
    backgroundColor: variantColors[variant].bg,
    color: variantColors[variant].fg,
    animation: "tkt-toast-in 0.2s ease-out",
  }),
  toastClose: {
    background: "none",
    border: "none",
    color: "currentColor",
    opacity: 0.7,
    cursor: "pointer",
    padding: 0,
    marginLeft: "auto",
    display: "flex",
    alignItems: "center",
  },
  backdrop: {
    position: "fixed",
    inset: 0,
    backgroundColor: "rgba(2, 6, 23, 0.72)",
    backdropFilter: "blur(4px)",
    zIndex: 10001,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    padding: "1.25rem",
    animation: "tkt-modal-fade 0.18s ease-out",
  },
  modal: {
    width: "100%",
    maxWidth: "420px",
    backgroundColor: "#1e293b",
    color: "#f8fafc",
    borderRadius: "1rem",
    border: "1px solid #334155",
    padding: "1.5rem",
    display: "flex",
    flexDirection: "column",
    gap: "1rem",
    boxShadow: "0 20px 60px rgba(0,0,0,0.6)",
    fontFamily: "'Segoe UI', system-ui, sans-serif",
  },
  modalTitle: {
    fontSize: "1.05rem",
    fontWeight: 700,
    margin: 0,
  },
  modalBody: {
    fontSize: "0.88rem",
    color: "#cbd5e1",
    margin: 0,
    lineHeight: 1.55,
  },
  modalActions: {
    display: "flex",
    gap: "0.6rem",
    marginTop: "0.25rem",
  },
  btn: (kind) => ({
    flex: 1,
    padding: "0.75rem",
    borderRadius: "0.75rem",
    border: "none",
    fontSize: "0.9rem",
    fontWeight: 700,
    cursor: "pointer",
    transition: "opacity 0.15s",
    ...(kind === "primary" && { backgroundColor: "#dc2626", color: "#fff" }),
    ...(kind === "secondary" && {
      backgroundColor: "transparent",
      color: "#cbd5e1",
      border: "1px solid #334155",
    }),
  }),
};

const variantColors = {
  success: { bg: "#14532d", fg: "#dcfce7", border: "#166534", Icon: CheckCircle },
  error:   { bg: "#450a0a", fg: "#fecaca", border: "#7f1d1d", Icon: AlertTriangle },
  info:    { bg: "#172554", fg: "#dbeafe", border: "#1e3a8a", Icon: Info },
};

// ─── Provider ────────────────────────────────────────────────
export function NotifyProvider({ children }) {
  const [toasts, setToasts]             = useState([]);
  const [confirmState, setConfirmState] = useState(null);
  const nextIdRef                       = useRef(0);

  // Dismiss a toast by id
  const dismiss = useCallback((id) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  // Queue a toast. Returns its id in case callers want to dismiss it early.
  const toast = useCallback((message, opts = {}) => {
    const id       = ++nextIdRef.current;
    const variant  = opts.variant  ?? "info";
    const duration = opts.duration ?? 4500;
    setToasts((prev) => [...prev, { id, message, variant }]);
    if (duration > 0) {
      setTimeout(() => dismiss(id), duration);
    }
    return id;
  }, [dismiss]);

  // Show a modal confirm and return a Promise<boolean>.
  const confirm = useCallback((message, opts = {}) => {
    return new Promise((resolve) => {
      setConfirmState({
        message,
        title:       opts.title       ?? "Are you sure?",
        okLabel:     opts.okLabel     ?? "Confirm",
        cancelLabel: opts.cancelLabel ?? "Cancel",
        resolve,
      });
    });
  }, []);

  const resolveConfirm = useCallback((value) => {
    setConfirmState((prev) => {
      prev?.resolve(value);
      return null;
    });
  }, []);

  // Dismiss confirm with Escape key
  useEffect(() => {
    if (!confirmState) return;
    const onKey = (e) => {
      if (e.key === "Escape") resolveConfirm(false);
      if (e.key === "Enter")  resolveConfirm(true);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [confirmState, resolveConfirm]);

  const value = useMemo(() => ({ toast, confirm, dismiss }), [toast, confirm, dismiss]);

  return (
    <NotifyContext.Provider value={value}>
      {children}

      {/* Toast stack */}
      {toasts.length > 0 && (
        <div style={S.toastStack} aria-live="polite">
          {toasts.map((t) => {
            const { Icon } = variantColors[t.variant];
            return (
              <div key={t.id} style={S.toast(t.variant)} role="status">
                <Icon size={16} style={{ flexShrink: 0, marginTop: 2 }} />
                <span>{t.message}</span>
                <button
                  style={S.toastClose}
                  onClick={() => dismiss(t.id)}
                  aria-label="Dismiss"
                >
                  <X size={14} />
                </button>
              </div>
            );
          })}
        </div>
      )}

      {/* Confirm modal */}
      {confirmState && (
        <div
          style={S.backdrop}
          role="dialog"
          aria-modal="true"
          aria-labelledby="tkt-confirm-title"
          onClick={(e) => {
            // Click outside to cancel
            if (e.target === e.currentTarget) resolveConfirm(false);
          }}
        >
          <div style={S.modal}>
            <h2 id="tkt-confirm-title" style={S.modalTitle}>
              {confirmState.title}
            </h2>
            <p style={S.modalBody}>{confirmState.message}</p>
            <div style={S.modalActions}>
              <button
                style={S.btn("secondary")}
                onClick={() => resolveConfirm(false)}
              >
                {confirmState.cancelLabel}
              </button>
              <button
                style={S.btn("primary")}
                onClick={() => resolveConfirm(true)}
                autoFocus
              >
                {confirmState.okLabel}
              </button>
            </div>
          </div>
        </div>
      )}
    </NotifyContext.Provider>
  );
}
