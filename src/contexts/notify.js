// ============================================================
// notify.js — context + hook for in-app toast/confirm
// ============================================================
// The <NotifyProvider> component lives in NotifyContext.jsx.
// This file holds the plain-JS pieces (context handle + hook)
// so the .jsx file can be component-only for react-refresh.
// ============================================================

import { createContext, useContext } from "react";

export const NotifyContext = createContext(null);

export function useNotify() {
  const ctx = useContext(NotifyContext);
  if (!ctx) throw new Error("useNotify() must be called inside <NotifyProvider>");
  return ctx;
}
