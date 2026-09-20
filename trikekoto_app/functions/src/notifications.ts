/**
 * In-app notices, with no Firebase in it, so it can be tested.
 *
 * A notice is a document the server writes for one user and that user's app
 * reads back — the durable half of telling somebody something. The push is
 * the other half, and it is the unreliable one: it needs a registration token
 * the app only has after the person has opened it and agreed to
 * notifications, and it is gone the moment it is swiped away. A driver
 * approved while their phone was off should still be told, which is what the
 * document is for.
 */

/** A driver profile, as much of it as the approval notice reads. */
export type DriverState = {
  status?: string;
  uid?: string | null;
  fcmToken?: string | null;
};

/** What a notice is about. The app renders from this, not from the text. */
export const NOTICE_ACCOUNT_APPROVED = 'account_approved';

export type Notice = { type: string; title: string; body: string };

/**
 * The moment an admin's decision becomes news.
 *
 * Only the transition into `approved` counts. A profile is rewritten by
 * every rating and every edit, and a driver re-told they were approved each
 * time would learn to ignore the one notice that matters. A suspension
 * followed by a re-approval is news again, which is why this compares the two
 * versions rather than checking a flag.
 */
export function justApproved(
  before: DriverState | undefined,
  after: DriverState | undefined,
): boolean {
  if (!after || after.status !== 'approved') return false;
  return before?.status !== 'approved';
}

/**
 * The words, in English.
 *
 * The app shows its own Filipino or English wording for a type it knows —
 * a notice written once by the server would otherwise be the one string in
 * the app that ignores the language switch. These are the fallback: what the
 * push carries, and what an older build that has never heard of this type
 * still shows rather than a blank row.
 */
export const ACCOUNT_APPROVED: Notice = {
  type: NOTICE_ACCOUNT_APPROVED,
  title: 'Account approved',
  body: 'Your account has been approved by the admin. You can now log in.',
};
