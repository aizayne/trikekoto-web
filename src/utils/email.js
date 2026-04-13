// ============================================================
// email.js — email normalization helpers
// ============================================================
// TrikeKoTo uses the user's email as the Firestore doc ID for
// drivers, active_drivers, and admins. Firebase Auth preserves
// the casing of whatever the user typed at signup, but compares
// emails case-insensitively for uniqueness. That mismatch means
// `Driver@Example.com` and `driver@example.com` are the same
// Auth account — but would become two different doc IDs if we
// naively used `user.email` as the key.
//
// normalizeEmail() eliminates that drift: every write OR read
// that uses an email as a doc ID must pass through it first.
// The Firestore rule compares with `.lower()` on its side so
// the equality holds regardless of casing in the auth token.
// ============================================================

/**
 * Canonicalizes an email for use as a Firestore document ID.
 * Returns an empty string for nullish/invalid input so callers
 * can safely interpolate it without crashing.
 *
 * @param {string|null|undefined} email
 * @returns {string} lowercased, trimmed email (or "" on bad input)
 */
export function normalizeEmail(email) {
  if (typeof email !== "string") return "";
  return email.trim().toLowerCase();
}
