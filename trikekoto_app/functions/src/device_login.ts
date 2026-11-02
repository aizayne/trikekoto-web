/**
 * The secret behind a remembered phone, with no Firebase in it, so it can be
 * tested.
 *
 * The phone holds the secret and the database holds only its hash. Secrets are
 * 256 random bits, which is why a plain SHA-256 is enough here: there is nothing
 * to guess, so nothing a slow password hash would slow down.
 */
import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';

export function newDeviceSecret(): string {
  return randomBytes(32).toString('hex');
}

export function hashDeviceSecret(secret: string): string {
  return createHash('sha256').update(secret).digest('hex');
}

/** False for anything malformed, never a throw: a refusal is a normal answer. */
export function deviceSecretMatches(secret: string, storedHash: unknown): boolean {
  if (typeof storedHash !== 'string') return false;
  const given = Buffer.from(hashDeviceSecret(secret));
  const stored = Buffer.from(storedHash);
  return given.length === stored.length && timingSafeEqual(given, stored);
}
