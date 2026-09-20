/**
 * Removing a driver from the system — the deciding half, with no Firebase in
 * it, so it can be tested.
 *
 * Deleting the profile is the easy part. What makes removal correct is what
 * happens to everything the person is attached to: a passenger currently in
 * their tricycle, a ride being offered to them at that second, and the rides
 * they finished months ago, which are the chapter's record and are not the
 * admin's to erase.
 */

/** A ride, as much of it as removal reads. */
export type RideRow = {
  id: string;
  status?: string;
  assignedDriver?: string | null;
  dispatch?: { offeredTo?: string | null };
};

/**
 * What removing a driver means for one of their rides.
 *
 * - `cancel` — a passenger is in the tricycle or waiting for it. The ride
 *   cannot silently keep pointing at an account that no longer exists: it is
 *   called off, which is the one outcome that tells the commuter to rebook.
 * - `release` — an offer is open to them right now. Clearing it is exactly
 *   what a decline does, and dispatch moves to the next nearest driver.
 * - `scrub` — a finished ride. It stays: who drove, which tricycle, when and
 *   what it was rated is the TODA's record of service, not the admin's to
 *   delete. Only the contact details go, because their purpose — reaching
 *   the driver during that trip — ended with the trip.
 */
export type RideAction = 'cancel' | 'release' | 'scrub';

export function actionForRide(ride: RideRow, driverEmail: string): RideAction {
  const email = driverEmail.toLowerCase();
  if (
    (ride.status === 'accepted' || ride.status === 'in_transit') &&
    ride.assignedDriver?.toLowerCase() === email
  ) {
    return 'cancel';
  }
  if (
    ride.status === 'searching' &&
    ride.dispatch?.offeredTo?.toLowerCase() === email
  ) {
    return 'release';
  }
  return 'scrub';
}

/**
 * Whether the sign-in account goes with the profile.
 *
 * Normally it does — a removal that leaves the account behind is not a
 * removal: the app would let them sign in and register again, since creating
 * a driver profile is something a signed-in person may do for themselves.
 *
 * The exception is an address that is also an admin. One person can be both,
 * and deleting the login of the officer who just removed a driver — possibly
 * themselves — would lock the chapter out of its own admin panel. The driver
 * profile still goes; the account stays, and the log says why.
 */
export function shouldDeleteAccount(opts: {
  uid?: string | null;
  isAdmin: boolean;
}): boolean {
  return !!opts.uid && !opts.isAdmin;
}
